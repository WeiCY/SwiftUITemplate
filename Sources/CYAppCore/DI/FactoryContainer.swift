import Foundation
import Factory

// MARK: - Factory 容器（桥接层）
//
// 使用 Factory 库实现的依赖注入容器。
// 内部使用 Factory @Injected 模式，对外只暴露 DIContainerProtocol。
//
// Factory 优势：
// - 编译时类型安全
// - 支持 @Injected 属性包装器
// - 内置 Mock 注入能力，方便测试

// MARK: - 工厂容器 扩展

extension Container {
    /// 网络客户端
    public var networkClient: Factory<CYNetworkClientProtocol> {
        self { CYNetworkClient.shared }
    }
    
    /// 缓存管理器
    public var cacheManager: Factory<CYCacheManager> {
        self { CYCacheManager.shared }
    }
    
    /// 日志工具
    public var logger: Factory<CYLogger> {
        self { CYLogger.shared }
    }
    
    /// 用户会话
    public var userSession: Factory<UserSessionProtocol> {
        self { CYUserSession() }.singleton
    }
    
    /// 认证服务
    public var authService: Factory<AuthServiceProtocol> {
        self { CYAuthService(userSession: self.userSession()) }
    }
    
    /// 分析服务
    public var analyticsService: Factory<CYAnalyticsServiceProtocol> {
        self { CYAnalyticsService() }
    }
    
    /// 图片加载器
    public var imageLoader: Factory<CYImageLoaderProtocol> {
        self { CYKingfisherImageLoader.shared }
    }
    
    /// 权限管理器
    public var permissionManager: Factory<CYPermissionManager> {
        self { CYPermissionManager.shared }
    }
    
    /// 全局 App 状态
    public var appState: Factory<CYAppState> {
        self { CYAppState() }.singleton
    }
}

// MARK: - CYFactoryContainer 实现

/// Factory 容器实现类
public final class CYFactoryContainer: DIContainerProtocol {
    
    public static let shared = CYFactoryContainer()
    
    private let container = Container.shared
    
    // MARK: - DIContainerProtocol 实现
    
    public var networkClient: CYNetworkClientProtocol { container.networkClient() }
    public var cacheManager: CYCacheManager { container.cacheManager() }
    public var logger: CYLogger { container.logger() }
    public var userSession: UserSessionProtocol { container.userSession() }
    public var authService: AuthServiceProtocol { container.authService() }
    public var analyticsService: CYAnalyticsServiceProtocol { container.analyticsService() }
    public var imageLoader: CYImageLoaderProtocol { container.imageLoader() }
    public var permissionManager: CYPermissionManager { container.permissionManager() }
    public var appState: CYAppState { container.appState() }
    
    public init() {}
}
