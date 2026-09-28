import Foundation
import Alamofire
import Synchronization
import CYAppCore

// MARK: - 网络客户端实现

/// 网络请求失败（终态响应上下文包装）
///
/// 由底层「发送 + 解码」抛出不带响应拦截器副作用，交由上层在**终态**统一应用响应拦截器。
/// 这样瞬态 401（会被 Token 刷新 + 重放吞掉的响应）不会提前触发响应拦截器（如自动登出）。
struct NetworkFailure: Error, Sendable {
    /// 已映射的网络错误
    let cyError: CYNetworkError
    /// 底层 HTTP 响应（终态时传给响应拦截器）
    let response: URLResponse?
    /// 底层响应体
    let data: Data?
}

/// 网络客户端实现（Alamofire 桥接层）
///
/// 业务代码通过 `CYNetworkClientProtocol` 协议使用，不直接依赖 Alamofire。
///
/// 实现按职责拆分到多个文件：
/// - `NetworkClient.swift`：类核心、拦截器管理、凭证恢复、`send` 分发
/// - `NetworkClient+Request.swift`：URL 构建、编解码器、拦截器应用
/// - `NetworkClient+Response.swift`：发送、解码、业务码解析、错误映射
/// - `NetworkClient+Upload.swift`：上传 / 下载
///
/// 拦截器链执行顺序：
/// 1. 构建 URLRequest
/// 2. 依次执行所有 CYRequestInterceptor（注入 Header、Token 等）
/// 3. 发送请求
/// 4. 依次执行所有 CYResponseInterceptor（日志、统一错误处理等）
///
/// **凭证恢复（401 自动重放）：**
/// 注册 `CYCredentialRecovery` 后，`.required` 请求认证失败会恢复凭证并重试一次。
///
/// **并发安全：** 可变状态由 `Mutex` 保护，类型本身满足 `Sendable`，无 `@unchecked`。
///
/// **与 OC 时代的对比：**
/// | OC (YTKRequest / MJExtension) | Swift (本模板) |
/// |---|---|
/// | MJExtension 运行时字典解析 | Codable 编译时类型安全 |
/// | `[NSDictionary]` / `[Model]` | `[User]` 强类型 |
/// | 回调 block | async/await |
/// | 手动判断 code | `CYAPIResponse<T>` 自动解包 |
public final class CYNetworkClient: CYNetworkClientProtocol, Sendable {

    /// 可变状态（拦截器、刷新协调器）由同一把 `Mutex` 保护，避免数据竞争。
    private struct MutableState: Sendable {
        var requestInterceptors: [any CYRequestInterceptor] = []
        var responseInterceptors: [any CYResponseInterceptor] = []
        var credentialRecoveryCoordinator: CYCredentialRecoveryCoordinator?
    }

    let baseURL: String
    let defaultHeaders: [String: String]
    let timeoutInterval: TimeInterval
    let session: Session
    private let state: Mutex<MutableState>

    public init(
        baseURL: String,
        defaultHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 30,
        requestInterceptors: [any CYRequestInterceptor] = [],
        responseInterceptors: [any CYResponseInterceptor] = [],
        session: Session = AF
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
        self.session = session
        self.state = Mutex(MutableState(
            requestInterceptors: requestInterceptors,
            responseInterceptors: responseInterceptors
        ))
    }

    // MARK: - 拦截器管理

    /// 注册可选的凭证恢复动作。仅 `.required` 端点认证失败时执行并重放一次。
    public func setCredentialRecovery(_ recovery: CYCredentialRecovery) {
        let coordinator = CYCredentialRecoveryCoordinator(recovery: recovery)
        state.withLock { $0.credentialRecoveryCoordinator = coordinator }
    }

    /// 添加请求拦截器
    public func addRequestInterceptor(_ interceptor: any CYRequestInterceptor) {
        state.withLock { $0.requestInterceptors.append(interceptor) }
    }

    /// 添加响应拦截器
    public func addResponseInterceptor(_ interceptor: any CYResponseInterceptor) {
        state.withLock { $0.responseInterceptors.append(interceptor) }
    }

    /// 当前请求拦截器快照
    func currentRequestInterceptors() -> [any CYRequestInterceptor] {
        state.withLock { $0.requestInterceptors }
    }

    /// 当前响应拦截器快照
    func currentResponseInterceptors() -> [any CYResponseInterceptor] {
        state.withLock { $0.responseInterceptors }
    }

    // MARK: - 401 重试包装

