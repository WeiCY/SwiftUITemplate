import Foundation

// MARK: - 请求拦截器

/// 请求拦截器协议
/// 在请求发送前统一注入 Header、Token、日志等
public protocol CYRequestInterceptor: Sendable {
    func intercept(_ request: inout URLRequest) async
}

// MARK: - 响应拦截器

/// 响应拦截器协议
/// 在响应返回后统一处理（如日志、错误码统一处理等）
public protocol CYResponseInterceptor: Sendable {
    func intercept(_ response: URLResponse?, data: Data?) async throws
}

// MARK: - 日志拦截器

/// 日志拦截器 — 打印完整的请求和响应信息
///
/// 输出示例：
/// ```
/// → POST https://api.example.com/auth/login
///   Headers: [Content-Type: application/json]
///   Body: {"username":"john","password":"***"}
/// ← 200 https://api.example.com/auth/login (245ms)
///   Body: {"code":0,"data":{...},"message":"success"}
/// ```
public struct CYLoggingInterceptor: CYRequestInterceptor, CYResponseInterceptor, Sendable {
    
    /// 是否打印请求/响应 Body
    private let includeBody: Bool
    
    public init(includeBody: Bool = true) {
        self.includeBody = includeBody
    }
    
    public func intercept(_ request: inout URLRequest) async {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        
        var log = "→ \(method) \(url)"
        
        // 请求头
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            log += "\n   Headers: \(headers)"
        }
        
        // 请求体
        if includeBody, let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            log += "\n   Body: \(bodyString)"
        }
        
        CYLogger.shared.debug(log)
    }
    
    public func intercept(_ response: URLResponse?, data: Data?) async throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        let status = httpResponse.statusCode
        let url = httpResponse.url?.absoluteString ?? "unknown"
        let icon = (200..<300).contains(status) ? "✅" : "❌"
        
        var log = "\(icon) ← \(status) \(url)"
        
        // 响应体
        if includeBody, let data, let bodyString = String(data: data, encoding: .utf8) {
            // 截断过长的响应体
            let truncated = bodyString.count > 500
                ? String(bodyString.prefix(500)) + "... (\(bodyString.count) chars)"
                : bodyString
            log += "\n   Body: \(truncated)"
        }
        
        CYLogger.shared.debug(log)
    }
}

// MARK: - Token 注入拦截器

/// Token 注入拦截器 — 自动在请求头中添加 Authorization
public struct CYAuthInterceptor: CYRequestInterceptor, Sendable {
    private let tokenProvider: @Sendable () -> String?
    
    public init(tokenProvider: @escaping @Sendable () -> String?) {
        self.tokenProvider = tokenProvider
    }
    
    public func intercept(_ request: inout URLRequest) async {
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - Token 自动刷新拦截器

/// Token 自动刷新拦截器
///
/// 当收到 401 响应时，自动使用 RefreshToken 换取新 AccessToken 并重试请求。
/// 内置并发锁防止多个请求同时刷新 Token。
///
/// 用法：
/// ```swift
/// let refreshInterceptor = CYTokenRefreshInterceptor(
///     refreshTokenProvider: { [weak session] in session?.refreshToken },
///     onTokenRefreshed: { [weak session] newToken in
///         await session?.updateToken(newToken)
///     },
///     refreshAction: { refreshToken in
///         try await authService.refreshToken(refreshToken)
///     },
///     onRefreshFailed: { [weak session] in
///         await session?.clear()  // 刷新失败，强制登出
///     }
/// )
/// ```
public struct CYTokenRefreshInterceptor: Sendable {
    
    /// 获取当前 RefreshToken
    private let refreshTokenProvider: @Sendable () -> String?
    
    /// Token 刷新成功回调
    private let onTokenRefreshed: @Sendable (TokenPair) async -> Void
    
    /// 执行刷新动作（调用 API）
    private let refreshAction: @Sendable (String) async throws -> TokenPair
    
    /// 刷新失败回调（通常执行登出）
    private let onRefreshFailed: @Sendable () async -> Void
    
    public init(
        refreshTokenProvider: @escaping @Sendable () -> String?,
        onTokenRefreshed: @escaping @Sendable (TokenPair) async -> Void,
        refreshAction: @escaping @Sendable (String) async throws -> TokenPair,
        onRefreshFailed: @escaping @Sendable () async -> Void
    ) {
        self.refreshTokenProvider = refreshTokenProvider
        self.onTokenRefreshed = onTokenRefreshed
        self.refreshAction = refreshAction
        self.onRefreshFailed = onRefreshFailed
    }
    
    /// 尝试刷新 Token
    ///
    /// - Returns: 新的 TokenPair（刷新成功），nil（无 RefreshToken 或刷新失败）
    public func attemptRefresh() async -> TokenPair? {
        guard let refreshToken = refreshTokenProvider() else {
            await onRefreshFailed()
            return nil
        }
        
        do {
            let newToken = try await refreshAction(refreshToken)
            await onTokenRefreshed(newToken)
            return newToken
        } catch {
            CYLogger.shared.error("Token 刷新失败", error: error)
            await onRefreshFailed()
            return nil
        }
    }
}

// MARK: - 401 自动登出拦截器

/// 401 自动登出拦截器
///
/// 收到 401 Unauthorized 响应时自动触发登出流程。
/// 配合 CYTokenRefreshInterceptor 使用：
/// 1. 先尝试 RefreshInterceptor 刷新 Token
/// 2. 如果刷新也失败，AutoLogoutInterceptor 触发登出
///
/// 用法：
/// ```swift
/// let autoLogout = CYAutoLogoutInterceptor(
///     onUnauthorized: { [weak appState] in
///         await appState?.setLoggedIn(false)
///         await appState?.selectedTab = .home
///     }
/// )
/// ```
public struct CYAutoLogoutInterceptor: CYResponseInterceptor, Sendable {
    
    private let onUnauthorized: @Sendable () async -> Void
    
    public init(onUnauthorized: @escaping @Sendable () async -> Void) {
        self.onUnauthorized = onUnauthorized
    }
    
    public func intercept(_ response: URLResponse?, data: Data?) async throws {
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 401 else { return }
        
        CYLogger.shared.error("收到 401，触发自动登出")
        await onUnauthorized()
    }
}
