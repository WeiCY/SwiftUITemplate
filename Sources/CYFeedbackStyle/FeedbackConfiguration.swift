import SwiftUI
import Observation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Toast 在屏幕中的显示位置。
public enum CYToastPosition: Sendable {
    case top
    case center
    case bottom
}

/// Toast 图标颜色策略。
public enum CYToastIconColorStrategy: Sendable {
    case typeColor
    case fixed(Color)
}

/// 反馈视图的阴影样式。
public struct CYFeedbackShadow: Sendable {
    public var color: Color
    public var radius: CGFloat
    public var x: CGFloat
    public var y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

/// Toast 的全局视觉与交互样式。
public struct CYToastStyle {
    public var position: CYToastPosition
    public var horizontalMargin: CGFloat
    public var verticalOffset: CGFloat
    public var cornerRadius: CGFloat
    public var iconTextSpacing: CGFloat
    public var backgroundColor: Color
    public var textColor: Color
    public var textFont: Font
    public var maxLines: Int
    public var iconColorStrategy: CYToastIconColorStrategy
    public var shadow: CYFeedbackShadow
    public var tapToDismiss: Bool
    public var insertionTransition: AnyTransition
    public var removalTransition: AnyTransition
    public var insertionAnimation: Animation
    public var removalAnimation: Animation

    public init(
        position: CYToastPosition = .center,
        horizontalMargin: CGFloat = 16,
        verticalOffset: CGFloat = 0,
        cornerRadius: CGFloat = 8,
        iconTextSpacing: CGFloat = 12,
        backgroundColor: Color = CYFeedbackDefaults.background,
        textColor: Color = .primary,
        textFont: Font = .system(.callout).weight(.regular),
        maxLines: Int = 2,
        iconColorStrategy: CYToastIconColorStrategy = .typeColor,
        shadow: CYFeedbackShadow = .init(color: .black.opacity(0.08), radius: 4, y: 2),
        tapToDismiss: Bool = true,
        insertionTransition: AnyTransition = .scale(scale: 0.92).combined(with: .opacity),
        removalTransition: AnyTransition = .scale(scale: 0.96).combined(with: .opacity),
        insertionAnimation: Animation = .spring(duration: 0.3, bounce: 0.2),
        removalAnimation: Animation = .easeOut(duration: 0.2)
    ) {
        self.position = position
        self.horizontalMargin = horizontalMargin
        self.verticalOffset = verticalOffset
        self.cornerRadius = cornerRadius
        self.iconTextSpacing = iconTextSpacing
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.textFont = textFont
        self.maxLines = max(1, maxLines)
        self.iconColorStrategy = iconColorStrategy
        self.shadow = shadow
        self.tapToDismiss = tapToDismiss
        self.insertionTransition = insertionTransition
        self.removalTransition = removalTransition
        self.insertionAnimation = insertionAnimation
        self.removalAnimation = removalAnimation
    }

    @MainActor public static let `default` = CYToastStyle()
}

/// Loading 指示器样式。
public struct CYLoadingIndicatorStyle: Sendable {
    public var color: Color
    public var scale: CGFloat
    public var size: CGFloat
    public var backgroundOpacity: Double
    public var pulseScaleRange: ClosedRange<CGFloat>
    public var pulseAnimation: Animation

    public init(
        color: Color = .primary,
        scale: CGFloat = 1.2,
        size: CGFloat = 64,
        backgroundOpacity: Double = 0.1,
        pulseScaleRange: ClosedRange<CGFloat> = 0.9...1.15,
        pulseAnimation: Animation = .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    ) {
        self.color = color
        self.scale = scale
        self.size = size
        self.backgroundOpacity = backgroundOpacity
        self.pulseScaleRange = pulseScaleRange
        self.pulseAnimation = pulseAnimation
    }
}

/// Loading 内容卡片样式。
public struct CYLoadingCardStyle: Sendable {
    public var backgroundColor: Color
    public var cornerRadius: CGFloat
    public var shadow: CYFeedbackShadow
    public var insets: EdgeInsets
    public var contentSpacing: CGFloat

