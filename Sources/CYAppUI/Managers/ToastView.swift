import SwiftUI
import CYAppCore
import CYFeedbackStyle
import CYAppDesignSystem

/// Toast 消息视图。
public struct CYToastView: View {
    public let message: String
    public let type: CYToastType
    public let style: CYToastStyle

    public init(
        message: String,
        type: CYToastType,
        style: CYToastStyle = .default
    ) {
        self.message = message
        self.type = type
        self.style = style
    }

    public var body: some View {
        HStack(spacing: style.iconTextSpacing) {
            Image(systemName: type.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(style.iconColorStrategy.color(for: type))
                .accessibilityHidden(true)

            Text(message)
                .font(style.textFont)
                .foregroundStyle(style.textColor)
                .lineLimit(style.maxLines)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, CYAppDimens.marginM)
        .padding(.vertical, CYAppDimens.marginS + 4)
        .background(style.backgroundColor, in: RoundedRectangle(cornerRadius: style.cornerRadius))
        .shadow(
            color: style.shadow.color,
            radius: style.shadow.radius,
            x: style.shadow.x,
            y: style.shadow.y
        )
        .padding(.horizontal, style.horizontalMargin)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

extension CYToastType {
    var color: Color {
        switch self {
        case .info: return CYAppColor.info
        case .success: return CYAppColor.success
        case .error: return CYAppColor.error
        case .warning: return CYAppColor.warning
        }
    }
}

#Preview("Toast Styles") {
    VStack(spacing: 16) {
        CYToastView(message: "Default toast style", type: .success)
        CYToastView(
            message: "Custom toast style with dynamic text support",
            type: .info,
            style: CYToastStyle(
                cornerRadius: 16,
                backgroundColor: .indigo,
                textColor: .white,
                textFont: .headline,
                maxLines: 3,
                iconColorStrategy: .fixed(.yellow),
                shadow: .init(color: .indigo.opacity(0.3), radius: 8, y: 4)
            )
        )
    }
    .padding()
    .background(CYAppColor.secondaryBackground)
}
