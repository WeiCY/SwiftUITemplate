import Foundation
import Security

// MARK: - Keychain 安全存储工具
//
// 封装 iOS Keychain 操作，用于安全存储敏感数据（Token、密码等）。
//
// 用法：
// ```swift
// CYKeychainHelper.standard.save("my_token", service: "com.app.auth", account: "token")
// let token = CYKeychainHelper.standard.readString(service: "com.app.auth", account: "token")
// CYKeychainHelper.standard.delete(service: "com.app.auth", account: "token")
// ```

public final class CYKeychainHelper {
    public static let standard = CYKeychainHelper()
    
    private init() {}
    
    // MARK: - Data 操作
    
    /// 保存 Data 到 Keychain
    public func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        // 先删除已有项
        SecItemDelete(query)
        
        // 添加新项
        let status = SecItemAdd(query, nil)
        
        if status != errSecSuccess {
            print("Keychain 保存失败: \(status)")
        }
    }
    
    /// 从 Keychain 读取 Data
    public func read(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        return result as? Data
    }
    
    /// 从 Keychain 删除指定项
    public func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        SecItemDelete(query)
    }
    
    // MARK: - String 便捷操作
    
    /// 保存字符串到 Keychain
    public func save(_ string: String, service: String, account: String) {
        if let data = string.data(using: .utf8) {
            save(data, service: service, account: account)
        }
    }
    
    /// 从 Keychain 读取字符串
    public func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
