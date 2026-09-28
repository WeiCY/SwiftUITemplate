import SwiftUI
import CYAppCore
import CYFeedbackStyle

// MARK: - 通用状态容器视图

/// 通用状态容器视图，统一处理 Loading / Error / Content 三种状态。
///
/// 错误视图支持两种方式：
/// 1. 使用全局 `CYFeedbackConfiguration.shared.errorStyle` 默认样式；
/// 2. 通过 `errorView` 插槽传入自定义视图。
public struct CYBaseView<Content: View, ErrorView: View>: View {
    let isLoading: Bool
    let error: CYAppError?
    let loadingMessage: String?
    let onRetry: (() -> Void)?
    let content: Content
    let errorViewBuilder: (CYAppError, (() -> Void)?) -> ErrorView

    @State private var feedbackConfiguration = CYFeedbackConfiguration.shared

    /// 使用默认错误样式的初始化。
    public init(
        isLoading: Bool = false,
        error: CYAppError? = nil,
        loadingMessage: String? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) where ErrorView == CYDefaultErrorView {
        self.init(
            isLoading: isLoading,
            error: error,
            loadingMessage: loadingMessage,
            onRetry: onRetry,
            content: content,
            errorView: { error, onRetry in
                CYDefaultErrorView(error: error, onRetry: onRetry)
            }
        )
    }

    /// 使用自定义错误视图插槽的初始化。
    public init(
        isLoading: Bool = false,
        error: CYAppError? = nil,
        loadingMessage: String? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder errorView: @escaping (CYAppError, (() -> Void)?) -> ErrorView
    ) {
        self.isLoading = isLoading
        self.error = error
        self.loadingMessage = loadingMessage
        self.onRetry = onRetry
        self.content = content()
        self.errorViewBuilder = errorView
    }

    public var body: some View {
        let style = feedbackConfiguration.loadingStyle

        ZStack {
            content
                .disabled(isLoading && style.disablesContent)
                .blur(radius: isLoading ? style.contentBlurRadius : 0)

            if let error {
                errorViewBuilder(error, onRetry)
                    .padding(style.card.insets)
            }

            if isLoading {
                loadingOverlay(style: style)
            }
        }
    }

    private func loadingOverlay(style: CYLoadingStyle) -> some View {
        ZStack {
            loadingMask(style: style)
            CYLoadingIndicator(message: loadingMessage, style: style)
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

// MARK: - 默认错误视图

/// 使用 `CYErrorStyle` 渲染的默认错误视图。
public struct CYDefaultErrorView: View {
    let error: CYAppError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?

    @State private var style = CYFeedbackConfiguration.shared.errorStyle

    public init(error: CYAppError, onRetry: (() -> Void)?, onDismiss: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: style.padding / 2) {
            if let onDismiss {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Dismiss")
                }
            }
            Image(systemName: style.icon)
                .font(.system(size: style.iconSize))
                .foregroundStyle(style.iconColor)

            Text(style.title.cyLocalized)
                .font(style.titleFont)
                .foregroundStyle(style.titleColor)

            Text(error.message)
                .font(style.messageFont)
                .foregroundStyle(style.messageColor)
                .multilineTextAlignment(.center)

            if let onRetry {
                Button(action: onRetry) {
                    Text(style.retryTitle.cyLocalized)
                        .font(style.retryFont)
                        .foregroundStyle(style.retryForegroundColor)
                        .padding(style.retryPadding)
                        .background(style.retryBackgroundColor)
                        .clipShape(.rect(cornerRadius: style.retryCornerRadius))
                }
            }
        }
        .padding(style.padding)
        .background(style.backgroundColor)
        .clipShape(.rect(cornerRadius: style.cornerRadius))
        .shadow(
            color: style.shadow.color,
            radius: style.shadow.radius,
            x: style.shadow.x,
            y: style.shadow.y
        )
    }
}

#Preview("Loading - Shared Default") {
    CYBaseView(isLoading: true, error: nil, loadingMessage: "Loading") {
        Text("Content")
    }
}

#Preview("Loading - Shared Custom") {
    // swiftlint:disable:next redundant_discardable_let
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

#Preview("Custom Error View") {
    CYBaseView(
        isLoading: false,
        error: .business(code: 500, message: "服务器繁忙"),
        onRetry: {}
    ) {
        Text("Content")
    } errorView: { error, _ in
        VStack(spacing: 12) {
            Image(systemName: "xmark.octagon.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(error.message)
                .font(.headline)
        }
        .padding(40)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }
}

#Preview("Content") {
    CYBaseView {
        Text("Normal Content")
    }
}
