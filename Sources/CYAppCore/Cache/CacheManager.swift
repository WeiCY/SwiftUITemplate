import Foundation
import CryptoKit

// MARK: - 缓存管理器
//
// 支持内存缓存（NSCache）和磁盘缓存（FileManager），提供 TTL 过期机制。
// 使用命名空间分组缓存项（如 "UserProfile"、"Images"）。
//
// 所有方法均为 async，磁盘 I/O 在后台 actor 执行，不阻塞主线程。
//
// 用法：
// ```swift
// // 保存缓存（300秒过期）
// await CYCacheManager.shared.save(value: user, forKey: "profile", namespace: "User", ttl: 300)
//
// // 读取缓存
// let user: User? = await CYCacheManager.shared.load(forKey: "profile", namespace: "User")
//
// // 清除指定命名空间
// await CYCacheManager.shared.clear(namespace: "User")
//
// // 清除全部缓存
// await CYCacheManager.shared.clear()
// ```

/// 缓存条目（带 TTL 过期信息）
private struct CacheEntry<T: Codable>: Codable {
    let value: T
    let expirationDate: Date?
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }
}

public enum CYCacheError: Error, LocalizedError, Sendable {
    case serialization(Error)
    case fileSystem(Error)

    public var errorDescription: String? {
        switch self {
        case .serialization(let error): "Cache serialization failed: \(error.localizedDescription)"
        case .fileSystem(let error): "Cache file operation failed: \(error.localizedDescription)"
        }
    }
}

