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

public enum CYKeychainError: Error, LocalizedError, Sendable, Equatable {
    case operationFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .operationFailed(let status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain operation failed (\(status))."
        }
    }
}

public enum CYKeychainAccessibility: Sendable {
    case whenUnlocked
    case afterFirstUnlock
    case whenPasscodeSetThisDeviceOnly

    fileprivate var secValue: CFString {
        switch self {
        case .whenUnlocked: kSecAttrAccessibleWhenUnlocked
        case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock
        case .whenPasscodeSetThisDeviceOnly: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}

public final class CYKeychainHelper: @unchecked Sendable {
    public static let standard = CYKeychainHelper()
    
    private init() {}
    
    // MARK: - Data 操作
    
    /// 保存 Data 到 Keychain
    @discardableResult
    public func save(
        _ data: Data,
        service: String,
        account: String,
        accessibility: CYKeychainAccessibility = .afterFirstUnlock
    ) -> Result<Void, CYKeychainError> {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: accessibility.secValue
        ] as CFDictionary
        
        // 先删除已有项
        let deleteStatus = SecItemDelete(query)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            return .failure(.operationFailed(status: deleteStatus))
        }
        
        // 添加新项
        let status = SecItemAdd(query, nil)
        
        guard status == errSecSuccess else { return .failure(.operationFailed(status: status)) }
        return .success(())
    }
    
    /// 从 Keychain 读取 Data
    public func read(service: String, account: String) -> Data? {
        try? readResult(service: service, account: account).get()
    }

    public func readResult(service: String, account: String) -> Result<Data?, CYKeychainError> {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        switch status {
        case errSecSuccess: return .success(result as? Data)
        case errSecItemNotFound: return .success(nil)
        default: return .failure(.operationFailed(status: status))
        }
    }
    
    /// 从 Keychain 删除指定项
    @discardableResult
    public func delete(service: String, account: String) -> Result<Void, CYKeychainError> {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        let status = SecItemDelete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(.operationFailed(status: status))
        }
        return .success(())
    }
    
    // MARK: - String 便捷操作
    
    /// 保存字符串到 Keychain
    @discardableResult
    public func save(
        _ string: String,
        service: String,
        account: String,
        accessibility: CYKeychainAccessibility = .afterFirstUnlock
    ) -> Result<Void, CYKeychainError> {
        save(Data(string.utf8), service: service, account: account, accessibility: accessibility)
    }
    
    /// 从 Keychain 读取字符串
    public func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func readStringResult(service: String, account: String) -> Result<String?, CYKeychainError> {
        readResult(service: service, account: account).map { data in
            data.flatMap { String(data: $0, encoding: .utf8) }
        }
    }
}
