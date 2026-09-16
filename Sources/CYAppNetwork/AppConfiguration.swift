import Foundation
import FactoryKit
import CYAppCore

/// 由宿主 App 在启动时注入的网络配置。
///
/// 在首次访问 `CYAppContainer.shared` 前调用一次：
/// ```swift
/// CYNetworkConfiguration.configure(
///     environment: .development,
///     baseURL: "https://dev-api.example.com",
///     defaultHeaders: ["X-App-Version": "1.0.0"],
///     timeoutInterval: 30
/// )
/// ```
@MainActor
public enum CYNetworkConfiguration {
    private static let lock = NSLock()
    private static var didConfigure = false

    /// 配置默认网络客户端。
    ///
    /// - Important: 必须在首次解析 `CYAppContainer.shared.networkClient` 前调用。
    public static func configure(
        environment: CYAppEnvironment = .current,
        baseURL: String,
        defaultHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval? = nil,
        requestInterceptors: [any CYRequestInterceptor] = [],
        responseInterceptors: [any CYResponseInterceptor] = []
    ) {
        lock.lock()
        defer { lock.unlock() }

        precondition(!didConfigure, "CYNetworkConfiguration.configure(_:) 只能在应用启动时调用一次")

        let effectiveTimeout = timeoutInterval ?? (environment.isDebugLoggingEnabled ? 60 : 30)
        let client = CYNetworkClient(
            baseURL: baseURL,
            defaultHeaders: defaultHeaders,
            timeoutInterval: effectiveTimeout,
            requestInterceptors: requestInterceptors,
            responseInterceptors: responseInterceptors
        )

        Container.shared.networkClient.register { client }
        didConfigure = true
    }
}

/// Compatibility namespace for the former network configuration API.
@available(*, deprecated, renamed: "CYNetworkConfiguration")
public typealias CYAppConfiguration = CYNetworkConfiguration
