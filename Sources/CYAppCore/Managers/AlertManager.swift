import Foundation
import Observation

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
public final class CYAlertManager {
    
    public nonisolated static let shared = CYAlertManager()
    
    // MARK: - State
    
    public var isPresented: Bool = false
    public var title: String = ""
    public var message: String?
    public var alertType: AlertType = .info
    
    // MARK: - Types
    
    public enum AlertType: Sendable {
        case info
        case success
        case warning
        case error
        case confirmation(confirmAction: @Sendable () -> Void, confirmTitle: String, isDestructive: Bool)
    }
    
    public nonisolated init() {}
    
    // MARK: - Show Alert
    
    /// 显示简单提示弹窗
    public func showAlert(
        title: String,
        message: String? = nil,
        type: AlertType = .info
    ) {
        self.title = title
        self.message = message
        self.alertType = type
        self.isPresented = true
    }
    
    /// 显示成功提示
    public func showSuccess(_ message: String) {
        showAlert(title: "成功", message: message, type: .success)
    }
    
    /// 显示错误提示
    public func showError(_ message: String) {
        showAlert(title: "错误", message: message, type: .error)
    }
    
    /// 显示警告提示
    public func showWarning(_ message: String) {
        showAlert(title: "警告", message: message, type: .warning)
    }
    
    // MARK: - Show Confirmation
    
    /// 显示确认对话框（带确认/取消按钮）
    public func showConfirmation(
        title: String,
        message: String? = nil,
        confirmTitle: String = "确认",
        confirmStyle isDestructive: Bool = false,
        onConfirm: @escaping @Sendable () -> Void
    ) {
        self.title = title
        self.message = message
        self.alertType = .confirmation(confirmAction: onConfirm, confirmTitle: confirmTitle, isDestructive: isDestructive)
        self.isPresented = true
    }
    
    // MARK: - Dismiss
    
    public func dismiss() {
        isPresented = false
    }
}