    public init(
        backgroundColor: Color = CYFeedbackDefaults.background,
        cornerRadius: CGFloat = 16,
        shadow: CYFeedbackShadow = .init(color: .black.opacity(0.08), radius: 12, y: 4),
        insets: EdgeInsets = .init(top: 24, leading: 32, bottom: 24, trailing: 32),
        contentSpacing: CGFloat = 24
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.insets = insets
        self.contentSpacing = contentSpacing
    }
}

/// 全局与局部 Loading 共用的视觉和交互样式。
public struct CYLoadingStyle: Sendable {
    public var maskMaterial: Material?
    public var maskBackgroundColor: Color
    public var maskOpacity: Double
    public var indicator: CYLoadingIndicatorStyle
    public var card: CYLoadingCardStyle
    public var textFont: Font
    public var textColor: Color
    public var disablesContent: Bool
    public var contentBlurRadius: CGFloat

    public init(
        maskMaterial: Material? = .ultraThinMaterial,
        maskBackgroundColor: Color = .black,
        maskOpacity: Double = 0.2,
        cardBackgroundColor: Color = CYFeedbackDefaults.background,
        cornerRadius: CGFloat = 16,
        shadow: CYFeedbackShadow = .init(color: .black.opacity(0.08), radius: 12, y: 4),
        indicatorColor: Color = .primary,
        indicatorScale: CGFloat = 1.2,
        indicatorBackgroundOpacity: Double = 0.1,
        pulseScaleRange: ClosedRange<CGFloat> = 0.9...1.15,
        pulseAnimation: Animation = .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
        textFont: Font = .system(.callout).weight(.regular),
        textColor: Color = .primary,
        cardInsets: EdgeInsets = .init(top: 24, leading: 32, bottom: 24, trailing: 32),
        contentSpacing: CGFloat = 24,
        disablesContent: Bool = true,
        contentBlurRadius: CGFloat = 0
    ) {
        self.maskMaterial = maskMaterial
        self.maskBackgroundColor = maskBackgroundColor
        self.maskOpacity = maskOpacity
        self.indicator = .init(
            color: indicatorColor,
            scale: indicatorScale,
            backgroundOpacity: indicatorBackgroundOpacity,
            pulseScaleRange: pulseScaleRange,
            pulseAnimation: pulseAnimation
        )
        self.card = .init(
            backgroundColor: cardBackgroundColor,
            cornerRadius: cornerRadius,
            shadow: shadow,
            insets: cardInsets,
            contentSpacing: contentSpacing
        )
        self.textFont = textFont
        self.textColor = textColor
        self.disablesContent = disablesContent
        self.contentBlurRadius = contentBlurRadius
    }

    public init(
        maskMaterial: Material? = .ultraThinMaterial,
        maskBackgroundColor: Color = .black,
        maskOpacity: Double = 0.2,
        indicator: CYLoadingIndicatorStyle,
        card: CYLoadingCardStyle,
        textFont: Font = .system(.callout).weight(.regular),
        textColor: Color = .primary,
        disablesContent: Bool = true,
        contentBlurRadius: CGFloat = 0
    ) {
        self.maskMaterial = maskMaterial
        self.maskBackgroundColor = maskBackgroundColor
        self.maskOpacity = maskOpacity
        self.indicator = indicator
        self.card = card
        self.textFont = textFont
        self.textColor = textColor
        self.disablesContent = disablesContent
        self.contentBlurRadius = contentBlurRadius
    }

    public var cardBackgroundColor: Color {
        get { card.backgroundColor }
        set { card.backgroundColor = newValue }
    }
    public var cornerRadius: CGFloat {
        get { card.cornerRadius }
        set { card.cornerRadius = newValue }
    }
    public var shadow: CYFeedbackShadow {
        get { card.shadow }
        set { card.shadow = newValue }
    }
    public var indicatorColor: Color {
        get { indicator.color }
        set { indicator.color = newValue }
    }
    public var indicatorScale: CGFloat {
        get { indicator.scale }
        set { indicator.scale = newValue }
    }
    public var indicatorBackgroundOpacity: Double {
        get { indicator.backgroundOpacity }
        set { indicator.backgroundOpacity = newValue }
    }
    public var pulseScaleRange: ClosedRange<CGFloat> {
        get { indicator.pulseScaleRange }
        set { indicator.pulseScaleRange = newValue }
    }
    public var pulseAnimation: Animation {
        get { indicator.pulseAnimation }
        set { indicator.pulseAnimation = newValue }
    }
    public var cardInsets: EdgeInsets {
        get { card.insets }
        set { card.insets = newValue }
    }
    public var contentSpacing: CGFloat {
        get { card.contentSpacing }
        set { card.contentSpacing = newValue }
    }

