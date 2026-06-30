import SwiftUI
import CYAppCore

// MARK: - 通用状态容器视图

/// 通用状态容器视图，统一处理 Loading / Error / Content 三种状态
///
/// 用法：
/// ```swift
/// CYBaseView(isLoading: viewModel.isLoading, error: viewModel.error) {
///     // 正常内容
///     List(viewModel.items) { ... }
/// }
/// ```
///
/// 带重试：
/// ```swift
/// CYBaseView(
///     isLoading: viewModel.isLoading,
///     error: viewModel.error,
///     onRetry: { Task { await viewModel.fetchItems() } }
/// ) {
///     List(viewModel.items) { ... }
/// }
/// ```
public struct CYBaseView<Content: View>: View {
    
    let isLoading: Bool
    let error: CYAppError?
    let onRetry: (() -> Void)?
    let content: Content
    
    public init(
        isLoading: Bool = false,
        error: CYAppError? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.onRetry = onRetry
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            // MARK: - Main Content
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 3 : 0)
            
            // MARK: - Error State
            if let error = error {
                errorView(error)
            }
            
            // MARK: - Loading State
            if isLoading {
                loadingOverlay
            }
        }
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func errorView(_ error: CYAppError) -> some View {
        VStack(spacing: CYAppDimens.marginM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(CYAppColor.error)
            
            Text("Something went wrong")
                .font(CYAppFont.h3)
                .foregroundColor(CYAppColor.textPrimary)
            
            Text(error.message)
                .font(CYAppFont.bodyMedium)
                .foregroundColor(CYAppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Text("Retry")
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
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ProgressView()
            .scaleEffect(1.5)
            .progressViewStyle(CircularProgressViewStyle(tint: CYAppColor.accent))
            .padding(CYAppDimens.marginL)
            .background(.ultraThinMaterial)
            .cornerRadius(CYAppDimens.radiusM)
            .shadow(radius: 5)
    }
}

// MARK: - Previews

#Preview("Loading") {
    CYBaseView(isLoading: true, error: nil) {
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
