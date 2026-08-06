import Foundation
import Observation

// MARK: - Alert 协议

@MainActor
public protocol CYAlertManagerProtocol: AnyObject, Sendable {
    var isPresented: Bool { get set }
    var title: String { get set }
    var message: String? { get set }
    var alertType: CYAlertManager.AlertType { get set }
    func showAlert(title: String, message: String?, type: CYAlertManager.AlertType)
    func showConfirmation(title: String, message: String?, confirmTitle: String, confirmStyle isDestructive: Bool, onConfirm: @escaping @Sendable () -> Void)
    func dismiss()
    func dismissAll()
}

/// 统一弹窗/确认对话框管理器
///
/// 支持 Alert、确认对话框、带输入的对话框。
/// 通过 `@Environment` 注入或全局单例使用。
///
/// 用法：
/// ```swift
/// // 简单提示
/// CYAlertManager.shared.showAlert(title: "提示", message: "操作成功")
///
/// // 确认对话框
/// CYAlertManager.shared.showConfirmation(
///     title: "确认删除",
///     message: "此操作不可撤销",
///     confirmTitle: "删除",
///     confirmStyle: .destructive
/// ) {
///     // 执行删除
/// }
///
/// // View 中使用：
/// .alertManager()
/// ```
@Observable
@MainActor
public final class CYAlertManager: CYAlertManagerProtocol, @unchecked Sendable {
    
    public nonisolated static let shared = CYAlertManager()
    
    // MARK: - State
    
    public var isPresented: Bool = false
    public var title: String = ""
    public var message: String?
    public var alertType: AlertType = .info
    
    /// 弹窗队列，避免连续调用互相覆盖。
    private var queue: [AlertItem] = []
    
    /// 当前队列中待展示弹窗数量（不包含正在展示）。
    public var queueCount: Int { queue.count }
    
    // MARK: - Types
    
    public enum AlertType: Sendable {
        case info
        case success
        case warning
        case error
        case confirmation(confirmAction: @Sendable () -> Void, confirmTitle: String, isDestructive: Bool)
    }
    
    public nonisolated init() {}
    
    // MARK: - Queue
    
    private struct AlertItem {
        let title: String
        let message: String?
        let type: AlertType
    }
    
    private func enqueue(title: String, message: String?, type: AlertType) {
        queue.append(AlertItem(title: title, message: message, type: type))
        if !isPresented {
            presentNext()
        }
    }
    
    private func presentNext() {
        guard let item = queue.first else { return }
        queue.removeFirst()
        self.title = item.title
        self.message = item.message
        self.alertType = item.type
        self.isPresented = true
    }
    
    // MARK: - Show Alert
    
    /// 显示简单提示弹窗
    public func showAlert(
        title: String,
        message: String? = nil,
        type: AlertType = .info
    ) {
        enqueue(title: title, message: message, type: type)
    }
    
    /// 显示成功提示
    public func showSuccess(_ message: String) {
        showAlert(title: "success_title".cyLocalized, message: message, type: .success)
    }

    /// 显示错误提示
    public func showError(_ message: String) {
        showAlert(title: "error_title".cyLocalized, message: message, type: .error)
    }

    /// 显示警告提示
    public func showWarning(_ message: String) {
        showAlert(title: "warning_title".cyLocalized, message: message, type: .warning)
    }
    
    // MARK: - Show Confirmation
    
    /// 显示确认对话框（带确认/取消按钮）
    public func showConfirmation(
        title: String,
        message: String? = nil,
        confirmTitle: String = "action_confirm".cyLocalized,
        confirmStyle isDestructive: Bool = false,
        onConfirm: @escaping @Sendable () -> Void
    ) {
        let type: AlertType = .confirmation(
            confirmAction: onConfirm,
            confirmTitle: confirmTitle,
            isDestructive: isDestructive
        )
        enqueue(title: title, message: message, type: type)
    }
    
    // MARK: - Dismiss
    
    public func dismiss() {
        isPresented = false
        // 留出 SwiftUI Alert 转场时间，再展示队列中的下一条。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.presentNext()
        }
    }
    
    /// 清空弹窗队列并立即关闭当前弹窗。
    public func dismissAll() {
        queue.removeAll()
        isPresented = false
    }
}
