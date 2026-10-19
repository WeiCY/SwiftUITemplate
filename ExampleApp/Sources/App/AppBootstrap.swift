import CYAppCore
import CYAppNetwork
import CYAppImage
import CYFeedbackStyle
import CYAppDesignSystem
import Foundation
import FactoryKit

// MARK: - 组合根
//
// AppBootstrap 是唯一装配入口：Core 配置、网络配置、图片、反馈样式。
// 新增 App 时复制此文件，按需增减模块。

@MainActor
enum AppBootstrap {
    private static var didStart = false

    static func start(with config: ExampleAppConfig) {
        precondition(!didStart, "AppBootstrap.start(with:) must only be called once")

        CYCoreBootstrap.configure(config.core)
        CYDesignConfiguration.configure(ProcessInfo.processInfo.arguments.contains("--alternate-brand") ? .alternate : CYDesignTokens())

        if let network = config.network {
            CYNetworkConfiguration.configure(
                environment: config.core.environment,
                baseURL: network.baseURL,
                defaultHeaders: network.defaultHeaders,
                timeoutInterval: network.timeoutInterval,
                requestInterceptors: network.requestInterceptors,
                responseInterceptors: network.responseInterceptors
            )
            CYBusinessCodePolicy.configure { $0 = network.businessCodePolicy }
        }

        // 设 config.usesMockNetwork = false 并配置真实 baseURL 即可切换。
        if config.usesMockNetwork {
            let mockClient = MockNetworkClient()
            mockClient.defaultDelay = 0.6
            mockClient.registerResponse(Article.samples)
            Container.shared.networkClient.register { mockClient }
        }

        if config.usesKingfisher {
            CYAppImageConfig.configure()
        }

        CYFeedbackConfiguration.configure(
            toastStyle: config.toastStyle,
            loadingStyle: config.loadingStyle,
            errorStyle: config.errorStyle
        )
        didStart = true
    }
}
