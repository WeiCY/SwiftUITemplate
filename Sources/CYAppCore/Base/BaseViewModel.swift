import Foundation
import Observation

// MARK: - ViewModel 基类

/// ViewModel 基类，提供统一的 loading / error / retry 管理
///
/// 使用 `@Observable` (Swift 5.9+) 实现自动 UI 刷新。
/// 子类只需关注业务逻辑，通过 `executeTask` 处理异步任务：
///
/// ```swift
/// @Observable
/// final class HomeViewModel: CYBaseViewModel {
///     var items: [Item] = []
///
///     func fetchItems() async {
///         await executeTask {
///             items = try await service.fetchItems()
///         }
///     }
/// }
/// ```
@MainActor
@Observable
open class CYBaseViewModel {
    
    // MARK: - 公开状态
    
    /// 是否正在加载
    public var isLoading: Bool = false
    
    /// 当前错误（nil 表示无错误）
    public var error: CYAppError?
    
    /// 便捷属性：是否有错误
    public var hasError: Bool { error != nil }
    
    /// 错误描述文本（供 View 层直接展示）
    public var errorMessage: String? { error?.message }
    
    // MARK: - 私有属性
    
    private var retryAction: (() async -> Void)?
    
    // MARK: - 初始化
    
    public init() {}
    
    // MARK: - 任务执行
    
    /// 执行异步任务，自动管理 loading / error 状态
    ///
    /// - Parameter action: 需要执行的异步操作
    ///
    /// 执行流程：
    /// 1. 设置 `isLoading = true`，清除旧错误
    /// 2. 执行 `action`
    /// 3. 成功 → `isLoading = false`
    /// 4. 失败 → `isLoading = false`，设置 `error`，保存重试闭包
    public func executeTask(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        error = nil
        
        do {
            try await action()
            isLoading = false
        } catch {
            isLoading = false
            self.error = CYAppError.resolve(error)
            // 保存重试闭包，方便 View 层一键重试
            self.retryAction = { [weak self] in
                await self?.executeTask(action)
            }
        }
    }
    
    // MARK: - 错误管理
    
    /// 清除当前错误
    public func clearError() {
        error = nil
        retryAction = nil
    }
    
    /// 重试上一次失败的操作
    public func retry() async {
        guard let retryAction else { return }
        await retryAction()
    }
}
