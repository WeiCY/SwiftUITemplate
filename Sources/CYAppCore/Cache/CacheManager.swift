import Foundation
import Observation

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
    private var memoryKeyIndex: [String: Set<String>] = [:]
    private let serializer: CYCacheSerializer

    init(serializer: CYCacheSerializer = CYJSONSerializer(), directoryName: String, baseDirectory: URL? = nil) {
        let fm = FileManager.default
        let base = baseDirectory
            ?? fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        self.baseCacheDirectory = base.appendingPathComponent(directoryName)
        self.serializer = serializer

        if !fm.fileExists(atPath: baseCacheDirectory.path) {
            try? fm.createDirectory(at: baseCacheDirectory, withIntermediateDirectories: true)
        }
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
        memoryCache.setObject(data as NSData, forKey: fullKey as NSString)
        registerMemoryKey(safeKey, namespace: namespace)
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
                memoryCache.setObject(data as NSData, forKey: fullKey as NSString)
                registerMemoryKey(safeKey, namespace: namespace)
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
        memoryKeyIndex[namespace ?? ""]?.remove(safeKey)
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
            let indexKey = namespace
            if let keys = memoryKeyIndex[indexKey] {
                for safeKey in keys {
                    let fullKey = "\(indexKey)/\(safeKey)"
                    memoryCache.removeObject(forKey: fullKey as NSString)
                }
                memoryKeyIndex[indexKey] = nil
            }
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
            memoryKeyIndex.removeAll()
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

    private func getDirectory(for namespace: String?) throws -> URL {
        guard let namespace = namespace, !namespace.isEmpty else {
            return baseCacheDirectory
        }
        let namespaceDir = baseCacheDirectory.appendingPathComponent(namespace)
        if !FileManager.default.fileExists(atPath: namespaceDir.path) {
            do {
                try FileManager.default.createDirectory(at: namespaceDir, withIntermediateDirectories: true)
            } catch {
                throw CYCacheError.fileSystem(error)
            }
        }
        return namespaceDir
    }

    private func safeFileName(for key: String) -> String {
        return key.replacingOccurrences(of: "/", with: "_")
    }

    private func registerMemoryKey(_ safeKey: String, namespace: String?) {
        let indexKey = namespace ?? ""
        memoryKeyIndex[indexKey, default: []].insert(safeKey)
    }

    private func removeIgnoringErrors(safeKey: String, fullKey: String, namespace: String?) {
        memoryCache.removeObject(forKey: fullKey as NSString)
        memoryKeyIndex[namespace ?? ""]?.remove(safeKey)
        let directory = (try? getDirectory(for: namespace)) ?? baseCacheDirectory
        let fileURL = directory.appendingPathComponent(safeKey)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

@Observable
public final class CYCacheManager: Sendable {
    public static let shared = CYCacheManager()

    private let storage: CacheStorage

    /// 初始化缓存管理器
    /// - Parameters:
    ///   - serializer: 序列化器，默认使用 JSON
    ///   - directoryName: 缓存子目录名，默认取 `CYAppConstants.cacheDirectoryName`
    ///   - baseDirectory: 缓存根目录，默认使用系统 caches 目录（测试可注入临时目录避免污染真实缓存）
    ///
    /// **性能优化建议**：
    /// - 小对象（< 1KB）：使用默认 `CYJSONSerializer()`
    /// - 大对象（> 10KB）或高频读写：使用 `CYPropertyListSerializer()`
    ///
    /// 示例：
    /// ```swift
    /// // 高性能缓存实例（用于列表数据）
    /// let fastCache = CYCacheManager(serializer: CYPropertyListSerializer())
    /// ```
    public init(
        serializer: CYCacheSerializer = CYJSONSerializer(),
        directoryName: String = CYAppConstants.cacheDirectoryName,
        baseDirectory: URL? = nil
    ) {
        self.storage = CacheStorage(serializer: serializer, directoryName: directoryName, baseDirectory: baseDirectory)
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
            try await storage.save(value: value, forKey: key, namespace: namespace, ttl: ttl)
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
        await storage.load(forKey: key, namespace: namespace)
    }

    /// 移除指定缓存项
    @discardableResult
    public func remove(forKey key: String, namespace: String? = nil) async -> Result<Void, CYCacheError> {
        do {
            try await storage.remove(forKey: key, namespace: namespace)
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
            try await storage.clear(namespace: namespace)
            return .success(())
        } catch let error as CYCacheError {
            CYLogger.cache.error("Failed to clear cache", error: error)
            return .failure(error)
        } catch {
            return .failure(.fileSystem(error))
        }
    }
}
