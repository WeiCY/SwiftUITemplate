import Foundation
import Synchronization

// MARK: - Mock 请求记录

/// Mock 收到的请求快照，用于在测试中断言请求方法、路径、Body 与上传分片。
public struct CYMockRequestRecord: Sendable {
    /// HTTP 方法
    public let method: CYHTTPMethod
    /// 请求路径
    public let path: String
    /// 请求体（`Encodable` body，或缺省时 `endpoint.body` 字典的 JSON 编码）
    public let body: Data?
    /// 上传文件分片（非上传请求为空数组）
    public let parts: [CYMultipartPart]
    /// 上传附加参数
    public let additionalParams: [String: String]?

    public init(
        method: CYHTTPMethod,
        path: String,
        body: Data?,
        parts: [CYMultipartPart],
        additionalParams: [String: String]?
    ) {
        self.method = method
        self.path = path
        self.body = body
        self.parts = parts
        self.additionalParams = additionalParams
    }
}

// MARK: - Mock Network Client

/// 可配置的 Mock 网络客户端，用于单元测试和 SwiftUI Preview。
///
/// 按返回类型注册 Mock 响应，无需实际网络连接。
///
/// ## 用法
/// ```swift
/// let mock = MockNetworkClient()
/// mock.registerResponse(User(id: 1, name: "Test"))
/// let result: User = try await mock.request(UserEndpoint.profile)
/// ```
///
/// **并发安全：** 全部可变状态由 `Mutex` 保护，类型满足 `Sendable`，无 `@unchecked`。
public final class MockNetworkClient: CYNetworkClientProtocol, Sendable {

    /// 注册的响应值：普通返回值或错误。
    private enum MockValue: Sendable {
        case response(any Sendable)
        case error(any Error & Sendable)
    }

    /// 可变状态统一由 `Mutex` 保护，避免数据竞争。
    private struct MutableState: Sendable {
        var typeResponses: [String: MockValue] = [:]
        var endpointResponses: [String: MockValue] = [:]
        var storedRequests: [CYMockRequestRecord] = []
        var defaultDelay: TimeInterval = 0.1
        var shouldFail: Bool = false
        var mockError: any Error & Sendable = CYNetworkError.unknown
    }

    private let state = Mutex(MutableState())

    public init() {}

    // MARK: - 可变配置

    /// Mock 响应的默认延迟（秒）
    public var defaultDelay: TimeInterval {
        get { state.withLock { $0.defaultDelay } }
        set { state.withLock { $0.defaultDelay = newValue } }
    }

    /// 是否让所有请求失败
    public var shouldFail: Bool {
        get { state.withLock { $0.shouldFail } }
        set { state.withLock { $0.shouldFail = newValue } }
    }

    /// `shouldFail` 为 true 时抛出的错误
    public var mockError: any Error & Sendable {
        get { state.withLock { $0.mockError } }
        set { state.withLock { $0.mockError = newValue } }
    }

    /// 已记录的请求（按发生顺序），包含失败的调用（`shouldFail` 或注册错误）。
    ///
    /// ```swift
    /// let mock = MockNetworkClient()
    /// mock.registerResponse(User(id: 1, name: "Test"))
    /// _ = try await mock.request(UserEndpoint.update, body: body)
    /// let sentBody = mock.recordedRequests.last?.body
    /// ```
    public var recordedRequests: [CYMockRequestRecord] {
        state.withLock { $0.storedRequests }
    }

    /// 清空请求记录（不影响已注册的 Mock 响应）
    public func clearRecordedRequests() {
        state.withLock { $0.storedRequests.removeAll() }
    }

    // MARK: - 注册

    /// 按返回类型注册 Mock 响应（自动匹配所有返回该类型的请求）
    public func registerResponse<T: Sendable>(_ response: T) {
        state.withLock { $0.typeResponses[String(describing: T.self)] = .response(response) }
    }

    /// 按具体 Endpoint 注册 Mock 响应
    public func registerResponse<T: Sendable>(for endpoint: CYEndpoint, _ response: T) {
        state.withLock { $0.endpointResponses[key(for: endpoint)] = .response(response) }
    }

    /// 按返回类型注册 Mock 错误
    public func registerError<T>(for type: T.Type, _ error: any Error & Sendable) {
        state.withLock { $0.typeResponses[String(describing: T.self)] = .error(error) }
    }

    /// 清除所有注册的 Mock 数据与请求记录
    public func reset() {
        state.withLock {
            $0.typeResponses.removeAll()
            $0.endpointResponses.removeAll()
            $0.storedRequests.removeAll()
            $0.shouldFail = false
        }
    }

    // MARK: - CYNetworkClientProtocol

