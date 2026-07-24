import SwiftUI
import CYAppDesignSystem
import CYFeedbackStyle

/// 全局加载遮罩视图。
public struct CYLoadingOverlay: View {
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
        ZStack {
            mask
                .ignoresSafeArea()

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
                    guard !reduceMotion else {
                        pulseScale = 1
                        return
                    }
                    withAnimation(style.indicator.pulseAnimation) {
                        pulseScale = style.indicator.pulseScaleRange.upperBound
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
            .accessibilityLabel(message ?? "Loading")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    @ViewBuilder
    private var mask: some View {
        if let material = style.maskMaterial {
            Rectangle()
                .fill(material)
                .overlay(style.maskBackgroundColor.opacity(style.maskOpacity))
        } else {
            Rectangle()
                .fill(style.maskBackgroundColor.opacity(style.maskOpacity))
        }
    }
}

#Preview("Loading Styles") {
    HStack(spacing: 0) {
        CYLoadingOverlay(message: "Default style")
        CYLoadingOverlay(
            message: "Custom style",
            style: CYLoadingStyle(
                maskMaterial: nil,
                maskBackgroundColor: .indigo,
                maskOpacity: 0.15,
                cardBackgroundColor: .black,
                cornerRadius: 24,
                indicatorColor: .mint,
                indicatorScale: 1.5,
                textFont: .headline,
                textColor: .white,
                cardInsets: .init(top: 28, leading: 36, bottom: 28, trailing: 36)
            )
        )
    }
}
