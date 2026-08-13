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
/// **Token 刷新（401 自动重放）：**
/// 通过 `setTokenRefreshInterceptor(_:)` 注册刷新拦截器后，
/// 任意请求收到 401 时会自动触发一次 Token 刷新并重试原请求（并发安全，多个 401 只会刷新一次）。
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
    private var tokenRefreshCoordinator: CYTokenRefreshCoordinator?

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

    /// 注册 Token 刷新拦截器，启用 401 自动刷新 + 重放。
    /// 通常在 App 启动时调用一次：
    /// ```swift
    /// CYNetworkClient.shared.setTokenRefreshInterceptor(
    ///     CYTokenRefreshInterceptor(refreshTokenProvider: ..., refreshAction: ..., ...)
    /// )
    /// ```
    public func setTokenRefreshInterceptor(_ interceptor: CYTokenRefreshInterceptor) {
        stateLock.lock()
        defer { stateLock.unlock() }
        tokenRefreshCoordinator = CYTokenRefreshCoordinator(interceptor: interceptor)
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
    func performRequest<T: Decodable>(
        _ build: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await _performRequest(build, hasRefreshed: false)
    }

    func _performRequest<T: Decodable>(
        _ build: @escaping @Sendable () async throws -> T,
        hasRefreshed: Bool
    ) async throws -> T {
        do {
            return try await build()
        } catch {
            let requiresRefresh: Bool
            if let cyError = error as? CYNetworkError {
                requiresRefresh = cyError.requiresTokenRefresh
            } else {
                requiresRefresh = false
            }

            // 已经刷新过，或不需要刷新，直接抛出错误
            guard !hasRefreshed, requiresRefresh else { throw error }

            let coordinator = stateLock.withLock { tokenRefreshCoordinator }
            guard let coordinator else { throw error }

            // 刷新失败（无 refreshToken 或刷新接口报错）则抛出原错误，不再重试
            let refreshedToken = await coordinator.refreshIfNeeded()
            guard refreshedToken != nil else { throw error }

            // 重放原请求：请求拦截器会重新注入最新 Token
            return try await _performRequest(build, hasRefreshed: true)
        }
    }

    // MARK: - 请求（自动解包 CYAPIResponse）

    /// 发起请求并自动解包 `CYAPIResponse.data`
    ///
    /// 后端返回 `{ "code": 0, "data": {...}, "message": "ok" }` 时直接返回 `T`；
    /// 业务码按 `CYBusinessCodePolicy` 判定：普通失败抛 `businessError`，
    /// 命中 Token 过期策略抛 `tokenExpired`（并自动刷新 + 重放，与 HTTP 401 同链路），
    /// 命中需重新登录策略抛 `needReLogin`。
    public func request<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> T {
        try await performRequest {
            let apiResponse: CYAPIResponse<T> = try await self.fetchRaw(endpoint)
            return try self.resolveData(apiResponse)
        }
    }

    // MARK: - 原始请求（返回完整 CYAPIResponse）

    /// 发起请求并返回完整 `CYAPIResponse<T>`（不按业务码抛错，由调用方自行判定）
    ///
    /// 适用于需要手动判断业务状态码的场景：
    /// ```swift
    /// let response = try await networkClient.requestRaw(UserEndpoint.profile)
    /// switch response.businessResult {
    /// case .success: handleSuccess(response.data)
    /// case .tokenExpired: refreshTokenAndRetry()  // 框架已自动处理，此处仅做补充 UI
    /// case .businessError(_, let message, let display): show(message, as: display)
    /// default: break
    /// }
    /// ```
    public func requestRaw<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T> {
        try await performRequest {
            try await self.fetchRaw(endpoint)
        }
    }

    // MARK: - 原始拉取（内部，不含业务码判定 / 不含刷新重试）

    /// 仅负责「构建请求 → 拦截器 → 发送 → 解码 CYAPIResponse」并映射底层错误，
    /// 业务码判定（成功 / 失败 / Token 过期 / 重新登录）交由上层 `resolveData`。
    private func fetchRaw<T: Decodable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T> {
        var urlRequest = try self.buildURLRequest(for: endpoint)
        await self.applyRequestInterceptors(to: &urlRequest)

        let dataTask = session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingDecodable(CYAPIResponse<T>.self, decoder: self.makeDecoder(for: endpoint))

        do {
            let apiResponse = try await dataTask.value
            let response = await dataTask.response
            try await self.applyResponseInterceptors(response.response, data: response.data)
            return apiResponse
        } catch {
            let response = await dataTask.response
            try? await self.applyResponseInterceptors(response.response, data: response.data)
            throw self.mapNetworkError(error, data: response.data)
        }
    }

    // MARK: - POST 请求（Encodable Body）

    /// 发起 POST 请求，body 使用 Encodable 类型安全编码
    ///
    /// **推荐用法（编译时类型安全，替代 MJExtension 运行时解析）：**
    /// ```swift
    /// struct LoginRequest: Encodable, Sendable {
    ///     let username: String
    ///     let password: String
    /// }
    ///
    /// let user: User = try await networkClient.post(
    ///     AuthEndpoint.login,
    ///     body: LoginRequest(username: "john", password: "123")
    /// )
    /// ```
    public func post<B: Encodable & Sendable, T: Decodable & Sendable>(_ endpoint: CYEndpoint, body: B) async throws -> T {
        try await performRequest {
            var urlRequest = try self.buildURLRequest(for: endpoint, encodableBody: body)
            await self.applyRequestInterceptors(to: &urlRequest)

            let dataTask = self.session.request(urlRequest)
                .validate(statusCode: 200..<300)
                .serializingDecodable(CYAPIResponse<T>.self, decoder: self.makeDecoder(for: endpoint))

            do {
                let apiResponse = try await dataTask.value
                let response = await dataTask.response
                try await self.applyResponseInterceptors(response.response, data: response.data)

                return try self.resolveData(apiResponse)
            } catch {
                let response = await dataTask.response
                try? await self.applyResponseInterceptors(response.response, data: response.data)
                throw self.mapNetworkError(error, data: response.data)
            }
        }
    }

    // MARK: - 上传

    /// 上传文件（multipart/form-data）
    ///
    /// 支持同时上传文件和附加参数：
    /// ```swift
    /// let avatar: Avatar = try await networkClient.upload(
    ///     UserEndpoint.uploadAvatar,
    ///     config: CYUploadConfig(data: imageData, mimeType: "image/jpeg")
    /// )
    /// ```
    public func upload<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        config: CYUploadConfig
    ) async throws -> T {
        try await performRequest {
            var urlRequest = try self.buildURLRequest(for: endpoint)
            await self.applyRequestInterceptors(to: &urlRequest)

            let uploadTask = self.session.upload(multipartFormData: { formData in
                formData.append(config.data, withName: config.paramName, fileName: config.fileName, mimeType: config.mimeType)
                if let body = endpoint.body {
                    for (key, value) in body {
                        if let string = value.stringValue, let d = string.data(using: .utf8) {
                            formData.append(d, withName: key)
                        }
                    }
                }
                if let additionalParams = config.additionalParams {
                    for (key, value) in additionalParams {
                        if let d = value.data(using: .utf8) {
                            formData.append(d, withName: key)
                        }
                    }
                }
            }, with: urlRequest)
            .validate(statusCode: 200..<300)
            .serializingDecodable(CYAPIResponse<T>.self, decoder: self.makeDecoder(for: endpoint))

            do {
                let apiResponse = try await uploadTask.value
                let response = await uploadTask.response
                try await self.applyResponseInterceptors(response.response, data: response.data)

                return try self.resolveData(apiResponse)
            } catch {
                let response = await uploadTask.response
                try? await self.applyResponseInterceptors(response.response, data: response.data)
                throw self.mapNetworkError(error, data: response.data)
            }
        }
    }

    // MARK: - 下载

    /// 下载文件到指定路径
    ///
    /// ```swift
    /// let fileURL = try await networkClient.download(
    ///     FileEndpoint.download(id: "123"),
    ///     to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("file.pdf")
    /// )
    /// ```
    public func download(_ endpoint: CYEndpoint, to fileURL: URL) async throws -> URL {
        try await performRequest {
            var urlRequest = try self.buildURLRequest(for: endpoint)
            await self.applyRequestInterceptors(to: &urlRequest)
            let destination: DownloadRequest.Destination = { _, _ in
                (fileURL, [.removePreviousFile, .createIntermediateDirectories])
            }

            return try await withCheckedThrowingContinuation { continuation in
                self.session.download(urlRequest, to: destination)
                    .validate(statusCode: 200..<300)
                    .response { response in
                        Task {
                            try? await self.applyResponseInterceptors(response.response, data: response.resumeData)

                            if let error = response.error {
                                continuation.resume(throwing: self.mapNetworkError(error, data: response.resumeData))
                            } else if let fileURL = response.fileURL {
                                continuation.resume(returning: fileURL)
                            } else {
                                continuation.resume(throwing: CYNetworkError.unknown)
                            }
                        }
                    }
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

    private func buildURL(for endpoint: CYEndpoint) -> URL? {
        var components = URLComponents(string: baseURL + endpoint.path)
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

    private func applyRequestInterceptors(to request: inout URLRequest) async {
        let interceptors = stateLock.withLock { requestInterceptors }
        for interceptor in interceptors {
            await interceptor.intercept(&request)
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
    /// - 成功：返回 `data`（data 为 nil 时抛 `decodingFailed`）。
    /// - Token 过期：抛 `CYNetworkError.tokenExpired` → 被 `performRequest` 捕获后自动刷新 + 重放。
    /// - 需重新登录：抛 `CYNetworkError.needReLogin`。
    /// - 普通错误：抛 `CYNetworkError.businessError`（message 取自服务端响应）。
    func resolveData<T: Decodable>(_ apiResponse: CYAPIResponse<T>) throws -> T {
        switch apiResponse.businessResult {
        case .success:
            guard let data = apiResponse.data else {
                throw CYNetworkError.decodingFailed(
                    NSError(domain: "CYNetworkClient", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "CYAPIResponse.data 为 nil"])
                )
            }
            return data

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

    /// 将 Alamofire 错误映射为 CYNetworkError
    func mapAlamofireError(_ afError: AFError, data: Data?) -> CYNetworkError {
        if let urlError = afError.underlyingError as? URLError {
            switch urlError.code {
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

        if case .sessionTaskFailed(let error) = afError,
           error is DecodingError {
            return .decodingFailed(error)
        }

        return .underlying(afError)
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

    /// 带去重的原始请求
    public func requestRawWithDeduplication<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        deduplicator: CYRequestDeduplicator
    ) async throws -> CYAPIResponse<T> {
        try await deduplicator.execute(key: endpoint.deduplicationKey) {
            try await self.requestRaw(endpoint)
        }
    }
}
