import SwiftUI
import CYAppCore
import CYAppDesignSystem

// MARK: - 全局反馈挂载修饰符
//
// 将 CYToastManager / CYLoadingManager 的单例状态渲染到屏幕上。
// 用法：在根视图（如 RootView）上调用一次即可。
//
// ```swift
// RootView()
//     .toastView()
//     .loadingOverlay()
// ```

public extension View {
    /// 挂载全局 Toast。配合 `CYToastManager.shared.show(...)` 使用。
    func toastView() -> some View {
        modifier(CYToastModifier())
    }

    /// 挂载全局 Loading 遮罩。配合 `CYLoadingManager.shared.show(...)` 使用。
    func loadingOverlay() -> some View {
        modifier(CYLoadingOverlayModifier())
    }
}

private struct CYToastModifier: ViewModifier {
    @State private var manager = CYToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if manager.isPresented, let message = manager.message {
                    CYToastView(message: message, type: manager.type)
                        .padding(.top, CYAppDimens.marginM)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(duration: 0.3), value: manager.isPresented)
                }
            }
    }
}

private struct CYLoadingOverlayModifier: ViewModifier {
    @State private var manager = CYLoadingManager.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if manager.isLoading {
                    CYLoadingOverlay(message: manager.message)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: manager.isLoading)
                }
            }
    }
}
