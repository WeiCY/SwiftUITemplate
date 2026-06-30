import SwiftUI
import CYAppCore

/// CYAlertManager 的 SwiftUI 视图修饰符
///
/// 在根 View 上使用，自动绑定 CYAlertManager 的弹窗状态：
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             RootView()
///                 .alertManager()
///         }
///     }
/// }
///
/// // 任意位置触发：
/// CYAlertManager.shared.showSuccess("操作完成")
/// CYAlertManager.shared.showConfirmation(title: "删除？") { delete() }
/// ```
public struct CYAlertManagerModifier: ViewModifier {
    
    @Bindable var alertManager = CYAlertManager.shared
    
    public func body(content: Content) -> some View {
        content
            .alert(alertManager.title, isPresented: $alertManager.isPresented) {
                switch alertManager.alertType {
                case .info, .success, .warning, .error:
                    Button("好的", role: .cancel) { }
                    
                case .confirmation(let action, let confirmTitle, let isDestructive):
                    Button(confirmTitle, role: isDestructive ? .destructive : .none) {
                        action()
                    }
                    Button("取消", role: .cancel) { }
                }
            } message: {
                if let message = alertManager.message {
                    Text(message)
                }
            }
    }
}

extension View {
    /// 绑定全局弹窗管理器到视图树
    public func alertManager() -> some View {
        modifier(CYAlertManagerModifier())
    }
}
