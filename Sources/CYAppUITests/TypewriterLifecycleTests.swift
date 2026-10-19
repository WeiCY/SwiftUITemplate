import XCTest
@testable import CYAppUI

@MainActor
private final class PlaybackGate {
    var pending: [CheckedContinuation<Void, Never>] = []
    func wait() async { await withCheckedContinuation { pending.append($0) } }
    func releaseFirst() { pending.removeFirst().resume() }
}

@MainActor
final class TypewriterLifecycleTests: XCTestCase {
    func testUpdatedTextDiscardsOldPlaybackAndReentryRestarts() async {
        let state = CYTypewriterState()
        let oldGate = PlaybackGate()
        let newGate = PlaybackGate()
        let old = Task { await state.play(text: "ab", speed: 1, enabled: true) { _ in await oldGate.wait() } }
        while oldGate.pending.isEmpty { await Task.yield() }
        XCTAssertEqual(state.displayedText, "a")
        let current = Task { await state.play(text: "XY", speed: 1, enabled: true) { _ in await newGate.wait() } }
        while newGate.pending.isEmpty { await Task.yield() }
        oldGate.releaseFirst()
        await old.value
        XCTAssertEqual(state.displayedText, "X")
        newGate.releaseFirst()
        while newGate.pending.isEmpty { await Task.yield() }
        XCTAssertEqual(state.displayedText, "XY")
        state.cancel()
        newGate.releaseFirst()
        await current.value
        await state.play(text: "XY", speed: 0, enabled: true)
        XCTAssertEqual(state.displayedText, "XY")
    }

    func testCancellationAndDisabledPlayback() async {
        let state = CYTypewriterState()
        let gate = PlaybackGate()
        let task = Task { await state.play(text: "abc", speed: 1, enabled: true) { _ in await gate.wait() } }
        while gate.pending.isEmpty { await Task.yield() }
        task.cancel()
        gate.releaseFirst()
        await task.value
        XCTAssertEqual(state.displayedText, "a")
        await state.play(text: "Updated", speed: 1, enabled: false)
        XCTAssertEqual(state.displayedText, "Updated")
        await state.play(text: "No delay", speed: .nan, enabled: true)
        XCTAssertEqual(state.displayedText, "No delay")
    }
}
