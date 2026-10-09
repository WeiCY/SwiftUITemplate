import Foundation
import CYAppCore
import CYAppNetwork
import CYFeedbackStyle

struct ExampleAppConfig {
    struct Network {
        var baseURL: String
        var defaultHeaders: [String: String]
        var timeoutInterval: TimeInterval
        var businessCodePolicy: CYBusinessCodePolicy
        var requestInterceptors: [any CYRequestInterceptor]
        var responseInterceptors: [any CYResponseInterceptor]
    }

    var core: CYAppConfig
    var network: Network?
    var usesKingfisher: Bool
    var toastStyle: CYToastStyle
    var loadingStyle: CYLoadingStyle
    var errorStyle: CYErrorStyle

    @MainActor static let `default` = ExampleAppConfig(
        core: CYAppConfig(environment: .development),
        network: Network(
            baseURL: "https://dev-api.example.com",
            defaultHeaders: ["X-App-Platform": "iOS"],
            timeoutInterval: 30,
            businessCodePolicy: .default,
            requestInterceptors: [],
            responseInterceptors: []
        ),
        usesKingfisher: true,
        toastStyle: CYToastStyle(position: .center),
        loadingStyle: .default,
        errorStyle: .default
    )
}
