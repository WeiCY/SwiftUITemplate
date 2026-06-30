import Foundation

// MARK: - 统一 API 响应

/// 统一 API 响应包装
///
/// 适用于大多数后端 API 返回格式：
/// ```json
/// {
///   "code": 0,
///   "data": { ... },
///   "message": "success"
/// }
/// ```
///
/// **用法：**
/// ```swift
/// // 方式 1：自动解包（推荐）— 直接获取 data，业务错误自动抛出
/// let user: User = try await networkClient.request(UserEndpoint.profile)
///
/// // 方式 2：手动处理完整响应
/// let response: CYAPIResponse<User> = try await networkClient.requestRaw(UserEndpoint.profile)
/// if response.isSuccess { print(response.data) }
/// ```
public struct CYAPIResponse<T: Decodable>: Decodable, Sendable where T: Sendable {
    /// 业务状态码（0 或 200 通常表示成功）
    public let code: Int
    /// 响应数据
    public let data: T?
    /// 服务端消息
    public let message: String?
    
    // MARK: - 计算属性
    
    /// 判断业务是否成功
    /// 默认 code == 0 为成功，可根据后端规范调整
    public var isSuccess: Bool {
        code == 0 || code == 200
    }
    
    // MARK: - 解码
    
    enum CodingKeys: String, CodingKey {
        case code
        case data
        case message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decode(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(T.self, forKey: .data)
        message = try? container.decodeIfPresent(String.self, forKey: .message)
    }
}

// MARK: - 空响应体

/// 空响应体 — 用于 POST/DELETE 等只返回 code + message 的接口
///
/// ```swift
/// // DELETE /api/user/123 只需知道成功与否
/// let _: CYEmptyResponse = try await networkClient.request(UserEndpoint.delete(id: 123))
/// ```
public struct CYEmptyResponse: Decodable, Sendable {
    public init() {}
}
