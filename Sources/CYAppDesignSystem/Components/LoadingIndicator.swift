import SwiftUI
import CYAppCore
import CYFeedbackStyle

// MARK: - Loading 指示器

/// 可复用的 Loading 指示器卡片（指示器 + 脉冲动画 + 可选文案 + 卡片背景）。
///
/// 由 `CYBaseView`（页面级状态容器）与 `CYLoadingOverlay`（全局加载遮罩）共用，
/// 保证两处指示器的视觉、动画与无障碍行为完全一致。
///
/// 用法：
/// ```swift
/// CYLoadingIndicator(message: "加载中…")
/// ```
public struct CYLoadingIndicator: View {
    public let message: String?
    public let style: CYLoadingStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat

    public init(message: String?, style: CYLoadingStyle = .default) {
        self.message = message
        self.style = style
        _pulseScale = State(initialValue: style.pulseScaleRange.lowerBound)
    }

    public var body: some View {
        VStack(spacing: style.card.contentSpacing) {
            ZStack {
                Circle()
                    .fill(style.indicator.color.opacity(style.indicator.backgroundOpacity))
                    .frame(width: style.indicator.size, height: style.indicator.size)
                    .scaleEffect(pulseScale)

                ProgressView()
                    .scaleEffect(style.indicator.scale)
                    .tint(style.indicator.color)
            }
            .onAppear {
                pulseScale = style.pulseScaleRange.lowerBound
                guard !reduceMotion else {
                    pulseScale = 1
                    return
                }
                withAnimation(style.pulseAnimation) {
                    pulseScale = style.pulseScaleRange.upperBound
                }
            }

            if let message {
                Text(message)
                    .font(style.textFont)
                    .foregroundStyle(style.textColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(style.card.insets)
        .background(
            RoundedRectangle(cornerRadius: style.card.cornerRadius, style: .continuous)
                .fill(style.card.backgroundColor)
                .shadow(
                    color: style.card.shadow.color,
                    radius: style.card.shadow.radius,
                    x: style.card.shadow.x,
                    y: style.card.shadow.y
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "loading".cyLocalized)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview("Default") {
    CYLoadingIndicator(message: "Loading")
}

#Preview("Custom Style") {
    CYLoadingIndicator(
        message: "Custom loading",
        style: CYLoadingStyle(
            maskBackgroundColor: .indigo,
            maskOpacity: 0.15,
            cardBackgroundColor: .black,
            cornerRadius: 24,
            indicatorColor: .mint,
            indicatorScale: 1.5,
            textColor: .white
        )
    )
}
