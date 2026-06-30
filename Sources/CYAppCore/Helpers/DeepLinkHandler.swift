import Foundation

/// 深链接/Universal Link 处理器
///
/// 解析 URL 并分发到对应的业务处理逻辑。
///
/// 用法：
/// ```swift
/// // 1. 注册路由
/// CYDeepLinkHandler.shared.register(scheme: "myapp") { url in
///     switch url.host {
///     case "product":
///         let id = url.queryParameters["id"]
///         // 导航到商品详情
///     case "profile":
///         // 导航到个人主页
///     default: break
///     }
/// }
///
/// // 2. 在 App 入口处理
/// .onOpenURL { url in
///     CYDeepLinkHandler.shared.handle(url: url)
/// }
/// ```
@MainActor
public final class CYDeepLinkHandler {
    
    public static let shared = CYDeepLinkHandler()
    
    /// 最后一次处理的 URL（用于调试）
    public var lastHandledURL: URL?
    
    private var handlers: [(scheme: String?, host: String?, handler: (URL) -> Void)] = []
    
    private init() {}
    
    /// 注册深链接处理逻辑
    /// - 参数：
    ///   - scheme: URL Scheme（如 "myapp"），nil 匹配所有 scheme
    ///   - host: URL Host（如 "product"），nil 匹配所有 host
    ///   - handler: 处理闭包
    public func register(scheme: String? = nil, host: String? = nil, handler: @escaping (URL) -> Void) {
        handlers.append((scheme: scheme, host: host, handler: handler))
    }
    
    /// 处理收到的 URL
    /// - Returns: true 如果找到匹配的处理逻辑
    @discardableResult
    public func handle(url: URL) -> Bool {
        lastHandledURL = url
        
        for entry in handlers {
            let schemeMatch = entry.scheme == nil || entry.scheme == url.scheme
            let hostMatch = entry.host == nil || entry.host == url.host
            if schemeMatch && hostMatch {
                entry.handler(url)
                return true
            }
        }
        
        return false
    }
    
    /// 清除所有已注册的处理逻辑
    public func clearAll() {
        handlers.removeAll()
    }
}

// MARK: - URL Query Parameters Helper

extension URL {
    /// 便捷访问 URL 查询参数
    /// 用法: url.queryParameters["id"] → "123"
    public var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return [:] }
        
        var params = [String: String]()
        for item in queryItems {
            params[item.name] = item.value ?? ""
        }
        return params
    }
}
