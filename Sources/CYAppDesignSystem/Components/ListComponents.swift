import SwiftUI
import CYAppCore

// MARK: - 标准列表行

/// 通用列表行组件。
///
/// 支持图标、标题、副标题、尾部自定义内容和箭头指示器。
public struct CYListRow: View {
    let title: String
    let subtitle: String?
    let leading: AnyView?
    let trailing: AnyView?
    let showDisclosure: Bool
    let action: (() -> Void)?

    public init<Leading: View, Trailing: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        showDisclosure: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = Leading.self == EmptyView.self ? nil : AnyView(leading())
        self.trailing = Trailing.self == EmptyView.self ? nil : AnyView(trailing())
        self.showDisclosure = showDisclosure
        self.action = action
    }

    public init(
        title: String,
        subtitle: String? = nil,
        showDisclosure: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            leading: { EmptyView() },
            trailing: { EmptyView() },
            showDisclosure: showDisclosure,
            action: action
        )
    }

    public init<Leading: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        showDisclosure: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            leading: leading,
            trailing: { EmptyView() },
            showDisclosure: showDisclosure,
            action: action
        )
    }

    public init<Trailing: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        showDisclosure: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            leading: { EmptyView() },
            trailing: trailing,
            showDisclosure: showDisclosure,
            action: action
        )
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: CYAppDimens.marginM) {
                leadingView

                textContent

                Spacer(minLength: CYAppDimens.marginS)

                trailingView

                if showDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CYAppColor.textTertiary)
                }
            }
            .padding(.vertical, CYAppDimens.marginS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingView: some View {
        if let leading {
            leading
                .frame(width: 32, height: 32)
        }
    }

    @ViewBuilder
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CYAppFont.bodyMedium)
                .foregroundColor(CYAppColor.textPrimary)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(CYAppFont.bodySmall)
                    .foregroundColor(CYAppColor.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        if let trailing {
            trailing
        }
    }
}

public extension CYListRow {
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = CYAppColor.primary,
        showDisclosure: Bool = false,
        action: (() -> Void)? = nil
    ) {
        if let icon {
            self.init(
                title: title,
                subtitle: subtitle,
                leading: {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(iconColor)
                        .clipShape(RoundedRectangle(cornerRadius: CYAppDimens.radiusS))
                },
                showDisclosure: showDisclosure,
                action: action
            )
        } else {
            self.init(
                title: title,
                subtitle: subtitle,
                showDisclosure: showDisclosure,
                action: action
            )
        }
    }
}

// MARK: - 分段标题

/// 列表分组标题。
public struct CYSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(CYAppFont.bodyMedium)
                .foregroundColor(CYAppColor.textSecondary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(CYAppFont.bodySmall)
                        .foregroundColor(CYAppColor.primary)
                }
            }
        }
        .padding(.horizontal, CYAppDimens.marginM)
        .padding(.top, CYAppDimens.marginL)
        .padding(.bottom, CYAppDimens.marginS)
    }
}
