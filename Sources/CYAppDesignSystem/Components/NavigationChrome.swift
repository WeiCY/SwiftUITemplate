#if os(iOS)
import SwiftUI
import CYAppCore

// MARK: - 页面导航外壳

/// 为页面统一配置导航标题、导航栏外观和工具栏。
///
/// 适合列表页、设置页、详情页等需要统一导航 chrome 的场景。
public struct CYPageNavigationChrome<Leading: View, Trailing: View>: ViewModifier {
    let title: String?
    let displayMode: NavigationBarItem.TitleDisplayMode
    let backgroundColor: Color?
    let isTranslucent: Bool
    let tintColor: Color?
    let leading: Leading
    let trailing: Trailing

    public init(
        title: String? = nil,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
        backgroundColor: Color? = nil,
        isTranslucent: Bool = true,
        tintColor: Color? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.displayMode = displayMode
        self.backgroundColor = backgroundColor
        self.isTranslucent = isTranslucent
        self.tintColor = tintColor
        self.leading = leading()
        self.trailing = trailing()
    }

    public func body(content: Content) -> some View {
        content
            .navigationTitle(title ?? "")
            .navigationBarTitleDisplayMode(displayMode)
            .toolbar {
                if Leading.self != EmptyView.self {
                    ToolbarItem(placement: .topBarLeading) {
                        leading
                    }
                }
                if Trailing.self != EmptyView.self {
                    ToolbarItem(placement: .topBarTrailing) {
                        trailing
                    }
                }
            }
            .toolbarBackground(backgroundColor ?? .clear, for: .navigationBar)
            .toolbarBackground(isTranslucent ? .visible : .hidden, for: .navigationBar)
            .tint(tintColor)
    }
}

public extension View {
    func cyPageNavigationChrome<Leading: View, Trailing: View>(
        title: String? = nil,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
        backgroundColor: Color? = nil,
        isTranslucent: Bool = true,
        tintColor: Color? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(CYPageNavigationChrome(
            title: title,
            displayMode: displayMode,
            backgroundColor: backgroundColor,
            isTranslucent: isTranslucent,
            tintColor: tintColor,
            leading: leading,
            trailing: trailing
        ))
    }
}

public extension View {
    func cyPageNavigationChrome<Trailing: View>(
        title: String? = nil,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
        backgroundColor: Color? = nil,
        isTranslucent: Bool = true,
        tintColor: Color? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(CYPageNavigationChrome(
            title: title,
            displayMode: displayMode,
            backgroundColor: backgroundColor,
            isTranslucent: isTranslucent,
            tintColor: tintColor,
            leading: { EmptyView() },
            trailing: trailing
        ))
    }
}

public extension View {
    func cyPageNavigationChrome(
        title: String? = nil,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
        backgroundColor: Color? = nil,
        isTranslucent: Bool = true,
        tintColor: Color? = nil
    ) -> some View {
        modifier(CYPageNavigationChrome(
            title: title,
            displayMode: displayMode,
            backgroundColor: backgroundColor,
            isTranslucent: isTranslucent,
            tintColor: tintColor,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        ))
    }
}
#endif
