import Foundation

/// 统一网络错误体系
/// 覆盖 HTTP 层 + 业务层 + 系统层三类错误
public enum CYNetworkError: Error, LocalizedError, Sendable {
    
    // MARK: - HTTP 层错误
    
    /// URL 无效
    case invalidURL
    
    /// 请求超时
    case timeout
    
    /// 无网络连接
    case noConnection
    
    /// HTTP 状态码错误（如 401、403、500）
    case httpError(statusCode: Int, data: Data?)
    
    // MARK: - 业务层错误
    
    /// 服务端返回业务错误码
    /// - 参数：
    ///   - code: 业务错误码（如 10001 = token 过期）
    ///   - message: 服务端返回的错误描述
    case businessError(code: Int, message: String)

    /// Token 过期（HTTP 200 但响应体 code 命中 token 过期策略）
    /// - 参数：
    ///   - code: 业务码（如 10001）
    ///   - message: 服务端返回的错误描述
    ///
    /// 命中后网络框架会自动触发 Token 刷新并重放原请求，与 HTTP 401 走同一链路。
    case tokenExpired(code: Int, message: String)

    /// 需重新登录（如账号被踢下线、刷新失败）
    /// - 参数：
    ///   - code: 业务码（如 10003）
    ///   - message: 服务端返回的错误描述
    case needReLogin(code: Int, message: String)
    
    // MARK: - 解析层错误
    
    /// JSON 解码失败
    case decodingFailed(any Error & Sendable)

    /// JSON 编码失败（请求体序列化）
    case encodingFailed(any Error & Sendable)
    
    // MARK: - 系统层错误
    
    /// 上传文件大小超过限制
    /// - Parameter limitMB: 当前生效的上传大小上限（MB）
    case payloadTooLarge(limitMB: Int)
    
    /// 底层网络错误（Alamofire / URLSession 原始错误）
    case underlying(any Error & Sendable)
    
    /// 未知错误
    case unknown
    
    // MARK: - 错误描述
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "network_invalid_url".cyLocalized
        case .timeout:
            return "network_timeout".cyLocalized
        case .noConnection:
            return "network_no_connection".cyLocalized
        case .httpError(let statusCode, _):
            return String(format: "network_http_error".cyLocalized, statusCode)
        case .businessError(_, let message):
            return message
        case .tokenExpired(_, let message):
            return message
        case .needReLogin(_, let message):
            return message
        case .decodingFailed(let error):
            return "\("network_decoding_failed".cyLocalized): \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "\("network_encoding_failed".cyLocalized): \(error.localizedDescription)"
        case .payloadTooLarge(let limitMB):
            return String(format: "network_payload_too_large".cyLocalized, limitMB)
        case .underlying(let error):
            return "\("network_underlying_error".cyLocalized): \(error.localizedDescription)"
        case .unknown:
            return "network_unknown_error".cyLocalized
        }
    }
    
    // MARK: - 辅助方法
    
    /// 是否为认证失败（401）— 用于自动刷新 Token
    public var isUnauthorized: Bool {
        if case .httpError(let code, _) = self { return code == 401 }
        return false
    }

    /// 是否需要触发 Token 刷新 + 重放（HTTP 401 或响应体 code 命中 Token 过期策略）
    public var requiresTokenRefresh: Bool {
        if isUnauthorized { return true }
        if case .tokenExpired = self { return true }
        return false
    }

    /// 是否为响应体级别的 Token 过期
    public var isTokenExpired: Bool {
        if case .tokenExpired = self { return true }
        return false
    }

    /// 是否为「需重新登录」
    public var isNeedReLogin: Bool {
        if case .needReLogin = self { return true }
        return false
    }

    /// 该错误建议的 UI 展示方式（基于业务码策略）
    public var displayKind: CYErrorDisplay {
        switch self {
        case .businessError(let code, _):
            return CYBusinessCodePolicy.shared.withLock { $0.display(for: code) }
        case .tokenExpired(let code, _):
            return CYBusinessCodePolicy.shared.withLock { $0.display(for: code) }
        case .needReLogin(let code, _):
            return CYBusinessCodePolicy.shared.withLock { $0.display(for: code) }
        default:
            return .toast
        }
    }
    
    /// 是否为服务端错误（5xx）
    public var isServerError: Bool {
        if case .httpError(let code, _) = self { return (500..<600).contains(code) }
        return false
    }
    
    /// HTTP 状态码（如有）
    public var statusCode: Int? {
        if case .httpError(let code, _) = self { return code }
        return nil
    }
    
    /// 业务错误码（如有）
    public var businessCode: Int? {
        switch self {
        case .businessError(let code, _): return code
        case .tokenExpired(let code, _): return code
        case .needReLogin(let code, _): return code
        default: return nil
        }
    }
}
