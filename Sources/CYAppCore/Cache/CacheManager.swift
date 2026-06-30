import Foundation
import Observation

// MARK: - 缓存管理器
//
// 支持内存缓存（NSCache）和磁盘缓存（FileManager），提供 TTL 过期机制。
// 使用命名空间分组缓存项（如 "UserProfile"、"Images"）。
//
// 用法：
// ```swift
// // 保存缓存（300秒过期）
// CYCacheManager.shared.save(value: user, forKey: "profile", namespace: "User", ttl: 300)
//
// // 读取缓存
// let user: User? = CYCacheManager.shared.load(forKey: "profile", namespace: "User")
//
// // 清除指定命名空间
// CYCacheManager.shared.clear(namespace: "User")
//
// // 清除全部缓存
// CYCacheManager.shared.clear()
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

@Observable
public final class CYCacheManager {
    public static let shared = CYCacheManager()
    
    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "SwiftUITemplate.CYCacheManager.queue")
    private let baseCacheDirectory: URL
    
    public init() {
        let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.baseCacheDirectory = url.appendingPathComponent("AppCache")
        
        if !fileManager.fileExists(atPath: baseCacheDirectory.path) {
            try? fileManager.createDirectory(at: baseCacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// 获取命名空间对应的目录
    private func getDirectory(for namespace: String?) -> URL {
        guard let namespace = namespace, !namespace.isEmpty else {
            return baseCacheDirectory
        }
        
        let namespaceDir = baseCacheDirectory.appendingPathComponent(namespace)
        if !fileManager.fileExists(atPath: namespaceDir.path) {
            try? fileManager.createDirectory(at: namespaceDir, withIntermediateDirectories: true)
        }
        return namespaceDir
    }
    
    /// 生成安全的文件名
    private func safeFileName(for key: String) -> String {
        return key.replacingOccurrences(of: "/", with: "_")
    }
    
    /// 保存 Codable 对象到缓存
    /// - 参数：
    ///   - value: 要缓存的对象
    ///   - key: 缓存键
    ///   - namespace: 可选命名空间（如 "UserProfile"、"Images"）
    ///   - ttl: 过期时间（秒），nil 表示永不过期
    public func save<T: Codable>(value: T, forKey key: String, namespace: String? = nil, ttl: TimeInterval? = nil) {
        queue.sync {
            let expirationDate = ttl.map { Date().addingTimeInterval($0) }
            let entry = CacheEntry(value: value, expirationDate: expirationDate)
            guard let data = try? JSONEncoder().encode(entry) else { return }
            let safeKey = safeFileName(for: key)
            let fullKey = namespace.map { "\($0)/\(safeKey)" } ?? safeKey
            memoryCache.setObject(data as NSData, forKey: fullKey as NSString)
            let directory = getDirectory(for: namespace)
            let fileURL = directory.appendingPathComponent(safeKey)
            try? data.write(to: fileURL)
        }
    }
    
    /// 从缓存中加载对象
    /// - 参数：
    ///   - key: 缓存键
    ///   - namespace: 命名空间
    /// - Returns: 缓存对象，不存在或已过期时返回 nil
    public func load<T: Codable>(forKey key: String, namespace: String? = nil) -> T? {
        queue.sync {
            let safeKey = safeFileName(for: key)
            let fullKey = namespace.map { "\($0)/\(safeKey)" } ?? safeKey
            if let data = memoryCache.object(forKey: fullKey as NSString) as Data? {
                if let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) {
                    if !entry.isExpired {
                        return entry.value
                    }
                    removeUnsafe(safeKey: safeKey, fullKey: fullKey, namespace: namespace)
                    return nil
                }
            }
            let directory = getDirectory(for: namespace)
            let fileURL = directory.appendingPathComponent(safeKey)
            if let data = try? Data(contentsOf: fileURL) {
                if let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) {
                    if !entry.isExpired {
                        memoryCache.setObject(data as NSData, forKey: fullKey as NSString)
                        return entry.value
                    }
                    removeUnsafe(safeKey: safeKey, fullKey: fullKey, namespace: namespace)
                    return nil
                }
            }
            return nil
        }
    }
    
    /// 移除指定缓存项
    public func remove(forKey key: String, namespace: String? = nil) {
        queue.sync {
            let safeKey = safeFileName(for: key)
            let fullKey = namespace.map { "\($0)/\(safeKey)" } ?? safeKey
            removeUnsafe(safeKey: safeKey, fullKey: fullKey, namespace: namespace)
        }
    }
    
    /// 清除缓存
    /// - Parameter namespace: 指定命名空间则只清除该命名空间，nil 清除全部
    public func clear(namespace: String? = nil) {
        queue.sync {
            if let namespace = namespace {
                let directory = getDirectory(for: namespace)
                try? fileManager.removeItem(at: directory)
            } else {
                memoryCache.removeAllObjects()
                try? fileManager.removeItem(at: baseCacheDirectory)
                try? fileManager.createDirectory(at: baseCacheDirectory, withIntermediateDirectories: true)
            }
        }
    }

    private func removeUnsafe(safeKey: String, fullKey: String, namespace: String?) {
        memoryCache.removeObject(forKey: fullKey as NSString)
        let directory = getDirectory(for: namespace)
        let fileURL = directory.appendingPathComponent(safeKey)
        try? fileManager.removeItem(at: fileURL)
    }
}
