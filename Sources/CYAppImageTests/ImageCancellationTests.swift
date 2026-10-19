import Foundation
import Synchronization
import XCTest
@testable import CYAppImage

final class ImageCancellationTests: XCTestCase {
    func testCancellationBeforeContinuationAndHandle() async {
        let state = CYImageRequestState()
        let cancellations = Mutex(0)
        state.cancel()
        state.setCancellation { cancellations.withLock { $0 += 1 } }
        do {
            _ = try await withCheckedThrowingContinuation { state.install($0) }
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(cancellations.withLock { $0 }, 1)
        state.complete(.success(Data([1])))
    }

    func testSynchronousCompletionAndDuplicateCallback() async throws {
        let state = CYImageRequestState()
        state.complete(.success(Data([7])))
        state.complete(.success(Data([8])))
        state.cancel()
        let data = try await withCheckedThrowingContinuation { state.install($0) }
        XCTAssertEqual(data, Data([7]))
    }

    func testConcurrentCompletionAndCancellationResolveExactlyOnce() async {
        for _ in 0..<100 {
            let state = CYImageRequestState()
            let result = Task { try await withCheckedThrowingContinuation { state.install($0) } }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { state.cancel() }
                group.addTask { state.complete(.success(Data([9]))) }
            }
            do { let data = try await result.value; XCTAssertEqual(data, Data([9])) } catch { XCTAssertTrue(error is CancellationError) }
        }
    }
}
