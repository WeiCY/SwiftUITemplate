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

public final class CYKeychainHelper: Sendable {
    public static let standard = CYKeychainHelper()

    private let updateItem: @Sendable (CFDictionary, CFDictionary) -> OSStatus
    private let addItem: @Sendable (CFDictionary) -> OSStatus

    init(
        update: @escaping @Sendable (CFDictionary, CFDictionary) -> OSStatus = { SecItemUpdate($0, $1) },
        add: @escaping @Sendable (CFDictionary) -> OSStatus = { SecItemAdd($0, nil) }
    ) {
        updateItem = update
        addItem = add
    }
    
    // MARK: - Data 操作
    
    /// 按 service/account 更新，条目不存在时添加；失败不主动删除旧条目。
    @discardableResult
    public func save(
        _ data: Data,
        service: String,
        account: String,
        accessibility: CYKeychainAccessibility = .afterFirstUnlock
    ) -> Result<Void, CYKeychainError> {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let values: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.secValue
        ]
        var status = updateItem(identity as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            let item = identity.merging(values, uniquingKeysWith: { _, new in new })
            status = addItem(item as CFDictionary)
            // Another writer may have inserted the same identity after the initial update.
            if status == errSecDuplicateItem {
                status = updateItem(identity as CFDictionary, values as CFDictionary)
            }
        }
        guard status == errSecSuccess else { return .failure(.operationFailed(status: status)) }
        return .success(())
    }

    /// 从 Keychain 读取 Data
    public func read(service: String, account: String) -> Data? {
        switch readResult(service: service, account: account) {
        case .success(let data):
            return data
        case .failure(let error):
            CYLogger.auth.error("Failed to read keychain item", error: error)
            return nil
        }
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

    /// 使用当前模板默认 Keychain service 保存字符串。
    @discardableResult
    public func save(
        _ string: String,
        account: String,
        accessibility: CYKeychainAccessibility = .afterFirstUnlock
    ) -> Result<Void, CYKeychainError> {
        save(string, service: CYAppConstants.keychainService, account: account, accessibility: accessibility)
    }

    /// 使用当前模板默认 Keychain service 读取字符串。
    public func readString(account: String) -> String? {
        readString(service: CYAppConstants.keychainService, account: account)
    }

    /// 使用当前模板默认 Keychain service 读取字符串的 Result 版本。
    public func readStringResult(account: String) -> Result<String?, CYKeychainError> {
        readStringResult(service: CYAppConstants.keychainService, account: account)
    }

    /// 使用当前模板默认 Keychain service 删除条目。
    @discardableResult
    public func delete(account: String) -> Result<Void, CYKeychainError> {
        delete(service: CYAppConstants.keychainService, account: account)
    }
}
