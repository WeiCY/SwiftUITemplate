import Foundation
import FactoryKit

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
        self {
            preconditionFailure("请先在 App 启动时通过 DI 注册 networkClient")
        }
    }
    
    /// 缓存管理器
    public var cacheManager: Factory<CYCacheManager> {
        self { CYCacheManager.shared }
    }
    
    /// 日志工具
    public var logger: Factory<CYLogger> {
        self { CYLogger.shared }
    }
    
    /// 分析服务
    public var analyticsService: Factory<CYAnalyticsServiceProtocol> {
        self { CYAnalyticsService() }
    }
    
    /// 图片加载器。
    /// 默认提供基于 `URLSession` 的轻量实现，无需强制导入 `CYAppImage`。
    /// 若需 Kingfisher 的高级能力，调用 `CYAppImageConfig.configure()` 覆盖即可。
    public var imageLoader: Factory<CYImageLoaderProtocol> {
        self { CYDefaultImageLoader.shared }
    }
    
    /// 权限管理器
    public var permissionManager: Factory<CYPermissionManager> {
        self { CYPermissionManager.shared }
    }
    
    // MARK: - 网络请求去重器
    
    /// 请求去重器（用于防止重复请求）
    public var requestDeduplicator: Factory<CYRequestDeduplicator> {
        self { CYRequestDeduplicator() }
            .singleton
    }
    
    // MARK: - UI 管理器
    
    /// Toast 管理器
    public var toastManager: Factory<CYToastManagerProtocol> {
        self { CYToastManager.shared }.singleton
    }
    
    /// Loading 管理器
    public var loadingManager: Factory<CYLoadingManagerProtocol> {
        self { CYLoadingManager.shared }.singleton
    }
    
    /// Alert 管理器
    public var alertManager: Factory<CYAlertManagerProtocol> {
        self { CYAlertManager.shared }.singleton
    }
    
    /// 主题管理器
    public var themeManager: Factory<CYThemeManaging> {
        self { CYThemeManager.shared }.singleton
    }
    
    /// 多语言管理器
    public var localizationManager: Factory<CYLocalizationManaging> {
        self { CYLocalizationManager.shared }.singleton
    }
}

// MARK: - CYFactoryContainer 实现

/// Factory 容器实现类
public final class CYFactoryContainer: DIContainerProtocol, Sendable {
    
    public static let shared = CYFactoryContainer()
    
    private let container = Container.shared
    
    // MARK: - DIContainerProtocol 实现
    
    public var networkClient: CYNetworkClientProtocol { container.networkClient() }
    public var cacheManager: CYCacheManager { container.cacheManager() }
    public var logger: CYLogger { container.logger() }
    public var analyticsService: CYAnalyticsServiceProtocol { container.analyticsService() }
    public var imageLoader: CYImageLoaderProtocol { container.imageLoader() }
    public var permissionManager: CYPermissionManager { container.permissionManager() }
    public var requestDeduplicator: CYRequestDeduplicator { container.requestDeduplicator() }
    public var toastManager: CYToastManagerProtocol { container.toastManager() }
    public var loadingManager: CYLoadingManagerProtocol { container.loadingManager() }
    public var alertManager: CYAlertManagerProtocol { container.alertManager() }
    public var themeManager: CYThemeManaging { container.themeManager() }
    public var localizationManager: CYLocalizationManaging { container.localizationManager() }
    
    public init() {}
}
