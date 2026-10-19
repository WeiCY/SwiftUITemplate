import XCTest
@testable import CYAppDesignSystem

private actor SnackSleeper {
    private var pending: [CheckedContinuation<Void, Never>] = []
    var count: Int { pending.count }
    func wait() async { await withCheckedContinuation { pending.append($0) } }
    func resume(_ index: Int) { pending[index].resume() }
}

@MainActor
final class SnackBarLifecycleTests: XCTestCase {
    func testReplacingMessageIgnoresOldTimerEvenWhenWaitIgnoresCancellation() async {
        let sleeper = SnackSleeper()
        let manager = CYSnackBarManager(wait: { _ in await sleeper.wait() })
        manager.show(message: "Old")
        let old = manager.dismissTask
        while await sleeper.count < 1 { await Task.yield() }
        manager.show(message: "New")
        let current = manager.dismissTask
        while await sleeper.count < 2 { await Task.yield() }
        await sleeper.resume(0)
        await old?.value
        XCTAssertTrue(manager.isPresented)
        XCTAssertEqual(manager.message, "New")
        await sleeper.resume(1)
        await current?.value
        XCTAssertFalse(manager.isPresented)
        XCTAssertNil(manager.message)
    }

    func testDismissAndShowInSameTurnCannotCloseNewMessage() async {
        let manager = CYSnackBarManager()
        manager.show(message: "Old", duration: 60)
        let old = manager.dismissTask
        manager.dismiss()
        manager.show(message: "New", duration: 0)
        await old?.value
        XCTAssertEqual(manager.message, "New")
        manager.dismiss()
    }

    func testInvalidDurationsStayUntilExplicitDismissal() {
        let manager = CYSnackBarManager()
        for duration in [Double.nan, .infinity, -.infinity, -1, 0, .greatestFiniteMagnitude] {
            manager.show(message: "Persistent", duration: duration)
            XCTAssertNil(manager.dismissTask)
            XCTAssertTrue(manager.isPresented)
            manager.dismiss()
        }
    }

    func testActionCanPresentSuccessorAndOnlyRunsOnce() {
        let manager = CYSnackBarManager()
        var calls = 0
        manager.show(message: "Undo?", actionTitle: "Undo", duration: 0) {
            calls += 1
            manager.show(message: "Undone", duration: 0)
        }
        manager.performAction()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(manager.message, "Undone")
        manager.performAction()
        XCTAssertEqual(calls, 1)
    }
}
