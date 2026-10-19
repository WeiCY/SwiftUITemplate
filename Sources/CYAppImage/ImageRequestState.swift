import Foundation
import Synchronization

/// 将回调桥接到 async。所有状态转换在锁内，恢复/取消在锁外，允许同步完成及提前取消。
final class CYImageRequestState: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Data, Error>?
        var cancellation: (@Sendable () -> Void)?
        var result: Result<Data, Error>?
    }
    private let state = Mutex(State())

    func install(_ continuation: CheckedContinuation<Data, Error>) {
        let result = state.withLock { state -> Result<Data, Error>? in
            if let result = state.result { return result }
            state.continuation = continuation
            return nil
        }
        if let result { continuation.resume(with: result) }
    }

    func setCancellation(_ cancellation: @escaping @Sendable () -> Void) {
        let shouldCancel = state.withLock { state in
            if case .failure(let error) = state.result, error is CancellationError { return true }
            guard state.result == nil else { return false }
            state.cancellation = cancellation
            return false
        }
        if shouldCancel { cancellation() }
    }

    func complete(_ result: Result<Data, Error>) {
        let continuation = state.withLock { state in
            guard state.result == nil else { return nil as CheckedContinuation<Data, Error>? }
            state.result = result
            let continuation = state.continuation
            state.continuation = nil
            state.cancellation = nil
            return continuation
        }
        continuation?.resume(with: result)
    }

    func cancel() {
        let pending = state.withLock { state -> (CheckedContinuation<Data, Error>?, (@Sendable () -> Void)?) in
            guard state.result == nil else { return (nil, nil) }
            state.result = .failure(CancellationError())
            let pending = (state.continuation, state.cancellation)
            state.continuation = nil
            state.cancellation = nil
            return pending
        }
        pending.0?.resume(throwing: CancellationError())
        pending.1?()
    }
}
