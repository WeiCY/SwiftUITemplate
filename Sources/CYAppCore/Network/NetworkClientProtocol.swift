import Foundation

// MARK: - HTTP 方法

/// HTTP 请求方法（桥接 Alamofire，对外不暴露 Alamofire 类型）
public enum CYHTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - 请求参数

/// 类型安全的 JSON 请求参数（编译期保证可序列化）
///
/// ```swift
/// var body: CYRequestParams? {
///     ["username": .string("john"), "age": .int(25), "vip": true]
/// }
/// ```
public typealias CYRequestParams = [String: CYJSONValue]

/// 端点的凭证使用策略。Network 只执行策略，不判断用户是否“已登录”。
public enum CYAuthenticationPolicy: Sendable, Equatable {
    /// 公开请求：不读取、不注入凭证，也不触发凭证恢复。
    case none
    /// 有凭证时注入，没有凭证时仍可发送。
    case optional
    /// 必须有凭证；认证失败时可触发宿主提供的恢复动作并重放一次。
    case required
}

// MARK: - 端点协议

/// 网络请求端点协议
///
/// 定义一个 API 请求的所有必要信息。
///
/// **简单参数用法：**
/// ```swift
/// enum UserAPI {
///     case login(username: String, password: String)
///     case profile
/// }
///
/// extension UserAPI: CYEndpoint {
///     var path: String { ... }
///     var method: CYHTTPMethod { ... }
///     var body: CYRequestParams? {
///         switch self {
///         case .login(let u, let p): return ["username": .string(u), "password": .string(p)]
///         case .profile: return nil
///         }
///     }
/// }
/// ```
///
/// **Encodable 类型安全用法（推荐复杂场景）：**
/// ```swift
/// struct LoginRequest: Encodable, Sendable {
///     let username: String
///     let password: String
///     let deviceId: String
/// }
///
/// // 在 ViewModel 中使用：
/// let loginBody = LoginRequest(username: "john", password: "123", deviceId: "xxx")
/// let user: User = try await networkClient.post(UserAPI.login, body: loginBody)
/// ```
public protocol CYEndpoint: Sendable {
    /// 请求路径（如 "/api/user/profile"）
    var path: String { get }
    /// HTTP 方法
    var method: CYHTTPMethod { get }
    /// 自定义请求头
    var headers: [String: String]? { get }
    /// 简单请求参数（适用于字典参数）
    var body: CYRequestParams? { get }
    /// URL 查询参数（GET 请求）
    var queryItems: [URLQueryItem]? { get }
    /// JSON 解码策略（响应解析），默认 convertFromSnakeCase，适配 snake_case 后端
    var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy { get }
    /// JSON 编码策略（请求体），默认 convertToSnakeCase，与后端对齐
    var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy { get }
    /// 凭证策略。默认 `.none`，不需要账号体系的 App 无需任何配置。
    var authentication: CYAuthenticationPolicy { get }
}

/// CYEndpoint 默认实现 — 可选属性提供默认值
public extension CYEndpoint {
    var headers: [String: String]? { nil }
    var body: CYRequestParams? { nil }
    var queryItems: [URLQueryItem]? { nil }
    var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy { .convertFromSnakeCase }
    var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy { .convertToSnakeCase }
    var authentication: CYAuthenticationPolicy { .none }
}

// MARK: - 网络客户端协议

/// 网络客户端协议
///
/// 业务代码只依赖此协议，不直接依赖 Alamofire。
///
/// **两种请求模式：**
/// ```swift
/// // 模式 1：自动解包 CYAPIResponse（推荐，99% 场景）
/// let user: User = try await networkClient.request(UserEndpoint.profile)
///
/// // 模式 2：获取完整 CYAPIResponse
/// let response: CYAPIResponse<User> = try await networkClient.requestRaw(UserEndpoint.profile)
/// ```
/// multipart 单文件部分（供 `upload(parts:)` 多文件上传）
public struct CYMultipartPart: Sendable {
    /// 文件数据
    public let data: Data
    /// MIME 类型（如 "image/jpeg"、"text/plain"）
    public let mimeType: String
    /// 服务端保存的文件名
    public var fileName: String
    /// 表单字段名
    public var paramName: String

