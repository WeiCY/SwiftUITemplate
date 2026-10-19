import SwiftUI
import Observation
import CYAppCore

public struct CYAlertManagerModifier<Manager: CYAlertManagerProtocol>: ViewModifier {
    
    let alertManager: Manager
    
    public init(manager: Manager) {
        self.alertManager = manager
    }
    
    public func body(content: Content) -> some View {
        content.modifier(CYAlertPresentationModifier(alertManager: alertManager))
    }
}

private struct CYAlertPresentationModifier: ViewModifier {
    let alertManager: any CYAlertManagerProtocol

    func body(content: Content) -> some View {
        content
            .alert(alertManager.title, isPresented: Binding(get: { alertManager.isPresented }, set: { alertManager.isPresented = $0 })) {
                switch alertManager.alertType {
                case .info, .success, .warning, .error:
                    Button("ok".cyLocalized, role: .cancel) { }

                case .confirmation(let action, let confirmTitle, let isDestructive):
                    Button(confirmTitle, role: isDestructive ? .destructive : .none) {
                        action()
                    }
                    Button("cancel".cyLocalized, role: .cancel) { }
                }
            } message: {
                if let message = alertManager.message {
                    Text(message)
                }
            }
            .onChange(of: alertManager.isPresented) { wasPresented, isPresented in
                // SwiftUI 通过绑定关闭弹窗时不会主动调用 manager.dismiss()，
                // 这里在状态从 true 变为 false 时推进队列。
                if wasPresented && !isPresented {
                    alertManager.dismiss()
                }
            }
    }
}

extension View {
    public func alertManager() -> some View {
        modifier(CYAlertManagerModifier(manager: CYAlertManager.shared))
    }
    
    public func alertManager(manager: any CYAlertManagerProtocol) -> some View {
        modifier(CYAlertPresentationModifier(alertManager: manager))
    }
}
