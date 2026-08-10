#if os(iOS)
import SwiftUI
import Combine

@MainActor
@Observable
public final class CYKeyboardObserver {

    public static let shared = CYKeyboardObserver()

    public var isVisible: Bool = false
    public var height: CGFloat = 0
    public var animationDuration: TimeInterval = 0.25

    private var cancellables = Set<AnyCancellable>()

    private init() {
        startObserving()
    }

    private func startObserving() {
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                self.isVisible = true
                if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    self.height = frame.height
                }
                if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
                    self.animationDuration = duration
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isVisible = false
                self?.height = 0
            }
            .store(in: &cancellables)
    }
}

extension View {

    public func keyboardAwarePadding(keyboard: CYKeyboardObserver = .shared) -> some View {
        modifier(CYKeyboardAwareModifier(keyboard: keyboard))
    }
}

private struct CYKeyboardAwareModifier: ViewModifier {
    let keyboard: CYKeyboardObserver

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.isVisible ? keyboard.height : 0)
            .animation(.easeOut(duration: keyboard.animationDuration), value: keyboard.height)
    }
}
#endif
