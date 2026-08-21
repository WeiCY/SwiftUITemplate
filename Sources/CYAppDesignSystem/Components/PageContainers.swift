import SwiftUI
import CYAppCore

// MARK: - 标准页面容器

/// 标准页面容器，用于统一 iOS 18+ 项目里的页面结构。
///
/// 适合承载：
/// - 标题栏
/// - 内容区
/// - 底部安全区
/// - 搜索栏 / 操作按钮 / 空状态
public struct CYPageContainer<Content: View, Toolbar: View>: View {
    let title: String?
    let subtitle: String?
    let showsNavigationBar: Bool
    let usesScrollView: Bool
    let contentPadding: EdgeInsets
    let content: Content
    let toolbar: Toolbar

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        showsNavigationBar: Bool = true,
        usesScrollView: Bool = true,
        contentPadding: EdgeInsets = .init(top: 0, leading: CYAppDimens.marginM, bottom: CYAppDimens.marginM, trailing: CYAppDimens.marginM),
        @ViewBuilder toolbar: () -> Toolbar,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsNavigationBar = showsNavigationBar
        self.usesScrollView = usesScrollView
        self.contentPadding = contentPadding
        self.toolbar = toolbar()
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsNavigationBar {
                header
            }

            if usesScrollView {
                ScrollView {
                    content
                        .padding(contentPadding)
                }
            } else {
                content
                    .padding(contentPadding)
            }
        }
        .toolbar {
            if Toolbar.self != EmptyView.self {
                toolbar
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if title != nil || subtitle != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(CYAppFont.h2)
                        .foregroundStyle(CYAppColor.textPrimary)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(CYAppFont.bodySmall)
                        .foregroundStyle(CYAppColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CYAppDimens.marginM)
            .padding(.top, CYAppDimens.marginL)
            .padding(.bottom, CYAppDimens.marginM)
        }
    }
}

public extension CYPageContainer where Toolbar == EmptyView {
    init(
        title: String? = nil,
        subtitle: String? = nil,
        showsNavigationBar: Bool = true,
        usesScrollView: Bool = true,
        contentPadding: EdgeInsets = .init(top: 0, leading: CYAppDimens.marginM, bottom: CYAppDimens.marginM, trailing: CYAppDimens.marginM),
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            showsNavigationBar: showsNavigationBar,
            usesScrollView: usesScrollView,
            contentPadding: contentPadding,
            toolbar: { EmptyView() },
            content: content
        )
    }
}

// MARK: - 标准空状态视图

/// 标准空状态视图，适合列表、搜索结果、收藏夹等页面。
public struct CYEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        systemImage: String = "tray",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: CYAppDimens.marginM) {
            Image(systemName: systemImage)
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(CYAppColor.textTertiary)

            Text(title)
                .font(CYAppFont.h4)
                .foregroundStyle(CYAppColor.textPrimary)

            Text(message)
                .font(CYAppFont.bodySmall)
                .foregroundStyle(CYAppColor.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(CYScaledButtonStyle())
                    .padding(.top, CYAppDimens.marginS)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CYAppDimens.marginXL)
    }
}
