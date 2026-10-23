// Linux-only substitute for the Apple lock used by unchanged BusinessCode/AppConstants.
// Tests exercise their production policies, but do not validate OSAllocatedUnfairLock itself.
import Foundation

public final class OSAllocatedUnfairLock<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State
    public init(initialState: State) { state = initialState }
    public func withLock<Result>(_ body: (inout State) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&state)
    }
}