    public static let `default` = CYLoadingStyle()
}

/// 错误状态视图的视觉样式。
public struct CYErrorStyle: Sendable {
    /// 顶部图标（SF Symbol 名称）
    public var icon: String
    public var iconSize: CGFloat
    public var iconColor: Color

    /// 错误标题。
    /// 默认值是本地化 key `"error_generic"`，展示时会通过 `.cyLocalized` 读取。
    public var title: String
    public var titleFont: Font
    public var titleColor: Color

    public var messageFont: Font
    public var messageColor: Color

    public var backgroundColor: Color
    public var cornerRadius: CGFloat
    public var shadow: CYFeedbackShadow
    public var padding: CGFloat

    /// 重试按钮标题（默认本地化 key `"action_retry"`）。
    public var retryTitle: String
    public var retryFont: Font
    public var retryForegroundColor: Color
    public var retryBackgroundColor: Color
    public var retryCornerRadius: CGFloat
    public var retryPadding: EdgeInsets

    public init(
        icon: String = "exclamationmark.triangle.fill",
        iconSize: CGFloat = 50,
        iconColor: Color = .red,
        title: String = "error_generic",
        titleFont: Font = .headline,
        titleColor: Color = .primary,
        messageFont: Font = .body,
        messageColor: Color = .secondary,
        backgroundColor: Color = CYFeedbackDefaults.background,
        cornerRadius: CGFloat = 16,
        shadow: CYFeedbackShadow = .init(color: .black.opacity(0.08), radius: 12, y: 4),
        padding: CGFloat = 24,
        retryTitle: String = "action_retry",
        retryFont: Font = .system(.callout).weight(.semibold),
        retryForegroundColor: Color = .white,
        retryBackgroundColor: Color = .accentColor,
        retryCornerRadius: CGFloat = 8,
        retryPadding: EdgeInsets = .init(top: 8, leading: 20, bottom: 8, trailing: 20)
    ) {
        self.icon = icon
        self.iconSize = iconSize
        self.iconColor = iconColor
        self.title = title
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.messageFont = messageFont
        self.messageColor = messageColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.padding = padding
        self.retryTitle = retryTitle
        self.retryFont = retryFont
        self.retryForegroundColor = retryForegroundColor
        self.retryBackgroundColor = retryBackgroundColor
        self.retryCornerRadius = retryCornerRadius
        self.retryPadding = retryPadding
    }

    public static let `default` = CYErrorStyle()
}

/// App 启动期统一配置的全局反馈样式状态。
@MainActor
@Observable
public final class CYFeedbackConfiguration {
    public static let shared = CYFeedbackConfiguration()

    public private(set) var toastStyle: CYToastStyle
    public private(set) var loadingStyle: CYLoadingStyle
    public private(set) var errorStyle: CYErrorStyle

    public init(
        toastStyle: CYToastStyle = .default,
        loadingStyle: CYLoadingStyle = .default,
        errorStyle: CYErrorStyle = .default
    ) {
        self.toastStyle = toastStyle
        self.loadingStyle = loadingStyle
        self.errorStyle = errorStyle
    }

    public static func configure(
        toastStyle: CYToastStyle? = nil,
        loadingStyle: CYLoadingStyle? = nil,
        errorStyle: CYErrorStyle? = nil
    ) {
        if let toastStyle {
            shared.toastStyle = toastStyle
        }
        if let loadingStyle {
            shared.loadingStyle = loadingStyle
        }
        if let errorStyle {
            shared.errorStyle = errorStyle
        }
    }

    /// 恢复默认反馈样式，便于测试间隔离。
    public static func reset() {
        shared.toastStyle = .default
        shared.loadingStyle = .default
        shared.errorStyle = .default
    }
}

@usableFromInline
enum CYFeedbackDefaults {
    @usableFromInline
    static var background: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}
