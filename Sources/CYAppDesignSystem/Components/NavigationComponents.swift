import SwiftUI
import CYAppCore

// MARK: - 页面操作栏

/// 页面顶部统一操作栏。
///
/// 适合放在列表页、详情页、设置页顶部，用于：
/// - 左侧返回/关闭
/// - 中间标题
/// - 右侧搜索/筛选/更多
public struct CYPageActionBar<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading
    let trailing: Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: CYAppDimens.marginM) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CYAppFont.h3)
                    .foregroundStyle(CYAppColor.textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(CYAppFont.bodySmall)
                        .foregroundStyle(CYAppColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: CYAppDimens.marginM)

            trailing
        }
        .padding(.horizontal, CYAppDimens.marginM)
        .padding(.vertical, CYAppDimens.marginM)
    }
}

public extension CYPageActionBar where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

public extension CYPageActionBar where Leading == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }
}

public extension CYPageActionBar where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(title: title, subtitle: subtitle, leading: leading, trailing: { EmptyView() })
    }
}

// MARK: - 搜索筛选栏

/// 页面内统一搜索 / 筛选栏。
public struct CYSearchFilterBar: View {
    let text: Binding<String>
    let placeholder: String
    let showsFilterButton: Bool
    let onSearch: (() -> Void)?
    let onFilter: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String = "Search",
        showsFilterButton: Bool = false,
        onSearch: (() -> Void)? = nil,
        onFilter: (() -> Void)? = nil
    ) {
        self.text = text
        self.placeholder = placeholder
        self.showsFilterButton = showsFilterButton
        self.onSearch = onSearch
        self.onFilter = onFilter
    }

    public var body: some View {
        HStack(spacing: CYAppDimens.marginS) {
            CYSearchBar(
                text: text,
                placeholder: placeholder,
                showsCancelButton: false,
                onSearch: onSearch
            )

            if showsFilterButton, let onFilter {
                Button(action: onFilter) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CYAppColor.primary)
                        .frame(width: 44, height: 44)
                        .background(CYAppColor.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CYAppDimens.radiusM))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 多栏页面容器

/// 面向 iPad / 大屏的多栏页面容器。
public struct CYSplitViewContainer<Sidebar: View, Content: View, Detail: View>: View {
    let sidebar: Sidebar
    let content: Content
    let detail: Detail

    public init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            content
        } detail: {
            detail
        }
    }
}
