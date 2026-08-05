import SwiftUI
import Observation
import CYAppCore

public struct CYAlertManagerModifier<Manager: CYAlertManagerProtocol & Observable>: ViewModifier {
    
    @Bindable var alertManager: Manager
    
    public init(manager: Manager) {
        self.alertManager = manager
    }
    
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
                    Button("cancel".cyLocalized, role: .cancel) { }
                }
            } message: {
                if let message = alertManager.message {
                    Text(message)
                }
            }
    }
}

extension View {
    public func alertManager() -> some View {
        modifier(CYAlertManagerModifier(manager: CYAlertManager.shared))
    }
    
    public func alertManager<M: CYAlertManagerProtocol & Observable>(manager: M) -> some View {
        modifier(CYAlertManagerModifier(manager: manager))
    }
}
