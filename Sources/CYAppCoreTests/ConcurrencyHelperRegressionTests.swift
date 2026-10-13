import XCTest
import os
@testable import CYAppCore

final class ConcurrencyHelperRegressionTests: XCTestCase {
    func testConcurrentDebounceAndCancelLeaveOnlyFinalAction() async {
        let queue = DispatchQueue(label: "CYDebouncerTests")
        queue.suspend()
        let debouncer = CYDebouncer(delay: 0, queue: queue)
        let count = OSAllocatedUnfairLock(initialState: 0)
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            debouncer.debounce { count.withLock { $0 += 1 } }
            if index.isMultiple(of: 2) { debouncer.cancel() }
        }
        debouncer.cancel()
        let done = expectation(description: "final action")
        debouncer.debounce {
            count.withLock { $0 += 1 }
            done.fulfill()
        }
        queue.resume()
        await fulfillment(of: [done], timeout: 2)
        XCTAssertEqual(count.withLock { $0 }, 1)
    }

    func testConcurrentThrottleEmitsOneActionAndResetAllowsNext() async {
        let queue = DispatchQueue(label: "CYThrottlerTests")
        let throttler = CYThrottler(interval: 3600, queue: queue)
        let count = OSAllocatedUnfairLock(initialState: 0)
        let first = expectation(description: "first action")
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            throttler.throttle {
                count.withLock { $0 += 1 }
                first.fulfill()
            }
        }
        await fulfillment(of: [first], timeout: 2)
        XCTAssertEqual(count.withLock { $0 }, 1)
        throttler.reset()
        let next = expectation(description: "action after reset")
        throttler.throttle {
            count.withLock { $0 += 1 }
            next.fulfill()
        }
        await fulfillment(of: [next], timeout: 2)
        XCTAssertEqual(count.withLock { $0 }, 2)
    }
}
