import CYAppCore
import CYAppNetwork
import CYAppImage
import CYFeedbackStyle

@MainActor
enum AppBootstrap {
    private static var didStart = false

    static func start(with config: ExampleAppConfig) {
        precondition(!didStart, "AppBootstrap.start(with:) must only be called once")

        CYCoreBootstrap.configure(config.core)

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
