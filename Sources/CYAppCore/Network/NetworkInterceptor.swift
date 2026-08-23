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
        CYLogger.shared.debug(Self.redactedRequestDescription(request, includeBody: includeBody))
    }
    
    public func intercept(_ response: URLResponse?, data: Data?) async throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        CYLogger.shared.debug(Self.redactedResponseDescription(httpResponse, data: data, includeBody: includeBody))
    }
    
    // MARK: - 日志脱敏纯函数（internal，供测试直接验证）
    
    /// 敏感请求头名称（值一律脱敏为 `***`），匹配时不区分大小写
    private static let sensitiveHeaderNames: Set<String> = [
        "authorization", "proxy-authorization", "cookie",
        "x-api-key", "apikey", "api_key", "x-auth-token", "token"
    ]
    
    /// 敏感 JSON 字段（值一律脱敏为 `***`），匹配时不区分大小写
    private static let sensitiveBodyKeys = [
        "password", "token", "access_token", "refresh_token",
        "secret", "api_key", "apikey", "authorization"
    ]
    
    /// 构造脱敏后的请求日志字符串
    static func redactedRequestDescription(_ request: URLRequest, includeBody: Bool = true) -> String {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        
        var log = "→ \(method) \(url)"
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            let redacted = headers.reduce(into: [String: String]()) { result, item in
                result[item.key] = isSensitiveHeader(item.key) ? "***" : item.value
            }
            log += "\n   Headers: \(redacted)"
        }
        
        if includeBody, let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            log += "\n   Body: \(redactSensitiveBodyFields(bodyString))"
        }
        
        return log
    }
    
    /// 构造脱敏后的响应日志字符串
    static func redactedResponseDescription(_ response: HTTPURLResponse, data: Data?, includeBody: Bool = true) -> String {
        let status = response.statusCode
        let url = response.url?.absoluteString ?? "unknown"
        let icon = (200..<300).contains(status) ? "✅" : "❌"
        
        var log = "\(icon) ← \(status) \(url)"
        
        if includeBody, let data, let bodyString = String(data: data, encoding: .utf8) {
            let redacted = redactSensitiveBodyFields(bodyString)
            let truncated = redacted.count > 500
                ? String(redacted.prefix(500)) + "... (\(redacted.count) chars)"
                : redacted
            log += "\n   Body: \(truncated)"
        }
        
        return log
    }
    
    private static func isSensitiveHeader(_ name: String) -> Bool {
        sensitiveHeaderNames.contains(name.lowercased())
    }
    
    /// 将 JSON 文本中敏感字段的值替换为 `***`
    private static func redactSensitiveBodyFields(_ bodyString: String) -> String {
        let keys = sensitiveBodyKeys.joined(separator: "|")
        let pattern = "(\"(?:" + keys + ")\"\\s*:\\s*)(?:\"[^\"]*\"|true|false|-?\\d+(?:\\.\\d+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return bodyString
        }
        let range = NSRange(location: 0, length: (bodyString as NSString).length)
        return regex.stringByReplacingMatches(in: bodyString, options: [], range: range, withTemplate: "$1\"***\"")
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
    ///
    /// 注意：并发安全由 `CYTokenRefreshCoordinator` 保证，
    /// 多个请求同时 401 时只有第一个真正发起刷新，其余复用同一次结果。
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

// MARK: - Token 刷新并发协调器

/// 401 并发刷新协调器（actor 保证线程安全）
///
/// 多个请求同时收到 401 时，仅第一个请求真正调用 `attemptRefresh()`，
/// 其余请求挂起并复用同一个刷新结果，避免并发刷新导致 RefreshToken 被多次消费。
///
/// 由 `CYNetworkClient.setTokenRefreshInterceptor(_:)` 内部创建并持有。
public actor CYTokenRefreshCoordinator {
    private var refreshTask: Task<TokenPair?, Never>?
    private let interceptor: CYTokenRefreshInterceptor
    
    public init(interceptor: CYTokenRefreshInterceptor) {
        self.interceptor = interceptor
    }
    
    /// 触发一次刷新（并发去重）。
    /// - Returns: 新的 TokenPair（刷新成功），nil（无 RefreshToken 或刷新失败）
    public func refreshIfNeeded() async -> TokenPair? {
        if let existing = refreshTask {
            return await existing.value
        }
        let task = Task { await interceptor.attemptRefresh() }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
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
