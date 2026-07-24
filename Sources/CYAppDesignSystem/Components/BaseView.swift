import SwiftUI
import CYAppCore
import CYFeedbackStyle

// MARK: - 通用状态容器视图

/// 通用状态容器视图，统一处理 Loading / Error / Content 三种状态。
public struct CYBaseView<Content: View>: View {
    let isLoading: Bool
    let error: CYAppError?
    let loadingMessage: String?
    let onRetry: (() -> Void)?
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedbackConfiguration = CYFeedbackConfiguration.shared
    @State private var pulseScale: CGFloat = 0.9

    public init(
        isLoading: Bool = false,
        error: CYAppError? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.loadingMessage = nil
        self.onRetry = onRetry
        self.content = content()
    }

    /// 支持局部 Loading 文案的兼容扩展初始化器。
    public init(
        isLoading: Bool = false,
        error: CYAppError? = nil,
        loadingMessage: String?,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.loadingMessage = loadingMessage
        self.onRetry = onRetry
        self.content = content()
    }

    public var body: some View {
        let style = feedbackConfiguration.loadingStyle

        ZStack {
            content
                .disabled(isLoading && style.disablesContent)
                .blur(radius: isLoading ? style.contentBlurRadius : 0)

            if let error {
                errorView(error)
            }

            if isLoading {
                loadingOverlay(style: style)
            }
        }
    }

    @ViewBuilder
    private func errorView(_ error: CYAppError) -> some View {
        VStack(spacing: CYAppDimens.marginM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(CYAppColor.error)

            Text("error_generic".cyLocalized)
                .font(CYAppFont.h3)
                .foregroundColor(CYAppColor.textPrimary)

            Text(error.message)
                .font(CYAppFont.bodyMedium)
                .foregroundColor(CYAppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let onRetry {
                Button(action: onRetry) {
                    Text("action_retry".cyLocalized)
                        .font(CYAppFont.button)
                        .foregroundColor(.white)
                        .padding(.horizontal, CYAppDimens.marginL)
                        .padding(.vertical, CYAppDimens.marginS)
                        .background(CYAppColor.accent)
                        .cornerRadius(CYAppDimens.radiusM)
                }
            }
        }
        .padding()
        .background(CYAppColor.background)
        .cornerRadius(CYAppDimens.radiusL)
        .shadow(radius: 10)
        .padding()
    }

    private func loadingOverlay(style: CYLoadingStyle) -> some View {
        ZStack {
            loadingMask(style: style)

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
                    pulseScale = style.indicator.pulseScaleRange.lowerBound
                    guard !reduceMotion else {
                        pulseScale = 1
                        return
                    }
                    withAnimation(style.indicator.pulseAnimation) {
                        pulseScale = style.indicator.pulseScaleRange.upperBound
                    }
                }

                if let loadingMessage {
                    Text(loadingMessage)
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
            .accessibilityLabel(loadingMessage ?? "Loading")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    @ViewBuilder
    private func loadingMask(style: CYLoadingStyle) -> some View {
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

#Preview("Loading - Shared Default") {
    CYBaseView(isLoading: true, error: nil, loadingMessage: "Loading") {
        Text("Content")
    }
}

#Preview("Loading - Shared Custom") {
    let _ = CYFeedbackConfiguration.configure(
        loadingStyle: CYLoadingStyle(
            maskBackgroundColor: .indigo,
            maskOpacity: 0.15,
            cardBackgroundColor: .black,
            cornerRadius: 24,
            indicatorColor: .mint,
            indicatorScale: 1.5,
            textColor: .white
        )
    )
    CYBaseView(isLoading: true, error: nil, loadingMessage: "Custom loading") {
        Text("Content")
    }
}

#Preview("Error with Retry") {
    CYBaseView(isLoading: false, error: .network("Network connection lost"), onRetry: {}) {
        Text("Content")
    }
}

#Preview("Content") {
    CYBaseView {
        Text("Normal Content")
    }
}
