import Foundation
import Alamofire
import CYAppCore

// MARK: - CYHTTPMethod Alamofire 桥接（内部）

extension CYHTTPMethod {
    /// 桥接到 Alamofire.HTTPMethod（仅内部使用）
    var alamofireMethod: Alamofire.HTTPMethod {
        return Alamofire.HTTPMethod(rawValue: self.rawValue)
    }
}

// MARK: - 网络客户端实现

/// 网络请求失败（终态响应上下文包装）
///
/// 由底层「发送 + 解码」抛出不带响应拦截器副作用，交由上层在**终态**统一应用响应拦截器。
/// 这样瞬态 401（会被 Token 刷新 + 重放吞掉的响应）不会提前触发响应拦截器（如自动登出）。
private struct NetworkFailure: Error {
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
/// 拦截器链执行顺序：
/// 1. 构建 URLRequest
/// 2. 依次执行所有 CYRequestInterceptor（注入 Header、Token 等）
/// 3. 发送请求
/// 4. 依次执行所有 CYResponseInterceptor（日志、统一错误处理等）
///
/// **凭证恢复（401 自动重放）：**
/// 注册 `CYCredentialRecovery` 后，`.required` 请求认证失败会恢复凭证并重试一次。
///
/// **与 OC 时代的对比：**
/// | OC (YTKRequest / MJExtension) | Swift (本模板) |
/// |---|---|
/// | MJExtension 运行时字典解析 | Codable 编译时类型安全 |
/// | `[NSDictionary]` / `[Model]` | `[User]` 强类型 |
/// | 回调 block | async/await |
/// | 手动判断 code | `CYAPIResponse<T>` 自动解包 |
public final class CYNetworkClient: CYNetworkClientProtocol, @unchecked Sendable {

    private let baseURL: String
    private let defaultHeaders: [String: String]
    private let timeoutInterval: TimeInterval
    private let session: Session

    /// 可变状态（拦截器数组、刷新协调器）用同一把锁保护，避免数据竞争。
    private let stateLock = NSLock()
    private var requestInterceptors: [any CYRequestInterceptor] = []
    private var responseInterceptors: [any CYResponseInterceptor] = []
    private var credentialRecoveryCoordinator: CYCredentialRecoveryCoordinator?

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
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
    }

    /// 注册可选的凭证恢复动作。仅 `.required` 端点认证失败时执行并重放一次。
    public func setCredentialRecovery(_ recovery: CYCredentialRecovery) {
        stateLock.lock()
        defer { stateLock.unlock() }
        credentialRecoveryCoordinator = CYCredentialRecoveryCoordinator(recovery: recovery)
    }

    /// 添加请求拦截器
    public func addRequestInterceptor(_ interceptor: any CYRequestInterceptor) {
        stateLock.lock()
        defer { stateLock.unlock() }
        requestInterceptors.append(interceptor)
    }

    /// 添加响应拦截器
    public func addResponseInterceptor(_ interceptor: any CYResponseInterceptor) {
        stateLock.lock()
        defer { stateLock.unlock() }
        responseInterceptors.append(interceptor)
    }

    // MARK: - 401 重试包装

