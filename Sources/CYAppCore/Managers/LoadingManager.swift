import Foundation
import Observation

// MARK: - 全局加载状态管理
//
// 管理全局的加载指示器状态，配合 CYLoadingOverlay 使用。
//
// 用法：
// ```swift
// // 显示加载
// CYLoadingManager.shared.show("加载中...")
//
// // 隐藏加载
// CYLoadingManager.shared.hide()
//
// // View 中使用：
// .loadingOverlay()
// ```

@Observable
@MainActor
public final class CYLoadingManager {
    public nonisolated static let shared = CYLoadingManager()
    
    /// 是否正在加载
    public var isLoading: Bool = false
    
    /// 加载提示文字
    public var message: String?
    
    public nonisolated init() {}
    
    /// 显示加载指示器
    /// - Parameter message: 可选的加载提示文字
    public func show(_ message: String? = nil) {
        self.message = message
        self.isLoading = true
    }
    
    /// 隐藏加载指示器
    public func hide() {
        self.isLoading = false
        self.message = nil
    }
}
