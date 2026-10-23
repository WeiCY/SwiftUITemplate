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

/// 日志拦截器 — 默认记录脱敏后的 URL、Header 和状态，正文需显式开启。
///
/// `includeBody: true` 的输出示例：
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
    
    public init(includeBody: Bool = false) {
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
    
    /// 构造脱敏后的请求日志字符串
    static func redactedRequestDescription(_ request: URLRequest, includeBody: Bool = true) -> String {
        let method = request.httpMethod ?? "GET"
        let url = CYNetworkLogRedactor.url(request.url?.absoluteString ?? "unknown")
        
        var log = "→ \(method) \(url)"
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            let redacted = headers.reduce(into: [String: String]()) { result, item in
                result[item.key] = CYNetworkLogRedactor.isSensitive(item.key) ? "***" : item.value
            }
            log += "\n   Headers: \(redacted)"
        }
        
        if includeBody, let body = request.httpBody {
            log += "\n   Body: \(CYNetworkLogRedactor.body(body))"
        }
        
        return log
    }
    
    /// 构造脱敏后的响应日志字符串
    static func redactedResponseDescription(_ response: HTTPURLResponse, data: Data?, includeBody: Bool = true) -> String {
        let status = response.statusCode
        let url = CYNetworkLogRedactor.url(response.url?.absoluteString ?? "unknown")
        let icon = (200..<300).contains(status) ? "✅" : "❌"
        
        var log = "\(icon) ← \(status) \(url)"
        
        if includeBody, let data {
            let redacted = CYNetworkLogRedactor.body(data)
            let truncated = redacted.count > 500
                ? String(redacted.prefix(500)) + "... (\(redacted.count) chars)"
                : redacted
            log += "\n   Body: \(truncated)"
        }
        
        return log
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
            CYLogger.shared.error("Credential recovery failed (details omitted)")
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

    /// 取消当前等待会返回 false，但不会中断共享恢复或触发 onFailure。
    /// 调用方可用 Task.isCancelled 区分取消与恢复失败；网络客户端将取消映射为 .cancelled。
    public func recoverIfNeeded() async -> Bool {
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }
                waiters[id] = continuation
                guard recoveryTask == nil else { return }
                let task = Task { await recovery.attemptRecovery() }
                recoveryTask = task
                Task { finishRecovery(await task.value) }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    // Cancellation releases only this caller; shared recovery may still rotate credentials
    // for other requests. Do not cancel it, even when the last waiter leaves.
    private var waiters: [UUID: CheckedContinuation<Bool, Never>] = [:]

    private func cancelWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume(returning: false)
    }

    private func finishRecovery(_ result: Bool) {
        recoveryTask = nil
        let pending = waiters.values
        waiters.removeAll()
        for continuation in pending { continuation.resume(returning: result) }
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
