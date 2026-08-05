import SwiftUI
import CYAppCore
import CYFeedbackStyle

// MARK: - 全局反馈挂载修饰符

public extension View {
    func toastView(manager: CYToastManagerProtocol = CYToastManager.shared) -> some View {
        modifier(CYToastModifier(manager: manager))
    }

    func loadingOverlay(manager: CYLoadingManagerProtocol = CYLoadingManager.shared) -> some View {
        modifier(CYLoadingOverlayModifier(manager: manager))
    }

    func feedbackOverlay(
        toastManager: CYToastManagerProtocol = CYToastManager.shared,
        loadingManager: CYLoadingManagerProtocol = CYLoadingManager.shared
    ) -> some View {
        loadingOverlay(manager: loadingManager)
            .toastView(manager: toastManager)
    }
}

private struct CYToastModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var manager: CYToastManagerProtocol
    @State private var configuration = CYFeedbackConfiguration.shared

    init(manager: CYToastManagerProtocol = CYToastManager.shared) {
        self._manager = State(initialValue: manager)
    }

    func body(content: Content) -> some View {
        let style = configuration.toastStyle

        content
            .overlay(alignment: style.position.alignment) {
                if manager.isPresented, let message = manager.message {
                    CYToastView(message: message, type: manager.type, style: style)
                        .offset(y: style.position.verticalOffset(style.verticalOffset))
                        .id(manager.presentationID)
                        .onTapGesture {
                            if style.tapToDismiss {
                                manager.dismiss()
                            }
                        }
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: style.insertionTransition,
                            removal: style.removalTransition
                        ))
                        .accessibilityAction(named: "Dismiss") {
                            manager.dismiss()
                        }
                }
            }
            .animation(
                reduceMotion ? .easeOut(duration: 0.1) :
                    (manager.isPresented ? style.insertionAnimation : style.removalAnimation),
                value: manager.presentationID
            )
            .animation(
                reduceMotion ? .easeOut(duration: 0.1) : style.removalAnimation,
                value: manager.isPresented
            )
    }
}

private struct CYLoadingOverlayModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var manager: CYLoadingManagerProtocol
    @State private var configuration = CYFeedbackConfiguration.shared

    init(manager: CYLoadingManagerProtocol = CYLoadingManager.shared) {
        self._manager = State(initialValue: manager)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if manager.isLoading {
                    CYLoadingOverlay(
                        message: manager.message,
                        style: configuration.loadingStyle
                    )
                    .transition(.opacity)
                }
            }
            .animation(
                .easeInOut(duration: reduceMotion ? 0.1 : 0.2),
                value: manager.isLoading
            )
    }
}
