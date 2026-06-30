import Foundation

// MARK: - 防抖器 (CYDebouncer)
//
// 延迟执行操作，在安静期结束后才触发。
// 适用于搜索输入、文本框实时校验等场景。
//
// 用法：
// ```swift
// let debouncer = CYDebouncer(delay: 0.3)
// debouncer.debounce {
//     // 执行搜索
// }
// ```

public final class CYDebouncer: @unchecked Sendable {
    
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    /// - 参数：
    ///   - delay: 防抖延迟时间（秒）
    ///   - queue: 执行队列（默认主线程）
    public init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    /// 调度新的防抖操作，之前的待执行操作会被取消
    public func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        
        let item = DispatchWorkItem(block: action)
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    /// 取消待执行的防抖操作
    public func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - 节流器 (CYThrottler)
//
// 限制操作在指定时间间隔内最多执行一次。
// 适用于按钮点击、滚动事件、埋点上报等场景。
//
// 用法：
// ```swift
// let throttler = CYThrottler(interval: 1.0)
// throttler.throttle {
//     // 执行操作（最多每秒一次）
// }
// ```

public final class CYThrottler: @unchecked Sendable {
    
    private let interval: TimeInterval
    private var lastExecution: Date?
    private let queue: DispatchQueue
    
    /// - 参数：
    ///   - interval: 最小执行间隔（秒）
    ///   - queue: 执行队列（默认主线程）
    public init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }
    
    /// 执行节流操作
    /// - Parameter trailing: 为 true 时在间隔结束时也执行一次（默认 false）
    public func throttle(trailing: Bool = false, action: @escaping () -> Void) {
        let now = Date()
        
        if let last = lastExecution, now.timeIntervalSince(last) < interval {
            if trailing {
                let remaining = interval - now.timeIntervalSince(last)
                queue.asyncAfter(deadline: .now() + remaining) { [weak self] in
                    self?.lastExecution = Date()
                    action()
                }
            }
            return
        }
        
        lastExecution = now
        queue.async(execute: action)
    }
    
    /// 重置节流计时器
    public func reset() {
        lastExecution = nil
    }
}
