import Foundation

// MARK: - 响应解析策略

/// 响应解析策略 — 决定 `send` 如何解释 HTTP 响应体
///
/// ```swift
/// // envelope：默认 API 包装，自动解包 data
/// let user: User = try await client.send(api, strategy: .envelope)
///
/// // direct：响应体直接就是目标类型（无 envelope）
/// let user: User = try await client.send(openAPI, strategy: .direct)
///
/// // empty：只关心成功与否（204 等空响应）
/// try await client.send(api, strategy: .empty) as CYEmptyResponse
/// ```
public enum CYResponseStrategy: Sendable, Equatable {
    /// 解析 `CYAPIResponse<T>` 并按业务码自动解包 `data`（业务错误抛 `CYNetworkError`）
    /// 对应 `request`：`{ "code": 0, "data": {...}, "message": "ok" }`
    case envelope

    /// 解析 `CYAPIResponse<T>` 并返回原始 envelope（不按业务码抛错）
    /// 对应 `requestRaw`：调用方自行判定 `businessResult`
    case envelopeRaw

    /// 响应体直接解码为 `T`（无外层 envelope）
    /// 适用于 OpenAPI / 第三方接口等非统一包装响应
    case direct

    /// 显式空响应体策略（204/205），仅 `CYEmptyResponse` 可用
    /// 注意：`requestVoid` 走的是 `.envelope` + `CYEmptyResponse`，不使用本策略
    case empty

    /// 原始响应体 `Data`（不参与解码）
    /// 对应 `requestData`：图片、文件等二进制响应
    case data
}
