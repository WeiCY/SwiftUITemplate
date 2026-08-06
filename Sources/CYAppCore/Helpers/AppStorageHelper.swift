import Foundation
import os

/// 类型安全的 UserDefaults封装，支持 Codable 对象
///
/// 用法：
/// ```swift
/// // 简单值
/// @AppStorageValue("username") var username: String = ""
/// @AppStorageValue("isLoggedIn") var isLoggedIn: Bool = false
///
/// // Codable 对象
/// let user: User? = CYAppStorageHelper.load(forKey: "currentUser")
/// CYAppStorageHelper.save(user, forKey: "currentUser")
/// ```
public struct CYAppStorageHelper {
    
    private init() {}
    
    private static var defaults: UserDefaults { .standard }
    
    /// 记录本工具写入过的 key，用于 `clearAll()` 只清除自定义数据，
    /// 而不破坏系统 / 其他框架写入 UserDefaults 的数据。
    private static let savedKeysStoreKey = "com.cyapp.storage.savedKeys"
    
    /// 启动时从 UserDefaults 恢复历史写入 key，保证 `clearAll()` 能清理跨进程/历史数据。
    private static let savedKeysLock = OSAllocatedUnfairLock(initialState: {
        Set(UserDefaults.standard.stringArray(forKey: savedKeysStoreKey) ?? [])
    }())
    
    // MARK: - Codable 对象存储
    
    /// 保存 Codable 对象到 UserDefaults
    public static func save<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
            let keys = savedKeysLock.withLock { keys -> Set<String> in
                keys.insert(key)
                return keys
            }
            defaults.set(Array(keys), forKey: savedKeysStoreKey)
        }
    }
    
    /// 从 UserDefaults 加载 Codable 对象
    public static func load<T: Codable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    /// 删除指定 key 的数据
    public static func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
        let keys = savedKeysLock.withLock { keys -> Set<String> in
            keys.remove(key)
            return keys
        }
        defaults.set(Array(keys), forKey: savedKeysStoreKey)
    }
    
    /// 检查 key 是否存在
    public static func has(forKey key: String) -> Bool {
        return defaults.object(forKey: key) != nil
    }
    
    /// 清除所有**本工具写入过**的自定义 key（保留系统 key 及其他框架数据）
    public static func clearAll() {
        let keys = savedKeysLock.withLock { $0 }
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        savedKeysLock.withLock { $0.removeAll() }
        defaults.removeObject(forKey: savedKeysStoreKey)
    }
}