/// 缓存后台 actor，所有磁盘 I/O 在此执行，天然串行且隔离。
private actor CacheStorage {
    private let memoryCache = NSCache<NSString, NSData>()
    private let baseCacheDirectory: URL
    private let memoryByteLimit: Int
    private let serializer: CYCacheSerializer

    init(serializer: CYCacheSerializer = CYJSONSerializer(), directoryName: String, baseDirectory: URL? = nil, memoryByteLimit: Int) {
        let fm = FileManager.default
        let base = baseDirectory
            ?? fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        // v2 使用摘要文件名；旧缓存自然失效，避免读取有键碰撞风险的旧条目。
        self.baseCacheDirectory = base.appendingPathComponent(directoryName).appendingPathComponent("v2")
        self.serializer = serializer
        self.memoryByteLimit = max(0, memoryByteLimit)
        memoryCache.totalCostLimit = max(1, memoryByteLimit)
        memoryCache.countLimit = 256
    }

    func save<T: Codable>(value: T, forKey key: String, namespace: String?, ttl: TimeInterval?) throws {
        let expirationDate = ttl.map { Date().addingTimeInterval($0) }
        let entry = CacheEntry(value: value, expirationDate: expirationDate)
        let data: Data
        do {
            data = try serializer.serialize(entry)
        } catch {
            throw CYCacheError.serialization(error)
        }
        let safeKey = safeFileName(for: key)
        let fullKey = namespace.map { "\($0)/\(safeKey)" } ?? safeKey
        let directory = try getDirectory(for: namespace)
        let fileURL = directory.appendingPathComponent(safeKey)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw CYCacheError.fileSystem(error)
        }
        remember(data, forKey: fullKey)
    }

    func load<T: Codable>(forKey key: String, namespace: String?) -> T? {
        let safeKey = safeFileName(for: key)
        let fullKey = namespace.map { "\($0)/\(safeKey)" } ?? safeKey

        if let data = memoryCache.object(forKey: fullKey as NSString) as Data? {
            do {
                let entry = try serializer.deserialize(data, as: CacheEntry<T>.self)
                if !entry.isExpired {
                    return entry.value
                }
                removeIgnoringErrors(safeKey: safeKey, fullKey: fullKey, namespace: namespace)
                return nil
            } catch {
                CYLogger.cache.warning("Failed to decode cached value for key: \(key)", error: error)
            }
        }

        let directory: URL
        do {
            directory = try getDirectory(for: namespace)
        } catch {
            CYLogger.cache.warning("Failed to resolve cache directory for key: \(key)", error: error)
            return nil
        }

        let fileURL = directory.appendingPathComponent(safeKey)
        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try serializer.deserialize(data, as: CacheEntry<T>.self)
            if !entry.isExpired {
                remember(data, forKey: fullKey)
                return entry.value
            }
            removeIgnoringErrors(safeKey: safeKey, fullKey: fullKey, namespace: namespace)
        } catch let error as CYCacheError {
            CYLogger.cache.warning("Failed to load cache entry for key: \(key)", error: error)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            CYLogger.cache.warning("Failed to read cached file for key: \(key)", error: error)
        }
        return nil
    }
    func remove(forKey key: String, namespace: String?) throws {
        let safeKey = safeFileName(for: key)
        let fullKey = namespace.map { "\($0)/\(safeKey)" } ?? safeKey
        memoryCache.removeObject(forKey: fullKey as NSString)
        let directory = try getDirectory(for: namespace)
        let fileURL = directory.appendingPathComponent(safeKey)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            throw CYCacheError.fileSystem(error)
        }
    }

    func clear(namespace: String?) throws {
        if let namespace = namespace {
            // No side index that outlives NSCache eviction. Other namespaces reload from disk.
            memoryCache.removeAllObjects()
            let directory = try getDirectory(for: namespace)
            do {
                try FileManager.default.removeItem(at: directory)
            } catch CocoaError.fileNoSuchFile {
                return
            } catch {
                throw CYCacheError.fileSystem(error)
            }
        } else {
            memoryCache.removeAllObjects()
            do {
                try FileManager.default.removeItem(at: baseCacheDirectory)
                try FileManager.default.createDirectory(at: baseCacheDirectory, withIntermediateDirectories: true)
            } catch CocoaError.fileNoSuchFile {
                try FileManager.default.createDirectory(at: baseCacheDirectory, withIntermediateDirectories: true)
            } catch {
                throw CYCacheError.fileSystem(error)
            }
        }
    }

    private func directoryURL(for namespace: String?) -> URL {
        guard let namespace, !namespace.isEmpty else { return baseCacheDirectory }
        return baseCacheDirectory.appendingPathComponent("namespace-" + safeFileName(for: namespace))
    }

    private func getDirectory(for namespace: String?) throws -> URL {
        let directory = directoryURL(for: namespace)
        // 系统可随时清理 caches；每次磁盘操作重新确保目录存在，包含无命名空间的根目录。
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw CYCacheError.fileSystem(error)
        }
        return directory
    }

    private func safeFileName(for key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func remember(_ data: Data, forKey key: String) {
        guard memoryByteLimit > 0, data.count <= memoryByteLimit else { return }
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
    }

    private struct DiskEntry {
        let url: URL
        let size: Int
        let date: Date
    }

    /// Explicit maintenance avoids a directory scan on every write.
    func trimDisk(to maximumBytes: Int) throws {
        memoryCache.removeAllObjects()
        let root = try getDirectory(for: nil)
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        var files: [DiskEntry] = []
        func isDigest(_ value: String) -> Bool { value.count == 64 && value.allSatisfy(\.isHexDigit) }
        func collect(_ directory: URL, allowsNamespaces: Bool) throws {
            for url in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) {
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: Set(keys))
                guard values.isSymbolicLink != true else { continue }
                let name = url.lastPathComponent
                if values.isRegularFile == true, isDigest(name) {
                    files.append(DiskEntry(url: url, size: max(0, values.fileSize ?? 0), date: values.contentModificationDate ?? .distantPast))
                } else if allowsNamespaces, values.isDirectory == true, name.hasPrefix("namespace-"), isDigest(String(name.dropFirst(10))) {
                    try collect(url, allowsNamespaces: false)
                }
            }
        }
        try collect(root, allowsNamespaces: true)
        var total = files.reduce(Int64(0)) { $0 + Int64($1.size) }
        let budget = Int64(max(0, maximumBytes))
        for file in files.sorted(by: { $0.date == $1.date ? $0.url.path < $1.url.path : $0.date < $1.date }) {
            guard total > budget else { break }
            try Task.checkCancellation()
            try fm.removeItem(at: file.url)
            total -= Int64(file.size)
        }
    }

    private func removeIgnoringErrors(safeKey: String, fullKey: String, namespace: String?) {
        memoryCache.removeObject(forKey: fullKey as NSString)
        // 清理只定位原命名空间，不创建目录，也不回退删除根命名空间中的同名条目。
        let directory = directoryURL(for: namespace)
        let fileURL = directory.appendingPathComponent(safeKey)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

public final class CYCacheManager: Sendable {
    public static let shared = CYCacheManager()

    private let storage: CacheStorage

    /// 初始化缓存管理器
    /// - Parameters:
    ///   - serializer: 序列化器，默认使用 JSON
    ///   - directoryName: 缓存子目录名，默认取 `CYAppConstants.cacheDirectoryName`
    ///   - baseDirectory: 缓存根目录，默认使用系统 caches 目录（测试可注入临时目录避免污染真实缓存）
    ///
    /// memoryByteLimit 为 NSCache 的软字节上限，默认 32 MiB；非正值禁用内存缓存，条目软上限 256。
    /// serializer 按数据格式需求选择；切换前验证真实模型往返，不按未经测量的大小阈值选格式。
    public init(
        serializer: CYCacheSerializer = CYJSONSerializer(),
        directoryName: String = CYAppConstants.cacheDirectoryName,
        baseDirectory: URL? = nil,
        memoryByteLimit: Int = 32 * 1_024 * 1_024
    ) {
        self.storage = CacheStorage(serializer: serializer, directoryName: directoryName, baseDirectory: baseDirectory, memoryByteLimit: memoryByteLimit)
    }

    /// 保存 Codable 对象到缓存
    /// - 参数：
    ///   - value: 要缓存的对象
    ///   - key: 缓存键
    ///   - namespace: 可选命名空间（如 "UserProfile"、"Images"）
    ///   - ttl: 过期时间（秒），nil 表示永不过期
    @discardableResult
    public func save<T: Codable & Sendable>(value: T, forKey key: String, namespace: String? = nil, ttl: TimeInterval? = nil) async -> Result<Void, CYCacheError> {
        do {
            try await storage.save(value: value, forKey: key, namespace: normalized(namespace), ttl: ttl)
            return .success(())
        } catch let error as CYCacheError {
            CYLogger.cache.error("Failed to save cache entry for key: \(key)", error: error)
            return .failure(error)
        } catch {
            let cacheError = CYCacheError.fileSystem(error)
            CYLogger.cache.error("Failed to save cache entry for key: \(key)", error: cacheError)
            return .failure(cacheError)
        }
    }

    /// 从缓存中加载对象
    /// - 参数：
    ///   - key: 缓存键
    ///   - namespace: 命名空间
    /// - Returns: 缓存对象，不存在或已过期时返回 nil
    public func load<T: Codable & Sendable>(forKey key: String, namespace: String? = nil) async -> T? {
        await storage.load(forKey: key, namespace: normalized(namespace))
    }

    /// 移除指定缓存项
    @discardableResult
    public func remove(forKey key: String, namespace: String? = nil) async -> Result<Void, CYCacheError> {
        do {
            try await storage.remove(forKey: key, namespace: normalized(namespace))
            return .success(())
        } catch let error as CYCacheError {
            CYLogger.cache.error("Failed to remove cache entry for key: \(key)", error: error)
            return .failure(error)
        } catch {
            return .failure(.fileSystem(error))
        }
    }

    /// 清除缓存
    /// - Parameter namespace: 指定命名空间则只清除该命名空间，nil 清除全部
    @discardableResult
    public func clear(namespace: String? = nil) async -> Result<Void, CYCacheError> {
        do {
            try await storage.clear(namespace: normalized(namespace))
            return .success(())
        } catch let error as CYCacheError {
            CYLogger.cache.error("Failed to clear cache", error: error)
            return .failure(error)
        } catch {
            return .failure(.fileSystem(error))
        }
    }

    /// 启动或后台维护时调用：按最后写入时间淘汰磁盘条目至预算内（默认 128 MiB）。
    /// 只扫描本实例 v2 根目录和摘要命名空间；不跟随符号链接，不删除无关文件。
    /// 后续写入可再次超预算，宿主需定期调用；不是永久数据存储或跨进程配额。
    @discardableResult
    public func trimDisk(to maximumBytes: Int = 128 * 1_024 * 1_024) async -> Result<Void, CYCacheError> {
        do {
            try await storage.trimDisk(to: maximumBytes)
            return .success(())
        } catch {
            return .failure(.fileSystem(error))
        }
    }

    private func normalized(_ namespace: String?) -> String? {
        namespace?.isEmpty == true ? nil : namespace
    }
}
