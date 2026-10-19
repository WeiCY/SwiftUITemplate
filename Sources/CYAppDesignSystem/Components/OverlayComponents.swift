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
    private var action: (@MainActor @Sendable () -> Void)?
    @ObservationIgnored
    private(set) var dismissTask: Task<Void, Never>?
    @ObservationIgnored
    private let wait: @Sendable (TimeInterval) async throws -> Void

    public nonisolated init() {
        wait = { try await Task.sleep(for: .seconds($0)) }
    }

    nonisolated init(wait: @escaping @Sendable (TimeInterval) async throws -> Void) {
        self.wait = wait
    }

    /// 替换当前消息。有限正 duration 自动关闭；非正、非有限或超出计时范围时保留至手动关闭。
    public func show(
        message: String,
        actionTitle: String? = nil,
        duration: TimeInterval = 3.0,
        action: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.isPresented = true

        dismissTask?.cancel()
        dismissTask = nil
        guard duration.isFinite, duration > 0, duration < Double(Int64.max) / 2 else { return }
        let wait = wait
        dismissTask = Task { @MainActor [weak self] in
            do {
                try await wait(duration)
                try Task.checkCancellation()
                self?.dismiss()
            } catch { /* A replaced or dismissed message must not close its successor. */ }
        }
    }

    /// 关闭 SnackBar。
    public func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        isPresented = false
        message = nil
        actionTitle = nil
        action = nil
    }

    /// 触发 SnackBar 上的动作按钮。
    public func performAction() {
        let action = action
        dismiss()
        action?()
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
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(CYAppFont.button)
                .foregroundStyle(CYAppColor.accent)
            }

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("dismiss".cyLocalized)
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
