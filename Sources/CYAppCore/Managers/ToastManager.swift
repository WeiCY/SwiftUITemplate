import Foundation
import Observation

// MARK: - Toast 消息管理
//
// 管理全局 Toast 提示的显示和自动消失。
//
// 用法：
// ```swift
// // 显示提示
// CYToastManager.shared.show("操作成功", type: .success)
// CYToastManager.shared.show("网络错误", type: .error, duration: 3.0)
//
// // 手动关闭
// CYToastManager.shared.dismiss()
//
// // View 中使用：
// .toastView()
// ```

@Observable
@MainActor
public final class CYToastManager {
    public nonisolated static let shared = CYToastManager()
    
    /// 当前显示的消息文本
    public var message: String?
    /// 消息类型
    public var type: CYToastType = .info
    /// 是否正在显示
    public var isPresented: Bool = false
    
    public nonisolated init() {}
    
    @ObservationIgnored
    private var dismissTask: Task<Void, Never>?
    
    /// 显示 Toast 消息
    /// - 参数：
    ///   - message: 消息文本
    ///   - type: 消息类型（info/success/error/warning）
    ///   - duration: 显示时长（秒），默认 2.0s
    public func show(_ message: String, type: CYToastType = .info, duration: TimeInterval = 2.0) {
        dismissTask?.cancel()
        self.message = message
        self.type = type
        self.isPresented = true
        
        // 自动消失
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isPresented = false
            }
        }
    }
    
    /// 手动关闭当前 Toast
    public func dismiss() {
        dismissTask?.cancel()
        isPresented = false
    }
}

/// Toast 消息类型
public enum CYToastType: Sendable {
    case info
    case success
    case error
    case warning
    
    /// 对应的 SF Symbol 图标
    public var icon: String {
        switch self {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .error: return "xmark.circle"
        case .warning: return "exclamationmark.triangle"
        }
    }
}
