import Foundation
import Synchronization
import XCTest
@testable import CYAppCore
@testable import CYAppNetwork

@MainActor
final class CredentialCancellationTests: XCTestCase {
    private struct ProtectedEndpoint: CYEndpoint {
        let path = "/protected"
        let method: CYHTTPMethod = .post
        let authentication: CYAuthenticationPolicy = .required
    }

    func testCancelledWaiterReturnsBeforeRecoveryFinishesWithoutReplaying() async throws {
        let recoveryEntered = expectation(description: "recovery started")
        let cancelledFinished = expectation(description: "cancelled caller released")
        let recoveryFinished = expectation(description: "shared recovery finished")
        let gate = ReliabilityGate()
        let attempts = Mutex((cancelled: 0, recoveries: 0))
        let client = CYNetworkClient(baseURL: "https://example.test")
        client.setCredentialRecovery(CYCredentialRecovery(action: {
            attempts.withLock { $0.recoveries += 1 }
            recoveryEntered.fulfill()
            await gate.wait()
            XCTAssertFalse(Task.isCancelled)
            recoveryFinished.fulfill()
            return true
        }))
        let first = Task {
            defer { cancelledFinished.fulfill() }
            do {
                let _: String = try await client.performRequest(ProtectedEndpoint()) {
                    attempts.withLock { $0.cancelled += 1 }
                    throw CYNetworkError.httpError(statusCode: 401, data: nil)
                }
                XCTFail("Expected cancellation")
            } catch {
                guard case CYNetworkError.cancelled = error else { return XCTFail("Expected cancellation, got \(error)") }
            }
        }
        await fulfillment(of: [recoveryEntered], timeout: 2)
        first.cancel()
        // This expectation must finish before opening the recovery gate.
        await fulfillment(of: [cancelledFinished], timeout: 2)
        await gate.open()
        await first.value
        await fulfillment(of: [recoveryFinished], timeout: 2)
        XCTAssertEqual(attempts.withLock { $0.cancelled }, 1)
        XCTAssertEqual(attempts.withLock { $0.recoveries }, 1)
    }

    func testAlreadyCancelledCallerDoesNotStartRecoveryOrRequest() async {
        let gate = ReliabilityGate()
        let requests = Mutex(0)
        let client = CYNetworkClient(baseURL: "https://example.test")
        let task = Task {
            await gate.wait()
            do {
                let _: String = try await client.performRequest(ProtectedEndpoint()) {
                    requests.withLock { $0 += 1 }
                    return "unexpected"
                }
                XCTFail("Expected cancellation")
            } catch {
                guard case CYNetworkError.cancelled = error else { return XCTFail("Expected cancellation") }
            }
        }
        task.cancel()
        await gate.open()
        await task.value
        XCTAssertEqual(requests.withLock { $0 }, 0)
    }

    func testCancelledCoordinatorCallerDoesNotStartRecovery() async {
        let gate = ReliabilityGate()
        let recoveries = Mutex(0)
        let coordinator = CYCredentialRecoveryCoordinator(recovery: CYCredentialRecovery(action: {
            recoveries.withLock { $0 += 1 }
            return true
        }))
        let task = Task { await gate.wait(); return await coordinator.recoverIfNeeded() }
        task.cancel()
        await gate.open()
        let result = await task.value
        XCTAssertFalse(result)
        XCTAssertEqual(recoveries.withLock { $0 }, 0)
    }
}
