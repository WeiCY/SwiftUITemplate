import Foundation
import Alamofire

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
/// **与 OC 时代的对比：**
/// | OC (YTKRequest / MJExtension) | Swift (本模板) |
/// |---|---|
/// | MJExtension 运行时字典解析 | Codable 编译时类型安全 |
/// | `[NSDictionary]` / `[Model]` | `[User]` 强类型 |
/// | 回调 block | async/await |
/// | 手动判断 code | `CYAPIResponse<T>` 自动解包 |
public final class CYNetworkClient: CYNetworkClientProtocol, @unchecked Sendable {
    
    public static let shared = CYNetworkClient()
    
    private let baseURL: String
    private var requestInterceptors: [any CYRequestInterceptor] = []
    private var responseInterceptors: [any CYResponseInterceptor] = []
    
    /// JSON 编码器（驼峰命名策略，与大多数后端 API 对齐）
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()
    
    /// JSON 解码器
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()
    
    public init(
        baseURL: String = CYAppEnvironment.current.baseURL,
        requestInterceptors: [any CYRequestInterceptor] = [],
        responseInterceptors: [any CYResponseInterceptor] = []
    ) {
        self.baseURL = baseURL
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
    }
    
    /// 添加请求拦截器
    public func addRequestInterceptor(_ interceptor: any CYRequestInterceptor) {
        requestInterceptors.append(interceptor)
    }
    
    /// 添加响应拦截器
    public func addResponseInterceptor(_ interceptor: any CYResponseInterceptor) {
        responseInterceptors.append(interceptor)
    }
    
    // MARK: - 请求（自动解包 CYAPIResponse）
    
    /// 发起请求并自动解包 `CYAPIResponse.data`
    ///
    /// 后端返回 `{ "code": 0, "data": {...}, "message": "ok" }` 时，
    /// 直接返回 `T`，业务错误码非 0 自动抛出 `CYNetworkError.businessError`。
    public func request<T: Decodable>(_ endpoint: CYEndpoint) async throws -> T {
        let apiResponse: CYAPIResponse<T> = try await requestRaw(endpoint)
        
        guard apiResponse.isSuccess else {
            throw CYNetworkError.businessError(
                code: apiResponse.code,
                message: apiResponse.message ?? "业务错误"
            )
        }
        
        guard let data = apiResponse.data else {
            throw CYNetworkError.decodingFailed(
                NSError(domain: "CYNetworkClient", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "CYAPIResponse.data 为 nil"])
            )
        }
        
