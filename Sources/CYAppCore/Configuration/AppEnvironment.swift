import Foundation

/// App 运行环境。
///
/// 模板只定义开发和生产两个语义环境；实际服务地址和请求配置由宿主 App
/// 在启动时通过 `CYAppConfiguration.configure(_:)` 注入。
public enum CYAppEnvironment: String, CaseIterable, Sendable {
    case development
    case production

    /// 默认环境，仅用于宿主 App 尚未显式配置时。
    public static var current: CYAppEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }

    public var isDebugLoggingEnabled: Bool {
        self == .development
    }

    public var featureFlags: FeatureFlags {
        switch self {
        case .development:
            FeatureFlags(enableAnalytics: false, enableCrashReporting: false, enableDebugMenu: true)
        case .production:
            FeatureFlags(enableAnalytics: true, enableCrashReporting: true, enableDebugMenu: false)
        }
    }

    public struct FeatureFlags: Sendable {
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
