import Foundation

// MARK: - 依赖注入容器协议

/// 依赖注入容器协议（基础能力）
/// 业务代码只依赖此协议，不直接依赖 Factory 库
/// 替换 DI 框架时只需提供新的协议实现
///
/// 不包含网络能力：离线 App 仅依赖此协议即可，不感知 `CYAppNetwork`。
public protocol DIContainerProtocol {
    var cacheManager: CYCacheManager { get }
    var logger: CYLogger { get }
    var analyticsService: CYAnalyticsServiceProtocol { get }
    var imageLoader: CYImageLoaderProtocol { get }
    var permissionManager: CYPermissionManager { get }
    var requestDeduplicator: CYRequestDeduplicator { get }
    var toastManager: CYToastManagerProtocol { get }
    var loadingManager: CYLoadingManagerProtocol { get }
    var alertManager: CYAlertManagerProtocol { get }
    var themeManager: CYThemeManaging { get }
    var localizationManager: CYLocalizationManaging { get }
}

/// 网络能力协议（可选能力）
///
/// 只有需要网络的 Feature 才依赖此协议，并通过组合声明能力：
/// ```swift
/// final class HomeViewModel: CYBaseViewModel {
///     private let dependencies: any DIContainerProtocol & NetworkProviding
/// }
/// ```
///
/// 离线 Feature 只依赖 `DIContainerProtocol`，因此编译器不会要求它们提供 `networkClient`。
public protocol NetworkProviding {
    var networkClient: CYNetworkClientProtocol { get }
}