    /// 统一封装「401 自动刷新 + 重放」逻辑。
    /// `build` 内应完整包含 构建请求 → 拦截器 → 发送 → 解码。
    /// 最多只会触发一次 Token 刷新；刷新失败或重放后仍 401 时直接抛出错误，不会循环。
    ///
    /// - Parameter endpoint: 用于读取该端点的鉴权策略（是否允许触发自动刷新）。
    func performRequest<T: Decodable>(
        _ endpoint: CYEndpoint,
        _ build: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await _performRequest(endpoint, build, hasRefreshed: false)
    }

    func _performRequest<T: Decodable>(
        _ endpoint: CYEndpoint,
        _ build: @escaping @Sendable () async throws -> T,
        hasRefreshed: Bool
    ) async throws -> T {
        do {
            return try await build()
        } catch {
            let failure = error as? NetworkFailure
            let rawError = failure?.cyError ?? error
            let requiresRefresh = (rawError as? CYNetworkError)?.requiresCredentialRecovery ?? false

            // 只有明确要求凭证的端点才允许恢复；公开或可选鉴权请求不会隐式改变账号状态。
            if !hasRefreshed, requiresRefresh, endpoint.authentication == .required,
               let coordinator = state.withLock({ $0.credentialRecoveryCoordinator }) {
                if await coordinator.recoverIfNeeded() {
                    // 重放时凭证拦截器会重新读取宿主更新后的 Authorization Header。
                    return try await _performRequest(endpoint, build, hasRefreshed: true)
                }
            }

            // 终态错误：此时才把响应交给响应拦截器（瞬态 401 不会提前触发自动登出等）
            if let failure {
                try? await self.applyResponseInterceptors(failure.response, data: failure.data)
                self.logTerminalFailure(rawError, endpoint: endpoint, response: failure.response)
            }
            throw rawError
        }
    }

    // MARK: - 按策略请求（send）

    /// 按响应策略发起请求（无 Encodable body，使用 `endpoint.body` 字典参数）
    ///
    /// `request` / `requestRaw` / `requestVoid` 等便捷方法由 `CYNetworkClientProtocol` 扩展提供。
    public func send<T: Decodable & Sendable>(_ endpoint: CYEndpoint, strategy: CYResponseStrategy) async throws -> T {
        try await performSend(endpoint, strategy: strategy, urlRequest: try buildURLRequest(for: endpoint))
    }

    /// 按响应策略发起请求（Encodable body）
    public func send<B: Encodable & Sendable, T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        strategy: CYResponseStrategy,
        body: B
    ) async throws -> T {
        try await performSend(endpoint, strategy: strategy, urlRequest: try buildURLRequest(for: endpoint, encodableBody: body))
    }

    /// `send` 统一分发：按策略路由到对应的发送 + 解码链路
    private func performSend<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        strategy: CYResponseStrategy,
        urlRequest: URLRequest
    ) async throws -> T {
        switch strategy {
        case .envelope:
            // 唯一走「业务码判定 + 401 自动刷新」的链路（对应 request）
            return try await performRequest(endpoint) {
                let apiResponse: CYAPIResponse<T> = try await self.fetchRaw(endpoint, urlRequest: urlRequest)
                return try self.resolveData(apiResponse)
            }

        case .envelopeRaw, .direct:
            return try await sendDirect(endpoint, urlRequest: urlRequest)

        case .empty:
            guard T.self == CYEmptyResponse.self else {
                throw CYNetworkError.decodingFailed(
                    NSError(domain: "CYNetworkClient", code: -3,
                            userInfo: [NSLocalizedDescriptionKey: ".empty 策略仅支持 CYEmptyResponse"])
                )
            }
            return try await sendDirect(endpoint, urlRequest: urlRequest)

        case .data:
            throw CYNetworkError.decodingFailed(
                NSError(domain: "CYNetworkClient", code: -3,
                        userInfo: [NSLocalizedDescriptionKey: ".data 策略请使用 requestData"])
            )
        }
    }

    /// raw 策略（envelopeRaw / direct / empty）的发送链路：不经业务码判定、不自动刷新，
    /// 响应拦截器在终态统一调用。
    private func sendDirect<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        urlRequest: URLRequest
    ) async throws -> T {
        do {
            let result: (value: T, response: URLResponse?, data: Data?) = try await self.fetchDirect(endpoint, urlRequest: urlRequest)
            try await self.applyResponseInterceptors(result.response, data: result.data)
            return result.value
        } catch {
            if let failure = error as? NetworkFailure {
                try? await self.applyResponseInterceptors(failure.response, data: failure.data)
                self.logTerminalFailure(failure.cyError, endpoint: endpoint, response: failure.response)
                throw failure.cyError
            }
            self.logTerminalFailure(error, endpoint: endpoint, response: nil)
            throw error
        }
    }
}
