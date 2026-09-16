import Foundation

/// App 启动时由 Core 消费的基础配置。
///
/// 可选模块的配置由宿主 App 组合，避免 Core 反向依赖 Network、Image 或 UI 模块。
public struct CYAppConfig: Sendable {
    public var environment: CYAppEnvironment
    public var values: CYAppConfigurationValues
    public var minimumLogLevel: CYLogLevel

    public init(
        environment: CYAppEnvironment = .current,
        values: CYAppConfigurationValues = .init(),
        minimumLogLevel: CYLogLevel? = nil
    ) {
        self.environment = environment
        self.values = values
        self.minimumLogLevel = minimumLogLevel
            ?? (environment.isDebugLoggingEnabled ? .debug : .info)
    }
}

/// Core 启动配置器。只应用 Core 自己拥有的配置。
public enum CYCoreBootstrap {
    public static func configure(_ config: CYAppConfig) {
        CYAppConstants.configure(config.values)
        CYLogger.shared.setMinimumLevel(config.minimumLogLevel)
    }
}
