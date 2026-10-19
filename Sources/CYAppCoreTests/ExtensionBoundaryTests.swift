import XCTest
import Synchronization
@testable import CYAppCore

private actor TimeoutGate {
    var pending: CheckedContinuation<Int, Error>?
    func wait() async throws -> Int { try await withCheckedThrowingContinuation { pending = $0 } }
    var isWaiting: Bool { pending != nil }
    func fail() { pending?.resume(throwing: NSError(domain: "FakeCancelledOperation", code: 1)); pending = nil }
}

final class ExtensionBoundaryTests: XCTestCase {
    func testTruncationNonpositiveAndGraphemeBoundaries() {
        XCTAssertEqual("abc".truncated(to: -1), "")
        XCTAssertEqual("abc".truncated(to: 0), "")
        XCTAssertEqual("👨‍👩‍👧‍👦ab".truncated(to: 1), "👨‍👩‍👧‍👦...")
    }

    func testThrowingDecodePreservesKeyNotFound() {
        struct Payload: Decodable { let name: String }
        XCTAssertNil(Payload.from(jsonString: "{}"))
        XCTAssertThrowsError(try Payload.decode(jsonString: "{}")) {
            guard case DecodingError.keyNotFound = $0 else { return XCTFail("Expected original decoding error") }
        }
        XCTAssertEqual(try Payload.decode(dictionary: ["name": "Example"]).name, "Example")
    }

    func testDateCacheSeparatesTimeZoneLocaleAndCalendar() {
        let date = Date(timeIntervalSince1970: 0)
        let locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(date.toString(format: "HH", locale: locale, timeZone: TimeZone(secondsFromGMT: 0)!), "00")
        XCTAssertEqual(date.toString(format: "HH", locale: locale, timeZone: TimeZone(secondsFromGMT: 28800)!), "08")
        let gregorian = date.toString(format: "yyyy", locale: locale, calendar: Calendar(identifier: .gregorian))
        let buddhist = date.toString(format: "yyyy", locale: locale, calendar: Calendar(identifier: .buddhist))
        XCTAssertNotEqual(gregorian, buddhist)
    }

    func testRetryRejectsInvalidBoundsAndDoesNotRetryCancellation() async {
        let calls = Mutex(0)
        do { _ = try await Task<Int, Error>.retry(times: -1) { 1 }; XCTFail("Expected error") } catch { XCTAssertTrue(error is CYRetryError) }
        do {
            _ = try await Task<Int, Error>.retry(times: 3, delay: .zero) {
                calls.withLock { $0 += 1 }
                throw CancellationError()
            }
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(calls.withLock { $0 }, 1)
    }

    func testTimeoutRejectsInvalidIntervalsWithoutRunningOperation() async {
        let calls = Mutex(0)
        for interval in [Double.nan, .infinity, 0, -1] {
            do {
                _ = try await withTimeout(seconds: interval) { calls.withLock { $0 += 1 }; return 1 }
                XCTFail("Expected invalid interval")
            } catch { XCTAssertTrue(error is CYTimeoutError) }
        }
        XCTAssertEqual(calls.withLock { $0 }, 0)
    }
    func testTimeoutParentCancellationWinsOverOperationFailure() async {
        let gate = TimeoutGate()
        let task = Task { try await withTimeout(seconds: 60) { try await gate.wait() } }
        while !(await gate.isWaiting) { await Task.yield() }
        task.cancel()
        await gate.fail()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

}
