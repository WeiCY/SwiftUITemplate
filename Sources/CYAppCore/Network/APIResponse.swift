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
    ///
    /// 不再硬编码 `code == 0 || 200`，而是交由 `CYBusinessCodePolicy.shared`
    /// 统一判定，保证与网络框架、上层 UI 使用同一套业务码语义。
    public var isSuccess: Bool {
        businessResult.isSuccess
    }
    
    /// 按 `CYBusinessCodePolicy` 分类后的业务语义结果
    ///
    /// 业务方可用它区分「成功 / 普通错误 / Token 过期 / 需重新登录」，
    /// 以及普通错误建议的展示方式（toast / alert / silent）。
    public var businessResult: CYBusinessCodeResult {
        CYBusinessCodePolicy.shared.classify(code, message: message)
    }
    
    // MARK: - 解码
    
    enum CodingKeys: String, CodingKey {
        case code
        case data
        case message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 缺失 code 时宽容地视为 0（兼容不返回 code 的接口）；
        // 但 code 存在却类型错误时，明确抛出，避免掩盖后端契约 Bug。
        if container.contains(.code) {
            do {
                code = try container.decode(Int.self, forKey: .code)
            } catch {
                throw DecodingError.typeMismatch(
                    Int.self,
                    .init(codingPath: [CodingKeys.code],
                           debugDescription: "CYAPIResponse.code 类型错误，期望 Int")
                )
            }
        } else {
            code = 0
        }
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
