#if canImport(UIKit)
import SwiftUI

/// SwiftUI 分享面板封装（UIActivityViewController 桥接）
///
/// 用法：
/// ```swift
/// .sheet(isPresented: $showShare) {
///     CYShareSheet(items: [url, text])
/// }
///
/// // 或使用 View modifier：
/// .shareSheet(isPresented: $showShare, items: [url])
/// ```
public struct CYShareSheet: UIViewControllerRepresentable {
    
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    
    public init(
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil
    ) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View 扩展

extension View {
    
    /// 便捷的分享面板修饰符
    /// - 参数：
    ///   - isPresented: 是否显示分享面板
    ///   - items: 要分享的内容
    public func shareSheet(isPresented: Binding<Bool>, items: [Any]) -> some View {
        sheet(isPresented: isPresented) {
            CYShareSheet(items: items)
        }
    }
}
#endif
