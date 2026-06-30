import Foundation

// MARK: - 全局常量
//
// 集中管理 App 的常量配置，包括网络超时、分页大小、存储 Key 等。
//
// 用法：
// ```swift
// let url = CYAppConstants.baseURL
// let timeout = CYAppConstants.timeoutInterval
// CYKeychainHelper.standard.save(token, service: CYAppConstants.keyUserToken, ...)
// ```

public struct CYAppConstants {
    
    // MARK: - App 信息
    
    /// App 名称
    public static let appName = "SwiftUITemplate"
    /// App 版本号
    public static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    /// Build 号
    public static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - 网络配置
    
    /// API 基础 URL
    public static var baseURL: String { CYAppEnvironment.current.baseURL }
    /// 请求超时时间（秒）
    public static let timeoutInterval: TimeInterval = 30.0
    /// 最大重试次数
    public static let maxRetryAttempts = 3
    
    // MARK: - 默认值
    
    /// 默认每页数量
    public static let defaultPageSize = 20
    /// 默认动画时长（秒）
    public static let animationDuration: TimeInterval = 0.3
    /// Toast 显示时长（秒）
    public static let toastDuration: TimeInterval = 2.0
    
    // MARK: - 存储 Key（UserDefaults / Keychain）
    
    /// 用户 Token Key
    public static let keyUserToken = "user_auth_token"
    /// 引导页是否已展示
    public static let keyOnboardingShown = "has_shown_onboarding"
    /// 主题偏好
    public static let keyThemePreference = "user_theme_pref"
    /// 语言偏好
    public static let keyLanguagePreference = "user_language_pref"
    
    // MARK: - 限制
    
    /// 最大上传大小（MB）
    public static let maxUploadSizeMB = 10
    /// 用户名最大长度
    public static let maxUsernameLength = 20
    /// 密码最小长度
    public static let minPasswordLength = 8
}
