import SwiftUI
import CYAppDesignSystem
import CYFeedbackStyle

/// 全局加载遮罩视图。
public struct CYLoadingOverlay: View {
    public let message: String?
    public let style: CYLoadingStyle

    public init(message: String?, style: CYLoadingStyle = .default) {
        self.message = message
        self.style = style
    }

    public var body: some View {
        ZStack {
            mask
                .ignoresSafeArea()

            CYLoadingIndicator(message: message, style: style)
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
