import Foundation

/// App 运行环境枚举
/// 通过编译配置自动选择环境，不同环境使用不同的 baseURL、API Key 等配置
///
/// 切换方式：
/// - Debug 构建 → .development
/// - Release 构建 → .production
/// - 可通过 Xcode Scheme 添加 `-D STAGING` 编译标志切换到 .staging
public enum CYAppEnvironment: String, CaseIterable {
    case development
    case staging
    case production
    
    /// 当前环境 — 通过编译宏自动选择
    public static var current: CYAppEnvironment {
        #if STAGING
        return .staging
        #elseif DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    // MARK: - API 配置
    
    /// 基础 URL — 替换为你的实际 API 地址
    public var baseURL: String {
        switch self {
        case .development:
            return "https://dev-api.example.com"
        case .staging:
            return "https://staging-api.example.com"
        case .production:
            return "https://api.example.com"
        }
    }
    
    /// API Key（如需要）
    public var apiKey: String {
        switch self {
        case .development:
            return "dev-key-placeholder"
        case .staging:
            return "staging-key-placeholder"
        case .production:
            return "prod-key-placeholder"
        }
    }
    
    // MARK: - 功能开关
    
    /// 是否启用调试日志
    public var isDebugLoggingEnabled: Bool {
        switch self {
        case .development: return true
        case .staging: return true
        case .production: return false
        }
    }
    
    /// 功能开关
    public var featureFlags: FeatureFlags {
        switch self {
        case .development:
            return FeatureFlags(enableAnalytics: false, enableCrashReporting: false, enableDebugMenu: true)
        case .staging:
            return FeatureFlags(enableAnalytics: true, enableCrashReporting: true, enableDebugMenu: true)
        case .production:
            return FeatureFlags(enableAnalytics: true, enableCrashReporting: true, enableDebugMenu: false)
        }
    }
    
    // MARK: - 功能开关结构体
    
    public struct FeatureFlags {
        public let enableAnalytics: Bool
        public let enableCrashReporting: Bool
        public let enableDebugMenu: Bool
        
        public init(enableAnalytics: Bool, enableCrashReporting: Bool, enableDebugMenu: Bool) {
            self.enableAnalytics = enableAnalytics
            self.enableCrashReporting = enableCrashReporting
            self.enableDebugMenu = enableDebugMenu
        }
    }
}