    public init(
        data: Data,
        mimeType: String,
        fileName: String = "upload",
        paramName: String = "file"
    ) {
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
        self.paramName = paramName
    }
}

public protocol CYNetworkClientProtocol: Sendable {

    /// 按响应策略发起请求（无 Encodable body，使用 `endpoint.body` 字典参数）
    ///
    /// ```swift
    /// let user: User = try await client.send(UserAPI.profile, strategy: .envelope)
    /// let raw: User = try await client.send(OpenAPI.user, strategy: .direct)
    /// ```
    func send<T: Decodable & Sendable>(_ endpoint: CYEndpoint, strategy: CYResponseStrategy) async throws -> T

    /// 按响应策略发起请求（Encodable body）
    ///
    /// ```swift
    /// let user: User = try await client.send(AuthAPI.login, strategy: .envelope, body: LoginRequest(...))
    /// ```
    func send<B: Encodable & Sendable, T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        strategy: CYResponseStrategy,
        body: B
    ) async throws -> T

    /// 获取原始响应体 Data（图片、文件等二进制响应，不参与 envelope 解码）
    func requestData(_ endpoint: CYEndpoint) async throws -> Data

    /// 多文件上传（multipart/form-data，带进度回调，fractionCompleted ∈ [0, 1]）
    ///
    /// ```swift
    /// let result = try await networkClient.upload(
    ///     UserEndpoint.uploadAvatar,
    ///     parts: [
    ///         CYMultipartPart(data: avatarData, mimeType: "image/jpeg", fileName: "a.jpg", paramName: "avatar"),
    ///         CYMultipartPart(data: coverData, mimeType: "image/png", fileName: "c.png", paramName: "cover"),
    ///     ],
    ///     additionalParams: ["scene": "profile"]
    /// )
    /// ```
    func upload<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        parts: [CYMultipartPart],
        additionalParams: [String: String]?,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> T

    /// 下载文件到指定路径（带进度回调，fractionCompleted ∈ [0, 1]）
    func download(
        _ endpoint: CYEndpoint,
        to fileURL: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL
}

// MARK: - 便捷扩展（基于 send / upload / download 组合）

public extension CYNetworkClientProtocol {

    /// 发起请求并自动解包 `CYAPIResponse.data`（等价 `send(.envelope)`）
    /// 业务错误码非 0 时自动抛出 `CYNetworkError.businessError`
    func request<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> T {
        try await send(endpoint, strategy: .envelope)
    }

    /// 发起请求并返回完整 `CYAPIResponse`（等价 `send(.envelopeRaw)`，不按业务码抛错）
    func requestRaw<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T> {
        try await send(endpoint, strategy: .envelopeRaw)
    }

    /// 只关心成功与否（不关心返回体），业务错误照常抛出
    ///
    /// 适合 DELETE / POST 等无返回数据、只确认成功的接口：
    /// ```swift
    /// try await networkClient.requestVoid(UserEndpoint.delete(id: 123))
    /// ```
    func requestVoid(_ endpoint: CYEndpoint) async throws {
        let _: CYEmptyResponse = try await send(endpoint, strategy: .envelope)
    }

    /// 泛型 Encodable body 的请求（等价 `send(.envelope, body:)`）
    ///
    /// ```swift
    /// let user: User = try await networkClient.request(AuthEndpoint.login, body: LoginRequest(...))
    /// ```
    func request<B: Encodable & Sendable, T: Decodable & Sendable>(_ endpoint: CYEndpoint, body: B) async throws -> T {
        try await send(endpoint, strategy: .envelope, body: body)
    }

    /// 多文件上传（无附加参数字典、无进度回调）
    func upload<T: Decodable & Sendable>(_ endpoint: CYEndpoint, parts: [CYMultipartPart]) async throws -> T {
        try await upload(endpoint, parts: parts, additionalParams: nil, progress: nil)
    }

    /// 多文件上传（无进度回调）
    func upload<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        parts: [CYMultipartPart],
        additionalParams: [String: String]?
    ) async throws -> T {
        try await upload(endpoint, parts: parts, additionalParams: additionalParams, progress: nil)
    }

    /// 下载文件到指定路径（无进度回调）
    func download(_ endpoint: CYEndpoint, to fileURL: URL) async throws -> URL {
        try await download(endpoint, to: fileURL, progress: nil)
    }
}
