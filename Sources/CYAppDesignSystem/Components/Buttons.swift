import SwiftUI

// MARK: - 按钮组件
//
// 预置的主按钮、次按钮样式及缩按压效果。
//
// 用法：
// ```swift
// PrimaryButton(title: "提交", action: { viewModel.submit() })
// PrimaryButton(title: "提交", action: { ... }, isLoading: viewModel.isLoading)
// SecondaryButton(title: "取消", action: { dismiss() })
//
// // 自定义按钮样式
// Button("确认") { ... }
//     .buttonStyle(CYScaledButtonStyle())
// ```

// MARK: - 按压缩放按钮样式

/// 按压缩放按钮样式
/// 点击时轻微缩小，提供触觉反馈
public struct CYScaledButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 主按钮

/// 主按钮（填充背景色 + 加载状态）
public struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool
    
    public init(title: String, action: @escaping () -> Void, isLoading: Bool = false) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(CYAppFont.button)
                }
            }
            .frame(maxWidth: .infinity, minHeight: CYAppDimens.buttonHeight)
            .padding(.horizontal, CYAppDimens.marginM)
            .background(CYAppColor.primary)
            .foregroundColor(.white)
            .cornerRadius(CYAppDimens.radiusM)
        }
        .disabled(isLoading)
    }
}

// MARK: - 次按钮

/// 次按钮（描边轮廓）
public struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(CYAppFont.button)
                .foregroundColor(CYAppColor.secondary)
                .frame(maxWidth: .infinity, minHeight: CYAppDimens.buttonHeight)
                .padding(.horizontal, CYAppDimens.marginM)
                .overlay(
                    RoundedRectangle(cornerRadius: CYAppDimens.radiusM)
                        .stroke(CYAppColor.secondary, lineWidth: CYAppDimens.borderWidth)
                )
        }
    }
}
