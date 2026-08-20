import SwiftUI
import CYAppCore

// MARK: - 底部操作栏

/// 页面底部统一操作栏。
///
/// 适合用于：
/// - 提交 / 保存 / 下一步
/// - 多按钮底部操作区
/// - 需要固定在底部安全区上的页面
public struct CYBottomActionBar<Leading: View, Trailing: View>: View {
    let background: Color
    let contentPadding: EdgeInsets
    let leading: Leading
    let trailing: Trailing

    public init(
        background: Color = CYAppColor.background,
        contentPadding: EdgeInsets = .init(top: CYAppDimens.marginM, leading: CYAppDimens.marginM, bottom: CYAppDimens.marginM, trailing: CYAppDimens.marginM),
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.background = background
        self.contentPadding = contentPadding
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: CYAppDimens.marginM) {
            leading
            Spacer(minLength: CYAppDimens.marginS)
            trailing
        }
        .padding(contentPadding)
        .background(background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CYAppColor.separator)
                .frame(height: CYAppDimens.separatorHeight)
        }
    }
}

public extension CYBottomActionBar where Leading == EmptyView, Trailing == EmptyView {
    init(background: Color = CYAppColor.background) {
        self.init(background: background, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

public extension CYBottomActionBar where Leading == EmptyView {
    init(
        background: Color = CYAppColor.background,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(background: background, leading: { EmptyView() }, trailing: trailing)
    }
}

public extension CYBottomActionBar where Trailing == EmptyView {
    init(
        background: Color = CYAppColor.background,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(background: background, leading: leading, trailing: { EmptyView() })
    }
}

// MARK: - 底部安全区附加栏

/// 为页面底部添加统一安全区内容。
///
/// 适合底部按钮、提示文案、操作条等需要贴近屏幕底部的场景。
public struct CYBottomSafeAreaInset<InsetContent: View>: ViewModifier {
    let edge: VerticalEdge
    let spacing: CGFloat
    let content: () -> InsetContent

    public init(
        edge: VerticalEdge = .bottom,
        spacing: CGFloat = 0,
        @ViewBuilder content: @escaping () -> InsetContent
    ) {
        self.edge = edge
        self.spacing = spacing
        self.content = content
    }

    public func body(content: Content) -> some View {
        content.safeAreaInset(edge: edge, spacing: spacing) {
            self.content()
        }
    }
}

public extension View {
    func cyBottomSafeAreaInset<InsetContent: View>(
        edge: VerticalEdge = .bottom,
        spacing: CGFloat = 0,
        @ViewBuilder content: @escaping () -> InsetContent
    ) -> some View {
        modifier(CYBottomSafeAreaInset(edge: edge, spacing: spacing, content: content))
    }
}

// MARK: - 底部固定按钮栏

/// 底部固定提交栏，适合表单、创建、编辑页。
public struct CYStickyBottomBar<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    let background: Color

    public init(
        background: Color = CYAppColor.background,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
        self.background = background
    }

    public var body: some View {
        CYBottomActionBar(background: background) {
            leading
        } trailing: {
            trailing
        }
        .padding(.bottom, 0)
    }
}
