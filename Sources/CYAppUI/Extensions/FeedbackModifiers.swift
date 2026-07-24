import SwiftUI
import CYAppCore

// MARK: - 全局反馈挂载修饰符

public extension View {
    /// 在根视图挂载一次全局 Toast。
    func toastView() -> some View {
        modifier(CYToastModifier())
    }

    /// 在根视图挂载一次全局 Loading。
    func loadingOverlay() -> some View {
        modifier(CYLoadingOverlayModifier())
    }

    /// 同时挂载 Toast 与 Loading。Loading 阻断操作时，Toast 显示在最上层。
    func feedbackOverlay() -> some View {
        loadingOverlay().toastView()
    }
}

private struct CYToastModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var manager = CYToastManager.shared
    @State private var configuration = CYFeedbackConfiguration.shared

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
    @State private var manager = CYLoadingManager.shared
    @State private var configuration = CYFeedbackConfiguration.shared

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
