import Foundation
import os

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

public final class CYDebouncer: Sendable {
    private struct Pending {
        let id: UUID
        let item: DispatchWorkItem
    }
    // DispatchWorkItem 非 Sendable，私有状态只在锁内读写，且从不返回锁外。
    private let pending = OSAllocatedUnfairLock(uncheckedState: nil as Pending?)
    private let delay: TimeInterval
    private let queue: DispatchQueue

    public init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = max(0, delay)
        self.queue = queue
    }

    public func debounce(action: @escaping @Sendable () -> Void) {
        pending.withLock { current in
            current?.item.cancel()
            let id = UUID()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let shouldRun = self.pending.withLock { current in
                    guard current?.id == id else { return false }
                    current = nil
                    return true
                }
                if shouldRun { action() }
            }
            current = Pending(id: id, item: item)
            queue.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    public func cancel() {
        pending.withLock { current in
            current?.item.cancel()
            current = nil
        }
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

public final class CYThrottler: Sendable {
    private struct State {
        var lastExecution: TimeInterval?
        var trailingID: UUID?
        var trailingWorkItem: DispatchWorkItem?
    }
    // 状态只在锁内访问；调用方闭包在释放锁后由 queue 执行。
    private let state = OSAllocatedUnfairLock(uncheckedState: State())
    private let interval: TimeInterval
    private let queue: DispatchQueue

    public init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = max(0, interval)
        self.queue = queue
    }

    public func throttle(trailing: Bool = false, action: @escaping @Sendable () -> Void) {
        state.withLock { state in
            let now = ProcessInfo.processInfo.systemUptime
            if let last = state.lastExecution, now - last < interval {
                guard trailing else { return }
                state.trailingWorkItem?.cancel()
                let id = UUID()
                let item = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    let shouldRun = self.state.withLock { state in
                        guard state.trailingID == id else { return false }
                        state.trailingID = nil
                        state.trailingWorkItem = nil
                        state.lastExecution = ProcessInfo.processInfo.systemUptime
                        return true
                    }
                    if shouldRun { action() }
                }
                state.trailingID = id
                state.trailingWorkItem = item
                queue.asyncAfter(deadline: .now() + interval - (now - last), execute: item)
            } else {
                state.trailingWorkItem?.cancel()
                state.trailingID = nil
                state.trailingWorkItem = nil
                state.lastExecution = now
                queue.async(execute: action)
            }
        }
    }

    public func reset() {
        state.withLock { state in
            state.trailingWorkItem?.cancel()
            state = State()
        }
    }
}
