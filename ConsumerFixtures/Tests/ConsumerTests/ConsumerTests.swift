import XCTest
import CoreOnly
import OfflinePersistence
import NetworkOnly
import DesignSystemConsumer
import CustomComposition

final class ConsumerTests: XCTestCase {
    func testCoreOnlyWithoutNetworkRegistration() throws { XCTAssertTrue(try CoreConsumer.check()) }

    @MainActor
    func testOfflineCRUDAndOriginalInitializationError() throws { XCTAssertTrue(try OfflineConsumer.check()) }

    func testNetworkSuccessFailureAndActualCancellation() async throws {
        defer { FixtureHTTPProtocol.handler.withLock { $0 = .init() } }
        FixtureHTTPProtocol.handler.withLock { $0 = .init(start: { $0.respond(code: 200, body: #"{"value":7}"#) }) }
        let value = try await NetworkConsumer.fetch(client: NetworkConsumer.makeClient())
        XCTAssertEqual(value, 7)
        FixtureHTTPProtocol.handler.withLock { $0 = .init(start: { $0.respond(code: 500, body: "failure") }) }
        do {
            _ = try await NetworkConsumer.fetch(client: NetworkConsumer.makeClient())
            XCTFail("Expected HTTP failure")
        } catch { XCTAssertTrue(String(describing: error).contains("500")) }
        let started = expectation(description: "started")
        let stopped = expectation(description: "stopped")
        FixtureHTTPProtocol.handler.withLock { $0 = .init(start: { _ in started.fulfill() }, stop: { stopped.fulfill() }) }
        let task = Task { try await NetworkConsumer.fetch(client: NetworkConsumer.makeClient()) }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(NetworkConsumer.isCancellation(error)) }
        await fulfillment(of: [stopped], timeout: 3)
    }

    @MainActor
    func testHostOwnedPaginationFailureAndSamePageRecovery() async {
        let model = ConsumerPages()
        await model.refresh()
        XCTAssertNotNil(model.error)
        model.failFirst = false
        await model.retry()
        XCTAssertEqual(model.items.count, 20)
        await model.append()
        await model.append()
        XCTAssertEqual(model.requests, [1, 1, 2])
        XCTAssertEqual(model.page, 1)
        model.failAppend = false
        await model.retry()
        XCTAssertEqual(model.requests, [1, 1, 2, 2])
        XCTAssertEqual(Set(model.items.map(\.id)).count, 40)
        model.failFirst = true
        await model.refresh()
        XCTAssertEqual(model.page, 2)
        XCTAssertEqual(model.items.count, 40)
    }

    @MainActor
    func testHostOwnedPaginationCancellationAndOldResponseIsolation() async {
        var pending: [CheckedContinuation<[ConsumerRow], Error>] = []
        let model = ConsumerPages { _ in try await withCheckedThrowingContinuation { pending.append($0) } }
        model.failFirst = false
        let old = Task { await model.refresh() }
        while pending.count < 1 { await Task.yield() }
        let current = Task { await model.refresh() }
        while pending.count < 2 { await Task.yield() }
        pending[1].resume(returning: [ConsumerRow(id: 2)])
        await current.value
        pending[0].resume(returning: [ConsumerRow(id: 1)])
        await old.value
        XCTAssertEqual(model.items.map(\.id), [2])
        let cancel = Task { await model.refresh() }
        while pending.count < 3 { await Task.yield() }
        cancel.cancel()
        pending[2].resume(returning: [])
        await cancel.value
        XCTAssertNil(model.error)
        XCTAssertEqual(model.items.map(\.id), [2])
    }

    @MainActor
    func testCustomInstancesAndRoutersDoNotShareState() {
        let first = HostComposition()
        let second = HostComposition()
        first.toast.show("First", type: .info, duration: 10)
        first.loading.show("Loading")
        first.alert.showAlert(title: "First", message: nil, type: .info)
        first.router.navigate(to: "Detail")
        XCTAssertTrue(first.toast.isPresented)
        XCTAssertFalse(second.toast.isPresented)
        XCTAssertFalse(second.loading.isLoading)
        XCTAssertFalse(second.alert.isPresented)
        XCTAssertEqual(second.router.depth(for: "one"), 0)
        XCTAssertEqual(first.router.depth(for: "one"), 1)
        XCTAssertTrue(HostComposition.checkBrand())
    }

    func testCustomLoaderActuallyCancels() async {
        let loader = HostImageLoader()
        let task = Task { try await loader.loadImage(from: URL(string: "https://local.invalid/slow")!) }
        while await loader.started == 0 { await Task.yield() }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        let cancelled = await loader.cancelled
        XCTAssertEqual(cancelled, 1)
    }
}