    /// 统一封装「401 自动刷新 + 重放」逻辑。
    /// `build` 内应完整包含 构建请求 → 拦截器 → 发送 → 解码。
    /// 最多只会触发一次 Token 刷新；刷新失败或重放后仍 401 时直接抛出错误，不会循环。
    ///
    /// - Parameter endpoint: 用于读取 `allowsTokenRefresh`（该端点是否允许触发自动刷新）。
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
               let coordinator = stateLock.withLock({ credentialRecoveryCoordinator }) {
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

    // MARK: - 原始数据请求（Data）

    /// 获取原始响应体 Data（图片、文件等二进制响应，不参与 envelope 解码）
    public func requestData(_ endpoint: CYEndpoint) async throws -> Data {
        var urlRequest = try self.buildURLRequest(for: endpoint)
        try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)

        let dataTask = session.request(urlRequest)
            .validate(statusCode: 200..<300)
        let response = await dataTask.serializingData().response
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

    // MARK: - 原始拉取（内部，不含业务码判定 / 不含刷新重试）

    /// 仅负责「发送 → 解码 CYAPIResponse<T>」并映射底层错误，
    /// 业务码判定（成功 / 失败 / Token 过期 / 重新登录）交由上层 `resolveData`。
    private func fetchRaw<T: Decodable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T> {
        try await fetchRaw(endpoint, urlRequest: try buildURLRequest(for: endpoint))
    }

    private func fetchRaw<B: Encodable & Sendable, T: Decodable>(
        _ endpoint: CYEndpoint,
        encodableBody: B
    ) async throws -> CYAPIResponse<T> {
        try await fetchRaw(endpoint, urlRequest: try buildURLRequest(for: endpoint, encodableBody: encodableBody))
    }

    private func fetchRaw<T: Decodable>(
        _ endpoint: CYEndpoint,
        urlRequest: URLRequest
    ) async throws -> CYAPIResponse<T> {
        var urlRequest = urlRequest
        try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)

        let dataTask = session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingDecodable(CYAPIResponse<T>.self, decoder: self.makeDecoder(for: endpoint))

        do {
            let apiResponse = try await self.decodeAPIResponse(from: dataTask)
            let response = await dataTask.response
            try await self.applyResponseInterceptors(response.response, data: response.data)
            return apiResponse
        } catch {
            let response = await dataTask.response
            // 解码/网络失败：携带终态响应抛出，由上层（performRequest / sendDirect）在终态应用响应拦截器
            throw NetworkFailure(
                cyError: self.mapNetworkError(error, data: response.data),
                response: response.response,
                data: response.data
            )
        }
    }

    /// 解码 `CYAPIResponse<T>`；204/205 空响应体仅在 `T == CYEmptyResponse` 时视为成功
    /// （合成空 envelope，避免 Alamofire 对非 `EmptyResponse` 类型抛 `.invalidEmptyResponse`）。
    private func decodeAPIResponse<T: Decodable>(
        from dataTask: DataTask<CYAPIResponse<T>>
    ) async throws -> CYAPIResponse<T> {
        if T.self == CYEmptyResponse.self {
            let response = await dataTask.response
            if let statusCode = response.response?.statusCode,
               (204...205).contains(statusCode),
               response.data?.isEmpty ?? true {
                return CYAPIResponse(code: 0, data: nil, message: nil)
            }
        }
        return try await dataTask.value
    }

