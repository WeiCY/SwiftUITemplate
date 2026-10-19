import SwiftUI
import CYAppCore

// MARK: - 底部操作栏

/// 页面底部统一操作栏。
///
/// 适合用于：
/// - 提交 / 保存 / 下一步
/// - 多按钮底部操作区
/// 仅负责内容排版与样式；定位、安全区和键盘避让由宿主 safeAreaInset 处理。
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
