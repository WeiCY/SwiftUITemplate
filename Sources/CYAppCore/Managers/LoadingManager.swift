import Foundation
import Observation

// MARK: - Loading 协议

@MainActor
public protocol CYLoadingManagerProtocol: AnyObject, Sendable {
    var isLoading: Bool { get }
    var message: String? { get }
    func show(_ message: String?)
    func hide()
    /// 强制关闭所有加载指示，忽略引用计数。
    func hideAll()
}

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
public final class CYLoadingManager: CYLoadingManagerProtocol, @unchecked Sendable {
    public nonisolated static let shared = CYLoadingManager()
    
    /// 是否正在加载
    public var isLoading: Bool = false
    
    /// 加载提示文字
    public var message: String?
    
    /// 当前活跃加载请求数。
    /// 多个并发任务同时调用 `show()`/`hide()` 时，只有最后一个 `hide()` 才会真正关闭加载。
    private var showCount: Int = 0
    
    public nonisolated init() {}
    
    /// 显示加载指示器
    /// - Parameter message: 可选的加载提示文字
    public func show(_ message: String? = nil) {
        showCount += 1
        self.message = message
        self.isLoading = true
    }
    
    /// 隐藏一次加载指示器。
    /// 仅当所有 `show()` 调用都被平衡后才会真正隐藏。
    public func hide() {
        showCount = max(0, showCount - 1)
        if showCount == 0 {
            self.isLoading = false
            self.message = nil
        }
    }
    
    /// 强制关闭加载指示器，忽略引用计数。
    public func hideAll() {
        showCount = 0
        self.isLoading = false
        self.message = nil
    }
}