    /// 直接解码响应体为 `T`（envelopeRaw / direct / empty 策略共用），
    /// 返回解码值 + 响应上下文；成功时不调用响应拦截器（由 `sendDirect` 在终态统一调用）。
    private func fetchDirect<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        urlRequest: URLRequest
    ) async throws -> (value: T, response: URLResponse?, data: Data?) {
        var urlRequest = urlRequest
        try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)

        let dataTask = session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingDecodable(T.self, decoder: self.makeDecoder(for: endpoint))
        return try await self.awaitDirectValue(dataTask)
    }

    /// 解码直接响应值；204/205 空响应仅在 `T == CYEmptyResponse` 时视为成功
    /// （合成空实例，避免 Alamofire 抛 `.invalidEmptyResponse`）。
    private func awaitDirectValue<T: Decodable & Sendable>(
        _ dataTask: DataTask<T>
    ) async throws -> (value: T, response: URLResponse?, data: Data?) {
        let response = await dataTask.response
        if T.self == CYEmptyResponse.self,
           let statusCode = response.response?.statusCode,
           (204...205).contains(statusCode),
           response.data?.isEmpty ?? true,
           let empty = CYEmptyResponse() as? T {
            return (empty, response.response, response.data)
        }
        do {
            let value = try await dataTask.value
            return (value, response.response, response.data)
        } catch {
            throw NetworkFailure(
                cyError: self.mapNetworkError(error, data: response.data),
                response: response.response,
                data: response.data
            )
        }
    }

    // MARK: - 上传

    /// 多文件上传（multipart/form-data，带进度回调）
    ///
    /// 支持同时上传多个文件和附加参数：
    /// ```swift
    /// let avatar: Avatar = try await networkClient.upload(
    ///     UserEndpoint.uploadAvatar,
    ///     parts: [CYMultipartPart(data: imageData, mimeType: "image/jpeg")]
    /// )
    /// ```
    public func upload<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        parts: [CYMultipartPart],
        additionalParams: [String: String]?,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> T {
        let limitMB = CYAppConstants.maxUploadSizeMB
        let limitBytes = limitMB * 1_024 * 1_024
        let totalBytes = parts.reduce(0) { $0 + $1.data.count }
        guard totalBytes <= limitBytes else {
            CYLogger.network.error(
                "Upload rejected: \(totalBytes) bytes exceeds \(limitMB) MB limit for \(endpoint.path)"
            )
            throw CYNetworkError.payloadTooLarge(limitMB: limitMB)
        }
        return try await performRequest(endpoint) {
            var urlRequest = try self.buildURLRequest(for: endpoint)
            try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)

            let uploadTask = self.session.upload(multipartFormData: { formData in
                for part in parts {
                    formData.append(part.data, withName: part.paramName, fileName: part.fileName, mimeType: part.mimeType)
                }
                if let body = endpoint.body {
                    for (key, value) in body {
                        guard let string = value.multipartStringValue else { continue }
                        formData.append(Data(string.utf8), withName: key)
                    }
                }
                if let additionalParams {
                    for (key, value) in additionalParams {
                        if let d = value.data(using: .utf8) {
                            formData.append(d, withName: key)
                        }
                    }
                }
            }, with: urlRequest)
            .validate(statusCode: 200..<300)
            .uploadProgress { uploadProgress in
                progress?(uploadProgress.fractionCompleted)
            }
            .serializingDecodable(CYAPIResponse<T>.self, decoder: self.makeDecoder(for: endpoint))

            let response = await uploadTask.response
            let apiResponse: CYAPIResponse<T>
            do {
                apiResponse = try await uploadTask.value
            } catch {
                // 解码失败：携带终态响应抛出，由上层在终态统一应用响应拦截器
                throw NetworkFailure(
                    cyError: self.mapNetworkError(error, data: response.data),
                    response: response.response,
                    data: response.data
                )
            }

            try await self.applyResponseInterceptors(response.response, data: response.data)
            return try self.resolveData(apiResponse)
        }
    }

    // MARK: - 下载

    /// 下载文件到指定路径（带进度回调；取消会传播到底层请求，错误映射为 `.cancelled`）
    ///
    /// ```swift
    /// let fileURL = try await networkClient.download(
    ///     FileEndpoint.download(id: "123"),
    ///     to: documentsDirectory.appendingPathComponent("file.pdf")
    /// )
    /// ```
    public func download(
        _ endpoint: CYEndpoint,
        to fileURL: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        try await performRequest(endpoint) {
            var urlRequest = try self.buildURLRequest(for: endpoint)
            try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)
            let destination: DownloadRequest.Destination = { _, _ in
                (fileURL, [.removePreviousFile, .createIntermediateDirectories])
            }

            // 先创建 Alamofire 请求（取消处理器需要持有它）
            let downloadRequest = self.session.download(urlRequest, to: destination)
                .validate(statusCode: 200..<300)
                .downloadProgress { downloadProgress in
                    progress?(downloadProgress.fractionCompleted)
                }

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    downloadRequest.response { response in
                        Task {
                            if let error = response.error {
                                // 下载失败（含取消）：携带终态响应抛出，由上层在终态统一应用响应拦截器
                                continuation.resume(throwing: NetworkFailure(
                                    cyError: self.mapNetworkError(error, data: response.resumeData),
                                    response: response.response,
                                    data: response.resumeData
                                ))
                            } else if let fileURL = response.fileURL {
                                try? await self.applyResponseInterceptors(response.response, data: response.resumeData)
                                continuation.resume(returning: fileURL)
                            } else {
                                continuation.resume(throwing: CYNetworkError.unknown)
                            }
                        }
                    }
                }
            } onCancel: {
                downloadRequest.cancel()
            }
        }
    }

    // MARK: - 编解码策略

    /// 根据 endpoint 的 key 策略创建 JSON 编码器（默认 convertToSnakeCase）
    private func makeEncoder(for endpoint: CYEndpoint) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = endpoint.keyEncodingStrategy
        return encoder
    }

    /// 根据 endpoint 的 key 策略创建 JSON 解码器（默认 convertFromSnakeCase）
    private func makeDecoder(for endpoint: CYEndpoint) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = endpoint.keyDecodingStrategy
        return decoder
    }

    // MARK: - 私有方法

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
    private func buildURLRequest(for endpoint: CYEndpoint) throws -> URLRequest {
        try _buildURLRequest(for: endpoint, encodableBody: Never?.none)
    }

    /// 构建 URLRequest（Encodable body 模式）
    private func buildURLRequest<B: Encodable>(
        for endpoint: CYEndpoint,
        encodableBody: B
    ) throws -> URLRequest {
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

    private func applyRequestInterceptors(
        to request: inout URLRequest,
        authentication: CYAuthenticationPolicy
    ) async throws {
        let interceptors = stateLock.withLock { requestInterceptors }
        for interceptor in interceptors {
            if let authenticationInterceptor = interceptor as? any CYAuthenticationRequestInterceptor {
                try await authenticationInterceptor.intercept(&request, authentication: authentication)
            } else {
                await interceptor.intercept(&request)
            }
        }
    }

    private func applyResponseInterceptors(_ response: URLResponse?, data: Data?) async throws {
        let interceptors = stateLock.withLock { responseInterceptors }
        for interceptor in interceptors {
            try await interceptor.intercept(response, data: data)
        }
    }
}

