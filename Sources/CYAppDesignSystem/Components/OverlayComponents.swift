import SwiftUI
import CYAppCore

// MARK: - Bottom Sheet

/// 为 `.sheet` 提供统一的半屏/自定义高度弹层样式。
public struct CYBottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    let showDragIndicator: Bool
    let sheetContent: () -> SheetContent

    public init(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        showDragIndicator: Bool = true,
        @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) {
        self._isPresented = isPresented
        self.detents = detents
        self.showDragIndicator = showDragIndicator
        self.sheetContent = sheetContent
    }

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                sheetContent()
                    .presentationDetents(detents)
                    .presentationDragIndicator(showDragIndicator ? .visible : .hidden)
            }
    }
}

public extension View {
    func cyBottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        showDragIndicator: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(CYBottomSheetModifier(
            isPresented: isPresented,
            detents: detents,
            showDragIndicator: showDragIndicator,
            sheetContent: content
        ))
    }
}

// MARK: - SnackBar

/// 底部 SnackBar 状态。
@MainActor
@Observable
public final class CYSnackBarManager: @unchecked Sendable {
    public nonisolated static let shared = CYSnackBarManager()

    public private(set) var isPresented = false
    public private(set) var message: String?
    public private(set) var actionTitle: String?

    @ObservationIgnored
    private var action: (@Sendable () -> Void)?
    @ObservationIgnored
    private var dismissTask: Task<Void, Never>?

    public nonisolated init() {}

    /// 显示 SnackBar。
    public func show(
        message: String,
        actionTitle: String? = nil,
        duration: TimeInterval = 3.0,
        action: (@Sendable () -> Void)? = nil
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.isPresented = true

        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            self?.dismiss()
        }
    }

    /// 关闭 SnackBar。
    public func dismiss() {
        dismissTask?.cancel()
        isPresented = false
        message = nil
        actionTitle = nil
        action = nil
    }

    /// 触发 SnackBar 上的动作按钮。
    public func performAction() {
        action?()
        dismiss()
    }
}

/// 底部 SnackBar 视图。
public struct CYSnackBar: View {
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let dismiss: () -> Void

    public init(
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        dismiss: @escaping () -> Void
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.dismiss = dismiss
    }

    public var body: some View {
        HStack(spacing: CYAppDimens.marginM) {
            Text(message)
                .font(CYAppFont.bodyMedium)
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(CYAppFont.button)
                .foregroundStyle(CYAppColor.accent)
            }
        }
        .padding(CYAppDimens.marginM)
        .background(Color.black.opacity(0.88))
        .clipShape(.rect(cornerRadius: CYAppDimens.radiusM))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, CYAppDimens.marginL)
        .padding(.bottom, CYAppDimens.marginXL)
    }
}

public struct CYSnackBarModifier: ViewModifier {
    @Bindable var manager: CYSnackBarManager

    public init(manager: CYSnackBarManager = .shared) {
        self.manager = manager
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if let message = manager.message, manager.isPresented {
                CYSnackBar(
                    message: message,
                    actionTitle: manager.actionTitle,
                    action: { manager.performAction() },
                    dismiss: { manager.dismiss() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

public extension View {
    func snackBar(manager: CYSnackBarManager = .shared) -> some View {
        modifier(CYSnackBarModifier(manager: manager))
    }
}
