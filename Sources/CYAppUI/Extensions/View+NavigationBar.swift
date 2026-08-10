#if os(iOS)
import SwiftUI

extension View {

    public func navigationBarAppearance(
        backgroundColor: Color? = nil,
        titleColor: Color? = nil,
        tintColor: Color? = nil,
        isTranslucent: Bool = true,
        hideSeparator: Bool = false
    ) -> some View {
        modifier(CYNavigationBarModifier(
            backgroundColor: backgroundColor,
            titleColor: titleColor,
            tintColor: tintColor,
            isTranslucent: isTranslucent,
            hideSeparator: hideSeparator
        ))
    }

    public func navigationBarHidden(_ hidden: Bool) -> some View {
        toolbarVisibility(hidden ? .hidden : .automatic, for: .navigationBar)
    }

    @available(iOS 17.0, *)
    public func scrollEdgeAppearance(
        backgroundColor: Color? = nil,
        isTranslucent: Bool = true
    ) -> some View {
        modifier(CYScrollEdgeModifier(backgroundColor: backgroundColor, isTranslucent: isTranslucent))
    }
}

private struct CYNavigationBarModifier: ViewModifier {
    let backgroundColor: Color?
    let titleColor: Color?
    let tintColor: Color?
    let isTranslucent: Bool
    let hideSeparator: Bool

    func body(content: Content) -> some View {
        content
            .toolbarBackground(backgroundColor ?? .clear, for: .navigationBar)
            .toolbarBackground(isTranslucent ? .visible : .hidden, for: .navigationBar)
            .toolbarColorScheme(titleColor != nil ? .dark : nil, for: .navigationBar)
            .tint(tintColor)
    }
}

@available(iOS 17.0, *)
private struct CYScrollEdgeModifier: ViewModifier {
    let backgroundColor: Color?
    let isTranslucent: Bool

    func body(content: Content) -> some View {
        content
            .toolbarBackground(backgroundColor ?? .clear, for: .navigationBar)
            .toolbarBackground(isTranslucent ? .visible : .hidden, for: .navigationBar)
    }
}
#endif
