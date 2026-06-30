import Foundation

/// 统一错误类型 — 覆盖 App 内所有错误场景
///
/// 与 `CYNetworkError` 的关系：
/// - **CYNetworkError**：网络层错误（细粒度，含 HTTP 状态码、业务码等）
/// - **CYAppError**：全局错误（跨模块，统一展示给 View 层）
///
/// 用法：
/// ```swift
/// // CYBaseViewModel 中自动转换
/// await executeTask {
///     items = try await service.fetchItems() // 任何 Error 自动转为 CYAppError
/// }
///
/// // View 中展示
/// if let error = viewModel.error {
///     Text(error.message)
/// }
/// ```
public enum CYAppError: Error, Equatable {
    /// 网络层错误（断网、超时、HTTP 错误等）
    case network(String)
    /// JSON 解码错误
    case decoding(String)
    /// 业务逻辑错误（后端返回非 0 错误码）
    case business(code: Int, message: String)
    /// 未知错误
    case unknown(String)
    
    /// 错误描述文本（供 View 层直接展示）
    public var message: String {
        switch self {
        case .network(let text), .decoding(let text), .unknown(let text):
            return text
        case .business(_, let message):
            return message
        }
    }
    
    /// 业务错误码（仅 business 类型有值）
    public var businessCode: Int? {
        if case .business(let code, _) = self { return code }
        return nil
    }
    
    /// 将任意 Error 转换为 CYAppError
    ///
    /// 转换优先级：CYAppError > CYNetworkError > DecodingError > 兜底
    public static func resolve(_ error: Error) -> CYAppError {
        if let appError = error as? CYAppError {
            return appError
        }
        if let networkError = error as? CYNetworkError {
            switch networkError {
            case .businessError(let code, let message):
                return .business(code: code, message: message)
            case .decodingFailed(let underlying):
                return .decoding(underlying.localizedDescription)
            default:
                return .network(networkError.errorDescription ?? "网络错误")
            }
        }
        if error is DecodingError {
            return .decoding(error.localizedDescription)
        }
        return .unknown(error.localizedDescription)
    }
}
