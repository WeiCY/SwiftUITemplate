import Foundation
import os

/// 宿主 App 在启动时可注入的核心默认值。
///
/// 应在创建 `CYCacheManager`、认证服务或分页 ViewModel 前调用
/// `CYAppConstants.configure(_:)`。未配置时使用模板默认值。
public struct CYAppConfigurationValues: Sendable {
    public var cacheDirectoryName: String
    public var keychainService: String
    public var defaultPageSize: Int
    public var toastDuration: TimeInterval
    public var maxUploadSizeMB: Int

    public init(
        cacheDirectoryName: String = "AppCache",
        keychainService: String = "com.cyapp.auth",
        defaultPageSize: Int = 20,
        toastDuration: TimeInterval = 2.0,
        maxUploadSizeMB: Int = 10
    ) {
        precondition(!cacheDirectoryName.isEmpty, "cacheDirectoryName cannot be empty")
        precondition(!keychainService.isEmpty, "keychainService cannot be empty")
        precondition(defaultPageSize > 0, "defaultPageSize must be greater than zero")
        precondition(toastDuration >= 0, "toastDuration cannot be negative")
        precondition(maxUploadSizeMB > 0, "maxUploadSizeMB must be greater than zero")
        self.cacheDirectoryName = cacheDirectoryName
        self.keychainService = keychainService
        self.defaultPageSize = defaultPageSize
        self.toastDuration = toastDuration
        self.maxUploadSizeMB = maxUploadSizeMB
    }
}

// MARK: - 全局常量

public enum CYAppConstants {
    private static let configurationLock = OSAllocatedUnfairLock(initialState: CYAppConfigurationValues())

    /// 配置核心默认值。应只在 App 启动阶段调用。
    public static func configure(_ values: CYAppConfigurationValues) {
        configurationLock.withLock { $0 = values }
    }

    /// 当前配置快照，便于将同一配置传递给自定义服务。
    public static var configuration: CYAppConfigurationValues {
        configurationLock.withLock { $0 }
    }

    public static let appName = "SwiftUITemplate"
    public static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    public static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    public static var cacheDirectoryName: String { configuration.cacheDirectoryName }
    public static var keychainService: String { configuration.keychainService }
    public static var defaultPageSize: Int { configuration.defaultPageSize }
    public static var toastDuration: TimeInterval { configuration.toastDuration }
    public static var maxUploadSizeMB: Int { configuration.maxUploadSizeMB }

    public static let keyUserToken = "user_auth_token"
    public static let keyOnboardingShown = "has_shown_onboarding"
    public static let keyThemePreference = "user_theme_pref"
    public static let keyLanguagePreference = "user_language_pref"
    public static let maxUsernameLength = 20
    public static let minPasswordLength = 8
}
