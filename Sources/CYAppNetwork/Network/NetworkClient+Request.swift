import Foundation
import Alamofire
import CYAppCore

// MARK: - 请求构建 / 编解码器 / 拦截器应用

extension CYNetworkClient {

    // MARK: - 编解码策略

    /// 根据 endpoint 的 key 策略创建 JSON 编码器（默认 convertToSnakeCase）
    private func makeEncoder(for endpoint: CYEndpoint) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = endpoint.keyEncodingStrategy
        return encoder
    }

    /// 根据 endpoint 的 key 策略创建 JSON 解码器（默认 convertFromSnakeCase）
    func makeDecoder(for endpoint: CYEndpoint) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = endpoint.keyDecodingStrategy
        return decoder
    }

    // MARK: - URL / URLRequest 构建

    /// 拼接 baseURL 与 path（规范化斜杠）并附加 queryItems
    func buildURL(for endpoint: CYEndpoint) -> URL? {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let path = endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path
        var components = URLComponents(string: "\(base)/\(path)")
        if let queryItems = endpoint.queryItems {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    /// 构建 URLRequest（简单参数模式，使用 endpoint.body）
    func buildURLRequest(for endpoint: CYEndpoint) throws -> URLRequest {
        try _buildURLRequest(for: endpoint, encodableBody: Never?.none)
    }

    /// 构建 URLRequest（Encodable body 模式）
    func buildURLRequest<B: Encodable>(for endpoint: CYEndpoint, encodableBody: B) throws -> URLRequest {
        try _buildURLRequest(for: endpoint, encodableBody: encodableBody)
    }

    /// 内部统一构建逻辑
    private func _buildURLRequest<B: Encodable>(
        for endpoint: CYEndpoint,
        encodableBody: B?
    ) throws -> URLRequest {
        guard let url = buildURL(for: endpoint) else {
            throw CYNetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = timeoutInterval

        defaultHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 设置 Body
        if endpoint.method != .get {
            if let encodableBody {
                // 优先使用 Encodable 类型安全编码
                request.httpBody = try makeEncoder(for: endpoint).encode(encodableBody)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } else if let body = endpoint.body {
                let jsonObject = body.mapValues { $0.jsonObject }
                guard JSONSerialization.isValidJSONObject(jsonObject) else {
                    CYLogger.network.error("endpoint.body 不可序列化: \(endpoint.path)")
                    throw CYNetworkError.encodingFailed(
                        NSError(domain: "CYNetworkClient", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "endpoint.body 包含不可序列化的值"])
                    )
                }
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: jsonObject)
                } catch {
                    CYLogger.network.error("endpoint.body 编码失败: \(endpoint.path)", error: error)
                    throw CYNetworkError.encodingFailed(error)
                }
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        return request
    }

    // MARK: - 拦截器应用

    func applyRequestInterceptors(
        to request: inout URLRequest,
        authentication: CYAuthenticationPolicy
    ) async throws {
        let interceptors = currentRequestInterceptors()
        for interceptor in interceptors {
            if let authenticationInterceptor = interceptor as? any CYAuthenticationRequestInterceptor {
                try await authenticationInterceptor.intercept(&request, authentication: authentication)
            } else {
                await interceptor.intercept(&request)
            }
        }
    }

    func applyResponseInterceptors(_ response: URLResponse?, data: Data?) async throws {
        let interceptors = currentResponseInterceptors()
        for interceptor in interceptors {
            try await interceptor.intercept(response, data: data)
        }
    }

    // MARK: - 错误日志

    /// 终态失败时输出带上下文的错误日志（所有出口统一调用）
    func logTerminalFailure(_ error: Error, endpoint: CYEndpoint, response: URLResponse?) {
        CYLogger.network.error(Self.failureLogMessage(error: error, endpoint: endpoint, response: response))
    }
}