    public func send<T: Decodable & Sendable>(_ endpoint: CYEndpoint, strategy: CYResponseStrategy) async throws -> T {
        record(endpoint)
        return try await resolveStrategy(endpoint, strategy: strategy)
    }

    public func send<B: Encodable & Sendable, T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        strategy: CYResponseStrategy,
        body: B
    ) async throws -> T {
        record(endpoint, body: try? JSONEncoder().encode(body))
        return try await resolveStrategy(endpoint, strategy: strategy)
    }

    /// `requestRaw` 的 Mock 增强：注册普通值 `T` 时自动包一层成功 envelope（shadow 协议扩展默认实现）
    public func requestRaw<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T> {
        record(endpoint)
        try await applyFailureOrDelay()
        if let envelope = try? resolve(endpoint: endpoint, as: CYAPIResponse<T>.self) {
            return envelope
        }
        let value = try resolve(endpoint: endpoint, as: T.self)
        return CYAPIResponse(code: 0, data: value, message: nil)
    }

    public func requestData(_ endpoint: CYEndpoint) async throws -> Data {
        record(endpoint)
        try await applyFailureOrDelay()
        let epKey = key(for: endpoint)
        if let value = state.withLock({ $0.endpointResponses[epKey] }) {
            switch value {
            case .error(let error): throw error
            case .response(let response): if let data = response as? Data { return data }
            }
        }
        if let value = state.withLock({ $0.typeResponses[String(describing: Data.self)] }) {
            switch value {
            case .error(let error): throw error
            case .response(let response): if let data = response as? Data { return data }
            }
        }
        throw CYNetworkError.unknown
    }

    public func upload<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        parts: [CYMultipartPart],
        additionalParams: [String: String]?,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> T {
        record(endpoint, parts: parts, additionalParams: additionalParams)
        return try await resolveStrategy(endpoint, strategy: .envelope)
    }

    public func download(
        _ endpoint: CYEndpoint,
        to fileURL: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        record(endpoint)
        try await applyFailureOrDelay()
        return fileURL
    }

    // MARK: - Private

    /// 失败检查 + 延迟（`shouldFail` 时抛 `mockError`）
    private func applyFailureOrDelay() async throws {
        let snapshot = state.withLock { ($0.shouldFail, $0.mockError, $0.defaultDelay) }
        if snapshot.0 { throw snapshot.1 }
        try await Task.sleep(for: .seconds(snapshot.2))
    }

    /// 统一的「失败检查 → 延迟 → 按策略解析」逻辑（`send` / `upload` 共用，避免重复记录）
    private func resolveStrategy<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        strategy: CYResponseStrategy
    ) async throws -> T {
        try await applyFailureOrDelay()
        switch strategy {
        case .envelope, .envelopeRaw, .direct:
            // envelopeRaw 需要注册完整 CYAPIResponse<X>（泛型无法自动包装内层值）
            return try resolve(endpoint: endpoint, as: T.self)
        case .empty:
            guard T.self == CYEmptyResponse.self, let empty = CYEmptyResponse() as? T else {
                throw CYNetworkError.unknown
            }
            return empty
        case .data:
            throw CYNetworkError.unknown
        }
    }

    /// 记录一次请求；未显式提供 body 时回退到 `endpoint.body` 字典的 JSON 编码。
    private func record(
        _ endpoint: CYEndpoint,
        body: Data? = nil,
        parts: [CYMultipartPart] = [],
        additionalParams: [String: String]? = nil
    ) {
        let effectiveBody = body ?? endpoint.body.flatMap { try? JSONEncoder().encode($0) }
        let entry = CYMockRequestRecord(
            method: endpoint.method,
            path: endpoint.path,
            body: effectiveBody,
            parts: parts,
            additionalParams: additionalParams
        )
        state.withLock { $0.storedRequests.append(entry) }
    }

    private func key(for endpoint: CYEndpoint) -> String {
        "\(endpoint.method.rawValue):\(endpoint.path)"
    }

    private func resolve<T: Decodable & Sendable>(endpoint: CYEndpoint, as type: T.Type) throws -> T {
        let typeKey = String(describing: T.self)
        let epKey = key(for: endpoint)

        // 先精确匹配 endpoint
        if let value = state.withLock({ $0.endpointResponses[epKey] }) {
            return try resolve(value, as: T.self)
        }

        // 再按类型匹配
        if let value = state.withLock({ $0.typeResponses[typeKey] }) {
            return try resolve(value, as: T.self)
        }

        throw CYNetworkError.unknown
    }

    private func resolve<T: Decodable & Sendable>(_ value: MockValue, as type: T.Type) throws -> T {
        switch value {
        case .error(let error):
            throw error
        case .response(let response):
            if let casted = response as? T { return casted }
            return try decode(response, as: T.self)
        }
    }

    private func decode<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
