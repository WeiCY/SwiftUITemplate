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
/// ✅ ← 200 https://api.example.com/auth/login
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

// MARK: - 凭证注入

/// Network 内部用于传递端点策略的专用拦截器协议。
public protocol CYAuthenticationRequestInterceptor: CYRequestInterceptor {
    func intercept(_ request: inout URLRequest, authentication: CYAuthenticationPolicy) async throws
}

/// 按端点策略注入完整 Authorization Header。
/// Header 的格式、存储和生命周期均由宿主 App 决定。
public struct CYCredentialInterceptor: CYAuthenticationRequestInterceptor, Sendable {
    private let authorizationHeaderProvider: @Sendable () async -> String?

    public init(authorizationHeaderProvider: @escaping @Sendable () async -> String?) {
        self.authorizationHeaderProvider = authorizationHeaderProvider
    }

    public func intercept(_ request: inout URLRequest) async {}

    public func intercept(
        _ request: inout URLRequest,
        authentication: CYAuthenticationPolicy
    ) async throws {
        guard authentication != .none else { return }
        guard let header = await authorizationHeaderProvider() else {
            if authentication == .required { throw CYNetworkError.credentialUnavailable }
            return
        }
        request.setValue(header, forHTTPHeaderField: "Authorization")
    }
}

// MARK: - 凭证恢复

/// 宿主提供的中性凭证恢复动作。成功后，Network 会重新读取凭证并重放一次请求。
public struct CYCredentialRecovery: Sendable {
    private let action: @Sendable () async throws -> Bool
    private let onFailure: @Sendable () async -> Void

    public init(
        action: @escaping @Sendable () async throws -> Bool,
        onFailure: @escaping @Sendable () async -> Void = {}
    ) {
        self.action = action
        self.onFailure = onFailure
    }

    public func attemptRecovery() async -> Bool {
        do {
            let recovered = try await action()
            if !recovered { await onFailure() }
            return recovered
        } catch {
            CYLogger.shared.error("Credential recovery failed", error: error)
            await onFailure()
            return false
        }
    }
}

/// 对并发认证失败执行 single-flight，避免重复恢复同一凭证。
public actor CYCredentialRecoveryCoordinator {
    private var recoveryTask: Task<Bool, Never>?
    private let recovery: CYCredentialRecovery

    public init(recovery: CYCredentialRecovery) {
        self.recovery = recovery
    }

    public func recoverIfNeeded() async -> Bool {
        if let existing = recoveryTask { return await existing.value }
        let task = Task { await recovery.attemptRecovery() }
        recoveryTask = task
        let result = await task.value
        recoveryTask = nil
        return result
    }
}

/// 将终态 401 报告给宿主。如何清理凭证或改变界面状态由宿主决定。
public struct CYAuthenticationFailureInterceptor: CYResponseInterceptor, Sendable {
    private let onAuthenticationFailure: @Sendable () async -> Void

    public init(onAuthenticationFailure: @escaping @Sendable () async -> Void) {
        self.onAuthenticationFailure = onAuthenticationFailure
    }

    public func intercept(_ response: URLResponse?, data: Data?) async throws {
        guard let response = response as? HTTPURLResponse, response.statusCode == 401 else { return }
        await onAuthenticationFailure()
    }
}
