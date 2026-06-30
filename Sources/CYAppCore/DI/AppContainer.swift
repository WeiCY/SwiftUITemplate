import Foundation

// MARK: - App 依赖注入容器（Facade）

/// App 依赖注入容器
/// 作为 CYFactoryContainer 的 facade，保持向后兼容
/// 业务代码通过 `CYAppContainer.shared` 获取依赖
///
/// 如需使用 Factory 的 @Injected 属性包装器，可直接在 Feature 中使用：
/// ```swift
/// @Injected(\.networkClient) var networkClient
/// ```
public final class CYAppContainer: DIContainerProtocol {
    
    public static let shared = CYAppContainer()
    
    /// 底层 Factory 容器
    private let factory = CYFactoryContainer.shared
    
    // MARK: - DIContainerProtocol 实现（委托到 Factory）
    
    public var networkClient: CYNetworkClientProtocol { factory.networkClient }
    public var cacheManager: CYCacheManager { factory.cacheManager }
    public var logger: CYLogger { factory.logger }
    public var userSession: UserSessionProtocol { factory.userSession }
    public var authService: AuthServiceProtocol { factory.authService }
    public var analyticsService: CYAnalyticsServiceProtocol { factory.analyticsService }
    public var imageLoader: CYImageLoaderProtocol { factory.imageLoader }
    public var permissionManager: CYPermissionManager { factory.permissionManager }
    public var appState: CYAppState { factory.appState }
    
    public init() {}
}
