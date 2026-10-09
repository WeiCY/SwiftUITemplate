import Foundation

// MARK: - App 依赖注入容器（Facade）

/// App 依赖注入容器
/// 作为 CYFactoryContainer 的 facade，保持向后兼容
/// 业务代码通过 `CYAppContainer.shared` 获取依赖
///
/// - Note: 该类型属于 Legacy / Compatibility Facade。新业务优先使用初始化注入或
///   `@Injected`，待真实项目迁移完成后再考虑下线。
///
/// 如需使用 Factory 的 @Injected 属性包装器，可直接在 Feature 中使用：
/// ```swift
/// @Injected(\.networkClient) var networkClient
/// ```
public final class CYAppContainer: DIContainerProtocol, NetworkProviding, Sendable {

    public static let shared = CYAppContainer()

    /// 底层 Factory 容器
    private let factory = CYFactoryContainer.shared
    
    // MARK: - NetworkProviding 实现（委托到 Factory）
    
    public var networkClient: CYNetworkClientProtocol { factory.networkClient }
    
    // MARK: - DIContainerProtocol 实现（委托到 Factory）
    
    public var cacheManager: CYCacheManager { factory.cacheManager }
    public var logger: CYLogger { factory.logger }
    public var analyticsService: CYAnalyticsServiceProtocol { factory.analyticsService }
    public var imageLoader: CYImageLoaderProtocol { factory.imageLoader }
    public var permissionManager: CYPermissionManager { factory.permissionManager }
    public var requestDeduplicator: CYRequestDeduplicator { factory.requestDeduplicator }
    public var toastManager: CYToastManagerProtocol { factory.toastManager }
    public var loadingManager: CYLoadingManagerProtocol { factory.loadingManager }
    public var alertManager: CYAlertManagerProtocol { factory.alertManager }
    public var themeManager: CYThemeManaging { factory.themeManager }
    public var localizationManager: CYLocalizationManaging { factory.localizationManager }
    
    public init() {}
}
