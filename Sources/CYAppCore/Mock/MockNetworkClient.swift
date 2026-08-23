import Foundation

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
public final class MockNetworkClient: CYNetworkClientProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "mock.network")
    private var typeResponses: [String: Any] = [:]
    private var endpointResponses: [String: Any] = [:]
    public var defaultDelay: TimeInterval = 0.1
    public var shouldFail: Bool = false
    public var mockError: Error = CYNetworkError.unknown

    public init() {}

    /// 按返回类型注册 Mock 响应（自动匹配所有返回该类型的请求）
    public func registerResponse<T: Sendable>(_ response: T) {
        queue.sync { typeResponses[String(describing: T.self)] = response }
    }

    /// 按具体 Endpoint 注册 Mock 响应
    public func registerResponse<T: Sendable>(for endpoint: CYEndpoint, _ response: T) {
        queue.sync { endpointResponses[key(for: endpoint)] = response }
    }

    /// 按返回类型注册 Mock 错误
    public func registerError<T>(for type: T.Type, _ error: Error) {
        queue.sync { typeResponses[String(describing: T.self)] = error }
    }

    /// 清除所有注册的 Mock 数据
    public func reset() {
        queue.sync {
            typeResponses.removeAll()
            endpointResponses.removeAll()
        }
        shouldFail = false
    }

    public func send<T: Decodable & Sendable>(_ endpoint: CYEndpoint, strategy: CYResponseStrategy) async throws -> T {
        if shouldFail { throw mockError }
        try await Task.sleep(for: .seconds(defaultDelay))
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

    public func send<B: Encodable & Sendable, T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        strategy: CYResponseStrategy,
        body: B
    ) async throws -> T {
        try await send(endpoint, strategy: strategy)
    }

    /// `requestRaw` 的 Mock 增强：注册普通值 `T` 时自动包一层成功 envelope（shadow 协议扩展默认实现）
    public func requestRaw<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T> {
        if shouldFail { throw mockError }
        try await Task.sleep(for: .seconds(defaultDelay))
        if let envelope = try? resolve(endpoint: endpoint, as: CYAPIResponse<T>.self) {
            return envelope
        }
        let value = try resolve(endpoint: endpoint, as: T.self)
        return CYAPIResponse(code: 0, data: value, message: nil)
    }

    public func requestData(_ endpoint: CYEndpoint) async throws -> Data {
        if shouldFail { throw mockError }
        try await Task.sleep(for: .seconds(defaultDelay))
        let epKey = key(for: endpoint)
        if let value = queue.sync(execute: { endpointResponses[epKey] }) {
            if let error = value as? Error { throw error }
            if let data = value as? Data { return data }
        }
        if let value = queue.sync(execute: { typeResponses[String(describing: Data.self)] }) {
            if let error = value as? Error { throw error }
            if let data = value as? Data { return data }
        }
        throw CYNetworkError.unknown
    }

    public func upload<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        parts: [CYMultipartPart],
        additionalParams: [String: String]?,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> T {
        try await send(endpoint, strategy: .envelope)
    }

    public func download(
        _ endpoint: CYEndpoint,
        to fileURL: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        if shouldFail { throw mockError }
        try await Task.sleep(for: .seconds(defaultDelay))
        return fileURL
    }

    // MARK: - Private

    private func key(for endpoint: CYEndpoint) -> String {
        "\(endpoint.method.rawValue):\(endpoint.path)"
    }

    private func resolve<T: Decodable & Sendable>(endpoint: CYEndpoint, as type: T.Type) throws -> T {
        let typeKey = String(describing: T.self)
        let epKey = key(for: endpoint)

        // 先精确匹配 endpoint
        if let value = queue.sync(execute: { endpointResponses[epKey] }) {
            if let error = value as? Error { throw error }
            if let casted = value as? T { return casted }
            return try decode(value, as: T.self)
        }

        // 再按类型匹配
        if let value = queue.sync(execute: { typeResponses[typeKey] }) {
            if let error = value as? Error { throw error }
            if let casted = value as? T { return casted }
            return try decode(value, as: T.self)
        }

        throw CYNetworkError.unknown
    }

    private func decode<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