// MARK: - 业务码解析 + 错误映射

private extension CYNetworkClient {

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

    func mapNetworkError(_ error: Error, data: Data?) -> CYNetworkError {
        if let networkError = error as? CYNetworkError {
            return networkError
        }

        if let afError = error as? AFError {
            return mapAlamofireError(afError, data: data)
        }

        return mapAlamofireError(.sessionTaskFailed(error: error), data: data)
    }

    /// 终态失败时输出带上下文的错误日志（所有出口统一调用）
    private func logTerminalFailure(_ error: Error, endpoint: CYEndpoint, response: URLResponse?) {
        CYLogger.network.error(Self.failureLogMessage(error: error, endpoint: endpoint, response: response))
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
}

// MARK: - 错误日志（可测试纯函数）

extension CYNetworkClient {
    /// 构造终态失败日志文本（纯函数，可测试）
    ///
    /// 格式：`[GET /api/user/profile] HTTP 500 | <错误描述>`
    static func failureLogMessage(error: Error, endpoint: CYEndpoint, response: URLResponse?) -> String {
        var message = "[\(endpoint.method.rawValue) \(endpoint.path)]"
        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            message += " HTTP \(statusCode)"
        }
        if let cyError = error as? CYNetworkError, let description = cyError.errorDescription {
            message += " | \(description)"
        } else {
            message += " | \(error)"
        }
        return message
    }
}

// MARK: - multipart 表单字段转换

private extension CYJSONValue {
    /// multipart 表单字段的字符串表示：字符串去引号，数值/布尔/空转为文本，
    /// 数组/对象不支持作为表单字段（返回 nil，调用方跳过）。
    var multipartStringValue: String? {
        switch self {
        case .string(let v): return v
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v): return "\(v)"
        case .null: return "null"
        case .array, .object: return nil
        }
    }
}

// MARK: - 请求去重集成

extension CYNetworkClient {
    /// 带去重的网络请求
    public func requestWithDeduplication<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        deduplicator: CYRequestDeduplicator
    ) async throws -> T {
        try await deduplicator.execute(key: endpoint.deduplicationKey) {
            try await self.request(endpoint)
        }
    }

    /// 带去重的 POST（Encodable body 纳入去重键）
    ///
    /// 默认 `deduplicationKey` 只覆盖 `endpoint.body` 字典参数；
    /// 本方法额外将 Encodable body 的确定性指纹拼入去重键，避免不同 body 被错误合并。
    public func requestWithDeduplication<B: Encodable & Sendable, T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        body: B,
        deduplicator: CYRequestDeduplicator
    ) async throws -> T {
        try await deduplicator.execute(key: endpoint.deduplicationKey + ":body=" + Self.bodyFingerprint(body)) {
            try await self.request(endpoint, body: body)
        }
    }

    /// 生成 Encodable body 的确定性指纹（纳入去重键）
    private static func bodyFingerprint<B: Encodable>(_ body: B) -> String {
        guard let data = try? JSONEncoder().encode(body) else { return "?" }
        return data.base64EncodedString()
    }
}
