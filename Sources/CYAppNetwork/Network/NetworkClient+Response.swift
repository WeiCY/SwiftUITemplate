import Foundation
import Alamofire
import CYAppCore

struct NetworkSuccess<Value: Sendable>: Sendable {
    let value: Value
    let response: URLResponse?
    let data: Data?
}

// MARK: - 发送 / 解码 / 业务码解析 / 错误映射

extension CYNetworkClient {

    // MARK: - 原始数据请求（Data）

    /// 获取原始响应体 Data（图片、文件等二进制响应，不参与 envelope 解码）
    ///
    /// raw 语义：不触发凭证恢复与重放，也不参与请求去重。
    public func requestData(_ endpoint: CYEndpoint) async throws -> Data {
        var urlRequest = try self.buildURLRequest(for: endpoint)
        try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)

        let dataTask = session.request(urlRequest)
            .validate(statusCode: 200..<300)
        let response = await dataTask.serializingData().response
        guard !Task.isCancelled else { throw CYNetworkError.cancelled }
        if let error = response.error {
            try? await self.applyResponseInterceptors(response.response, data: response.data)
            let mapped = self.mapNetworkError(error, data: response.data)
            self.logTerminalFailure(mapped, endpoint: endpoint, response: response.response)
            throw mapped
        }
        let data = response.value ?? Data()
        try await self.applyResponseInterceptors(response.response, data: data)
        return data
    }

    // MARK: - Envelope 拉取

    /// 发送、解码并判定业务码；仅传输/解码/业务失败包装响应上下文。
    /// 响应拦截器由上层在终态执行，避免抛错后被重复执行。
    func fetchEnvelope<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        urlRequest: URLRequest
    ) async throws -> NetworkSuccess<T> {
        var urlRequest = urlRequest
        try await applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)
        let dataTask = session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingData()
        return try await awaitEnvelopeValue(dataTask, endpoint: endpoint)
    }

    /// JSON requests and multipart uploads share status, business-error and empty-body handling.
    func awaitEnvelopeValue<T: Decodable & Sendable>(
        _ dataTask: DataTask<Data>,
        endpoint: CYEndpoint
    ) async throws -> NetworkSuccess<T> {
        let response = await dataTask.response
        do {
            guard !Task.isCancelled else { throw CYNetworkError.cancelled }
            if let error = response.error { throw error }
            if T.self == CYEmptyResponse.self,
               let status = response.response?.statusCode, (204...205).contains(status),
               response.data?.isEmpty ?? true,
               let empty = CYEmptyResponse() as? T {
                return NetworkSuccess(value: empty, response: response.response, data: response.data)
            }
            let data = try response.result.get()
            let decoder = makeDecoder(for: endpoint)
            // A failure body may contain validation details instead of the success model.
            // Classify its envelope first; only successful data is decoded as T.
            let metadata = try decoder.decode(NetworkEnvelopeMetadata.self, from: data)
            let _: CYEmptyResponse = try resolveData(CYAPIResponse(
                code: metadata.code, data: CYEmptyResponse(), message: metadata.message
            ))
            let envelope = try decoder.decode(CYAPIResponse<T>.self, from: data)
            return NetworkSuccess(value: try resolveData(envelope), response: response.response, data: response.data)
        } catch {
            throw NetworkFailure(
                cyError: mapNetworkError(error, data: response.data),
                response: response.response, data: response.data
            )
        }
    }

    /// 直接解码响应体为 `T`（envelopeRaw / direct / empty 策略共用），
    /// 返回解码值 + 响应上下文；成功时不调用响应拦截器（由 `sendDirect` 在终态统一调用）。
    func fetchDirect<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        urlRequest: URLRequest
    ) async throws -> NetworkSuccess<T> {
        var urlRequest = urlRequest
        try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)

        let dataTask = session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingDecodable(T.self, decoder: self.makeDecoder(for: endpoint))
        return try await self.awaitDirectValue(dataTask)
    }

    /// 解码直接响应值；204/205 空响应仅在 `T == CYEmptyResponse` 时视为成功
    /// （合成空实例，避免 Alamofire 抛 `.invalidEmptyResponse`）。
    func awaitDirectValue<T: Decodable & Sendable>(
        _ dataTask: DataTask<T>
    ) async throws -> NetworkSuccess<T> {
        let response = await dataTask.response
        guard !Task.isCancelled else { throw CYNetworkError.cancelled }
        if T.self == CYEmptyResponse.self,
           let statusCode = response.response?.statusCode,
           (204...205).contains(statusCode),
           response.data?.isEmpty ?? true,
           let empty = CYEmptyResponse() as? T {
            if let error = response.error {
                // Bypass only the serializer's lack of an EmptyResponse conformance.
                guard case .responseSerializationFailed = error else {
                    throw NetworkFailure(cyError: mapNetworkError(error, data: response.data),
                                         response: response.response, data: response.data)
                }
            }
            return NetworkSuccess(value: empty, response: response.response, data: response.data)
        }
        do {
            let value = try await dataTask.value
            return NetworkSuccess(value: value, response: response.response, data: response.data)
        } catch {
            throw NetworkFailure(
                cyError: self.mapNetworkError(error, data: response.data),
                response: response.response,
                data: response.data
            )
        }
    }

    // MARK: - 业务码解析

    /// 按 `CYBusinessCodePolicy` 解析 `CYAPIResponse`，统一处理「成功 / 普通错误 /
    /// Token 过期 / 需重新登录」，并始终优先使用服务端返回的 `message`。
    ///
    /// - 成功：返回 `data`；若 `T == CYEmptyResponse` 则允许 `data == nil`，返回空实例。
    /// - Token 过期：抛 `CYNetworkError.tokenExpired` → 被 `performRequest` 捕获后自动刷新 + 重放。
    /// - 需重新登录：抛 `CYNetworkError.needReLogin`。
    /// - 普通错误：抛 `CYNetworkError.businessError`（message 取自服务端响应）。
    func resolveData<T: Decodable>(_ apiResponse: CYAPIResponse<T>) throws -> T {
        switch apiResponse.businessResult {
        case .success:
            if let data = apiResponse.data {
                return data
            }
            if T.self == CYEmptyResponse.self {
                guard let empty = CYEmptyResponse() as? T else {
                    throw CYNetworkError.decodingFailed(
                        NSError(domain: "CYNetworkClient", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "CYEmptyResponse 类型转换失败"])
                    )
                }
                return empty
            }
            throw CYNetworkError.decodingFailed(
                NSError(domain: "CYNetworkClient", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "CYAPIResponse.data 为 nil"])
            )

        case .tokenExpired(let code, let message):
            throw CYNetworkError.tokenExpired(code: code, message: message ?? "auth_token_expired".cyLocalized)

        case .needReLogin(let code, let message):
            throw CYNetworkError.needReLogin(code: code, message: message ?? "auth_need_relogin".cyLocalized)

        case .businessError(let code, let message, _):
            throw CYNetworkError.businessError(code: code, message: message ?? "business_error".cyLocalized)
        }
    }

    // MARK: - 错误映射

    func mapNetworkError(_ error: Error, data: Data?) -> CYNetworkError {
        if let networkError = error as? CYNetworkError {
            return networkError
        }

        if let afError = error as? AFError {
            return mapAlamofireError(afError, data: data)
        }

        return mapAlamofireError(.sessionTaskFailed(error: error), data: data)
    }

    /// 将 Alamofire 错误映射为 CYNetworkError
    func mapAlamofireError(_ afError: AFError, data: Data?) -> CYNetworkError {
        // 请求取消（Task 取消 / URLSession 取消 / 显式 cancel）→ .cancelled
        if case .explicitlyCancelled = afError {
            return .cancelled
        }
        if case .sessionTaskFailed(let error) = afError, error is CancellationError {
            return .cancelled
        }

        if let urlError = afError.underlyingError as? URLError {
            switch urlError.code {
            case .cancelled:
                return .cancelled
            case .notConnectedToInternet, .networkConnectionLost:
                return .noConnection
            case .timedOut:
                return .timeout
            default:
                break
            }
        }

        if let statusCode = afError.responseCode, !(200..<300).contains(statusCode) {
            return .httpError(statusCode: statusCode, data: data)
        }

        if case .responseSerializationFailed(let reason) = afError,
           case .decodingFailed(let error) = reason {
            return .decodingFailed(error)
        }
        if case .sessionTaskFailed(let error) = afError,
           error is DecodingError {
            return .decodingFailed(error)
        }

        return .underlying(afError)
    }

    // MARK: - 错误日志（可测试纯函数）

    /// 构造终态失败日志文本（纯函数，可测试）
    ///
    /// 格式：`[GET /api/user/profile] HTTP 500 | <错误描述>`
    static func failureLogMessage(error: Error, endpoint: CYEndpoint, response: URLResponse?) -> String {
        var message = "[\(endpoint.method.rawValue) \(CYNetworkLogRedactor.url(endpoint.path))]"
        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            message += " HTTP \(statusCode)"
        }
        // Error descriptions can contain server bodies, credentials or raw URLs.
        message += " | \(String(describing: type(of: error))) (details omitted)"
        return message
    }
}

/// Deliberately omits data: error payloads do not have to conform to a success model.
/// Raw envelope decoding retains CYAPIResponse's strict data validation.
private struct NetworkEnvelopeMetadata: Decodable {
    let code: Int
    let message: String?

    private enum CodingKeys: String, CodingKey { case code, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = container.contains(.code) ? try container.decode(Int.self, forKey: .code) : 0
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}