        return data
    }
    
    // MARK: - 原始请求（返回完整 CYAPIResponse）
    
    /// 发起请求并返回完整 `CYAPIResponse<T>`
    ///
    /// 适用于需要手动判断业务状态码的场景：
    /// ```swift
    /// let response = try await networkClient.requestRaw(UserEndpoint.profile)
    /// switch response.code {
    /// case 0: handleSuccess(response.data)
    /// case 10001: refreshTokenAndRetry()  // Token 过期
    /// default: handleError(response.message)
    /// }
    /// ```
    public func requestRaw<T: Decodable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T> {
        var urlRequest = try buildURLRequest(for: endpoint)
        await applyRequestInterceptors(to: &urlRequest)
        
        let dataTask = AF.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingDecodable(CYAPIResponse<T>.self, decoder: decoder)
        
        // 使用 value (async throws) 替代同步的 result 属性
        do {
            let apiResponse = try await dataTask.value
            let response = await dataTask.response
            try await applyResponseInterceptors(response.response, data: response.data)
            
            return apiResponse
        } catch {
            // 执行响应拦截器链（即使出错也执行）
            let response = await dataTask.response
            try? await applyResponseInterceptors(response.response, data: response.data)
            
            throw mapNetworkError(error, data: response.data)
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
    public func post<B: Encodable & Sendable, T: Decodable>(_ endpoint: CYEndpoint, body: B) async throws -> T {
        var urlRequest = try buildURLRequest(for: endpoint, encodableBody: body)
        await applyRequestInterceptors(to: &urlRequest)
        
        let dataTask = AF.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingDecodable(CYAPIResponse<T>.self, decoder: decoder)
        
        do {
            let apiResponse = try await dataTask.value
            let response = await dataTask.response
            try await applyResponseInterceptors(response.response, data: response.data)
            
            return try unwrapData(apiResponse, emptyDataMessage: "CYAPIResponse.data 为 nil")
        } catch {
            let response = await dataTask.response
            try? await applyResponseInterceptors(response.response, data: response.data)
            throw mapNetworkError(error, data: response.data)
        }
    }
    
    // MARK: - 上传
    
    /// 上传文件（multipart/form-data）
    ///
    /// 支持同时上传文件和附加参数：
    /// ```swift
    /// let avatar: Avatar = try await networkClient.upload(
    ///     UserEndpoint.uploadAvatar,
    ///     data: imageData,
    ///     mimeType: "image/jpeg"
    /// )
    /// ```
    public func upload<T: Decodable>(_ endpoint: CYEndpoint, data: Data, mimeType: String) async throws -> T {
        var urlRequest = try buildURLRequest(for: endpoint)
        await applyRequestInterceptors(to: &urlRequest)
        
        let uploadTask = AF.upload(multipartFormData: { formData in
            formData.append(data, withName: "file", fileName: "upload", mimeType: mimeType)
            if let body = endpoint.body {
                for (key, value) in body {
                    if let string = value as? String, let d = string.data(using: .utf8) {
                        formData.append(d, withName: key)
                    }
                }
            }
        }, with: urlRequest)
        .validate(statusCode: 200..<300)
        .serializingDecodable(CYAPIResponse<T>.self, decoder: decoder)
        
        do {
            let apiResponse = try await uploadTask.value
            let response = await uploadTask.response
            try await applyResponseInterceptors(response.response, data: response.data)
            
            return try unwrapData(apiResponse, businessErrorMessage: "上传失败", emptyDataMessage: "CYAPIResponse.data 为 nil")
        } catch {
            let response = await uploadTask.response
            try? await applyResponseInterceptors(response.response, data: response.data)
            throw mapNetworkError(error, data: response.data)
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
        var urlRequest = try buildURLRequest(for: endpoint)
        await applyRequestInterceptors(to: &urlRequest)
        let destination: DownloadRequest.Destination = { _, _ in
            (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.download(urlRequest, to: destination)
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
        
        // 设置 Headers
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 设置 Body
        if endpoint.method != .get {
            if let encodableBody {
                // 优先使用 Encodable 类型安全编码
                request.httpBody = try encoder.encode(encodableBody)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } else if let body = endpoint.body {
                // 回退到字典参数（使用 JSONSerialization 兼容）
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        }
        
        return request
    }
    
    private func applyRequestInterceptors(to request: inout URLRequest) async {
        for interceptor in requestInterceptors {
            await interceptor.intercept(&request)
        }
    }
    
    private func applyResponseInterceptors(_ response: URLResponse?, data: Data?) async throws {
        for interceptor in responseInterceptors {
            try await interceptor.intercept(response, data: data)
        }
    }
    
    private func unwrapData<T: Decodable>(
        _ apiResponse: CYAPIResponse<T>,
        businessErrorMessage: String = "业务错误",
        emptyDataMessage: String
    ) throws -> T {
        guard apiResponse.isSuccess else {
            throw CYNetworkError.businessError(
                code: apiResponse.code,
                message: apiResponse.message ?? businessErrorMessage
            )
        }
        
        guard let data = apiResponse.data else {
            throw CYNetworkError.decodingFailed(
                NSError(domain: "CYNetworkClient", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: emptyDataMessage])
            )
        }
        
        return data
    }
    
    private func mapNetworkError(_ error: Error, data: Data?) -> CYNetworkError {
        if let networkError = error as? CYNetworkError {
            return networkError
        }
        
        if let afError = error as? AFError {
            return mapAlamofireError(afError, data: data)
        }
        
        return mapAlamofireError(.sessionTaskFailed(error: error), data: data)
    }
    
    /// 将 Alamofire 错误映射为 CYNetworkError
    private func mapAlamofireError(_ afError: AFError, data: Data?) -> CYNetworkError {
        // 网络断开
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
        
        // HTTP 状态码错误
        if let statusCode = afError.responseCode, !(200..<300).contains(statusCode) {
            return .httpError(statusCode: statusCode, data: data)
        }
        
        // 解码错误
        if case .sessionTaskFailed(let error) = afError,
           error is DecodingError {
            return .decodingFailed(error)
        }
        
        return .underlying(afError)
    }
}
