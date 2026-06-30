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
    
    // MARK: - 解析层错误
    
    /// JSON 解码失败
    case decodingFailed(Error)
    
    // MARK: - 系统层错误
    
    /// 底层网络错误（Alamofire / URLSession 原始错误）
    case underlying(Error)
    
    /// 未知错误
    case unknown
    
    // MARK: - 错误描述
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .timeout:
            return "请求超时，请检查网络后重试"
        case .noConnection:
            return "网络连接失败，请检查网络设置"
        case .httpError(let statusCode, _):
            return "服务器错误 (HTTP \(statusCode))"
        case .businessError(_, let message):
            return message
        case .decodingFailed(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .underlying(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unknown:
            return "未知错误"
        }
    }
    
    // MARK: - 辅助方法
    
    /// 是否为认证失败（401）— 用于自动刷新 Token
    public var isUnauthorized: Bool {
        if case .httpError(let code, _) = self { return code == 401 }
        return false
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
        if case .businessError(let code, _) = self { return code }
        return nil
    }
}
