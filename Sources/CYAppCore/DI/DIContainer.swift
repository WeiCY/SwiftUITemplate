import Foundation

// MARK: - 依赖注入容器协议

/// 依赖注入容器协议
/// 业务代码只依赖此协议，不直接依赖 Factory 库
/// 替换 DI 框架时只需提供新的协议实现
public protocol DIContainerProtocol {
    var networkClient: CYNetworkClientProtocol { get }
    var cacheManager: CYCacheManager { get }
    var logger: CYLogger { get }
    var userSession: UserSessionProtocol { get }
    var authService: AuthServiceProtocol { get }
    var analyticsService: CYAnalyticsServiceProtocol { get }
    var imageLoader: CYImageLoaderProtocol { get }
    var permissionManager: CYPermissionManager { get }
    var appState: CYAppState { get }
}
