import Foundation
import os

// MARK: - 业务码统一定义
//
// 后端通常在 HTTP 200 的响应体里再用自定义 `code` 表达「业务成功 / 失败 /
// Token 过期 / 需重新登录」等语义，且不同项目约定不同（有的用 0、有的用 200、
// Token 过期可能是 401 也可能是 10001）。本文件把这类「业务码 → 语义」的映射
// 收敛到单一可配置策略 `CYBusinessCodePolicy`，网络框架与上层 UI 都只认策略，
// 不再到处硬编码 `code == 0`。

// MARK: - 错误展示方式

/// 业务错误的 UI 展示方式
///
/// 上层可根据业务码决定将错误以何种形态呈现，避免「所有错误都弹 Toast」。
public enum CYErrorDisplay: Sendable, Equatable {
    /// 轻提示（默认）
    case toast
    /// 强提示（弹窗 Alert）
    case alert
    /// 静默（不打扰用户，仅日志 / 内部处理）
    case silent
}

// MARK: - 业务码分类结果

/// 一个业务码经策略分类后的语义结果
public enum CYBusinessCodeResult: Sendable, Equatable {
    /// 业务成功
    case success
    /// 普通业务错误（含建议的展示方式）
    case businessError(code: Int, message: String?, display: CYErrorDisplay)
    /// Token 过期（需刷新后重试）
    case tokenExpired(code: Int, message: String?)
    /// 需重新登录（如账号被踢、刷新失败）
    case needReLogin(code: Int, message: String?)

    /// 是否为成功
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    /// 关联的业务码（成功为 nil）
    public var code: Int? {
        switch self {
        case .success: return nil
        case .businessError(let code, _, _): return code
        case .tokenExpired(let code, _): return code
        case .needReLogin(let code, _): return code
        }
    }
}

// MARK: - 业务码策略

/// 业务码 ↔ 语义 的统一策略（可配置、可替换）
///
/// 默认约定（可在 App 启动时通过 `CYBusinessCodePolicy.shared` 覆盖）：
/// - 成功：`0`、`200`
/// - Token 过期：`401`、`10001`、`10002`（触发自动刷新 + 重放）
/// - 需重新登录：`10003`
/// - 其余为普通业务错误，默认以 Toast 展示；可把特定码划入 `alertCodes` / `silentCodes`
///
/// 用法：
/// ```swift
/// // App 启动时按自家后端契约定制
/// CYBusinessCodePolicy.configure { policy in
///     policy.successCodes = [0, 1, 200]
///     policy.tokenExpiredCodes = [401, 10001, 10002, 10010]
///     policy.reLoginCodes = [10003, 10004]
///     policy.silentCodes = [90001]          // 静默处理
///     policy.alertCodes = [50000, 50001]    // 弹窗而非 Toast
/// }
/// ```
public struct CYBusinessCodePolicy: Sendable {
    /// 视为「成功」的业务码集合
    public var successCodes: Set<Int>
    /// 视为「Token 过期」的业务码集合（自动刷新 + 重放）
    public var tokenExpiredCodes: Set<Int>
    /// 视为「需重新登录」的业务码集合
    public var reLoginCodes: Set<Int>
    /// 静默处理的业务码集合（不打扰用户）
    public var silentCodes: Set<Int>
    /// 以 Alert 强提示的业务码集合（其余默认 Toast）
    public var alertCodes: Set<Int>

    /// 全局共享策略（线程安全，通过 `OSAllocatedUnfairLock` 保护）
    ///
    /// App 启动时按后端契约覆盖：
    /// ```swift
    /// CYBusinessCodePolicy.shared.configure { policy in
    ///     policy.successCodes = [0, 1, 200]
    ///     policy.tokenExpiredCodes = [401, 10001, 10002, 10010]
    /// }
    /// ```
    public static let shared = OSAllocatedUnfairLock(initialState: CYBusinessCodePolicy())

    /// 线程安全地修改全局策略
    public static func configure(_ mutate: @Sendable (inout CYBusinessCodePolicy) -> Void) {
        shared.withLock { mutate(&$0) }
    }

    /// 不可变默认策略（用于测试或不定制的场景）
    public static let `default` = CYBusinessCodePolicy()

    public init(
        successCodes: Set<Int> = [0, 200],
        tokenExpiredCodes: Set<Int> = [401, 10001, 10002],
        reLoginCodes: Set<Int> = [10003],
        silentCodes: Set<Int> = [],
        alertCodes: Set<Int> = []
    ) {
        self.successCodes = successCodes
        self.tokenExpiredCodes = tokenExpiredCodes
        self.reLoginCodes = reLoginCodes
        self.silentCodes = silentCodes
        self.alertCodes = alertCodes
    }

    /// 将业务码分类为语义结果
    public func classify(_ code: Int, message: String?) -> CYBusinessCodeResult {
        if successCodes.contains(code) {
            return .success
        }
        if tokenExpiredCodes.contains(code) {
            return .tokenExpired(code: code, message: message)
        }
        if reLoginCodes.contains(code) {
            return .needReLogin(code: code, message: message)
        }
        let display: CYErrorDisplay = silentCodes.contains(code) ? .silent
            : alertCodes.contains(code) ? .alert
            : .toast
        return .businessError(code: code, message: message, display: display)
    }

    /// 仅判断某业务码建议的展示方式（用于已拿到的错误码做 UI 决策）
    public func display(for code: Int) -> CYErrorDisplay {
        if silentCodes.contains(code) { return .silent }
        if alertCodes.contains(code) { return .alert }
        return .toast
    }
}
