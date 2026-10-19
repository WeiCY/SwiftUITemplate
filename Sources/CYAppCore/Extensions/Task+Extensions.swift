import Foundation

extension Task where Success == Never, Failure == Never {

    public static func sleep(seconds: Double) async throws {
        try await sleep(for: .seconds(seconds))
    }

    public static func sleep(milliseconds: Int) async throws {
        try await sleep(for: .milliseconds(milliseconds))
    }
}

extension Task where Failure == Error {

    @discardableResult
    public static func retry(
        times: Int,
        delay: Duration = .seconds(1),
        backoff: Double = 2.0,
        operation: @Sendable @escaping () async throws -> Success
    ) async throws -> Success {
        guard times > 0 else { throw CYRetryError.exhausted }
        guard delay >= .zero, backoff.isFinite, backoff >= 0 else { throw CYRetryError.invalidParameters }
        var currentDelay = delay
        var lastError: Error?
        for attempt in 0..<times {
            do {
                try Task<Never, Never>.checkCancellation()
                let result = try await operation()
                try Task<Never, Never>.checkCancellation()
                return result
            } catch {
                if Task<Never, Never>.isCancelled || CYAppError.resolve(error).isCancellation { throw _Concurrency.CancellationError() }
                lastError = error
                if attempt < times - 1 {
                    try await Task<Never, Never>.sleep(for: currentDelay)
                    // 保留亚秒精度，避免延迟 < 1s 时退避被截断为 0
                    let components = currentDelay.components
                    let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
                    let next = seconds * backoff
                    guard next.isFinite, next < Double(Int64.max) / 2 else { throw CYRetryError.invalidParameters }
                    currentDelay = .seconds(next)
                }
            }
        }
        throw lastError ?? CYRetryError.exhausted
    }
}

public enum CYRetryError: Error, LocalizedError, Sendable {
    case exhausted
    case invalidParameters

    public var errorDescription: String? {
        switch self {
        case .exhausted: return "Retry attempts exhausted"
        case .invalidParameters: return "Delay and backoff must be finite and nonnegative"
        }
    }
}

/// 协作式超时：会取消子任务，但必须等待不配合取消的 operation 退出，不能强制终止。
/// seconds 必须有限且大于零；取消父任务始终按取消处理。
public func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    guard seconds.isFinite, seconds > 0, seconds < Double(Int64.max) / 2 else { throw CYTimeoutError.invalidInterval }
    try Task.checkCancellation()
    do {
        return try await withThrowingTaskGroup(of: T.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                try Task.checkCancellation()
                let result = try await operation()
                try Task.checkCancellation()
                return result
            }
            group.addTask {
                try await Task<Never, Never>.sleep(seconds: seconds)
                throw CYTimeoutError.timedOut
            }
            guard let result = try await group.next() else {
                throw CYTimeoutError.timedOut
            }
            try Task.checkCancellation()
            return result
        }
    } catch {
        if Task.isCancelled { throw CancellationError() }
        throw error
    }
}

public enum CYTimeoutError: Error, LocalizedError, Sendable {
    case timedOut
    case invalidInterval

    public var errorDescription: String? {
        switch self {
        case .timedOut: return "Operation timed out"
        case .invalidInterval: return "Timeout must be finite and greater than zero"
        }
    }
}
