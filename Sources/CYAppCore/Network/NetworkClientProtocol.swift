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

/// 简单请求参数类型别名（适用于参数较少的场景）
public typealias CYRequestParams = [String: any Sendable]

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
///         case .login(let u, let p): return ["username": u, "password": p]
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
}

/// CYEndpoint 默认实现 — 可选属性提供默认值
public extension CYEndpoint {
    var headers: [String: String]? { nil }
    var body: CYRequestParams? { nil }
    var queryItems: [URLQueryItem]? { nil }
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
public protocol CYNetworkClientProtocol: Sendable {
    
    /// 发起请求并自动解包 CYAPIResponse.data
    /// 业务错误码非 0 时自动抛出 CYNetworkError.businessError
    func request<T: Decodable>(_ endpoint: CYEndpoint) async throws -> T
    
    /// 发起请求并返回完整 CYAPIResponse（含 code + data + message）
    func requestRaw<T: Decodable>(_ endpoint: CYEndpoint) async throws -> CYAPIResponse<T>
    
    /// 发起 POST 请求，body 使用 Encodable 类型安全编码
    func post<B: Encodable & Sendable, T: Decodable>(_ endpoint: CYEndpoint, body: B) async throws -> T
    
    /// 上传数据
    func upload<T: Decodable>(_ endpoint: CYEndpoint, data: Data, mimeType: String) async throws -> T
    
    /// 下载文件到指定路径
    func download(_ endpoint: CYEndpoint, to fileURL: URL) async throws -> URL
}
