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
        var currentDelay = delay
        var lastError: Error?
        for attempt in 0..<times {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < times - 1 {
                    try await Task<Never, Never>.sleep(for: currentDelay)
                    // 保留亚秒精度，避免延迟 < 1s 时退避被截断为 0
                    let components = currentDelay.components
                    let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
                    currentDelay = .seconds(seconds * backoff)
                }
            }
        }
        throw lastError ?? CYRetryError.exhausted
    }
}

public enum CYRetryError: Error, LocalizedError, Sendable {
    case exhausted

    public var errorDescription: String? {
        switch self {
        case .exhausted: return "Retry attempts exhausted"
        }
    }
}

public func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task<Never, Never>.sleep(seconds: seconds)
            throw CYTimeoutError.timedOut
        }
        guard let result = try await group.next() else {
            throw CYTimeoutError.timedOut
        }
        group.cancelAll()
        return result
    }
}

public enum CYTimeoutError: Error, LocalizedError, Sendable {
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .timedOut: return "Operation timed out"
        }
    }
}
