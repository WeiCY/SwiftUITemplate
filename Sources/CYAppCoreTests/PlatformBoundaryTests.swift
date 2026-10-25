import CoreLocation
import CYTestSupport
import Foundation
import XCTest
@testable import CYAppCore

@MainActor
private final class LocationDriver: CYLocationAuthorizationDriving {
    var current: CLAuthorizationStatus = .notDetermined
    var reads = 0
    var authorizationStatus: CLAuthorizationStatus { reads += 1; return current }
    var onChange: (@MainActor (CLAuthorizationStatus) -> Void)?
    var requests = 0
    func requestWhenInUseAuthorization() { requests += 1 }
    func emit(_ status: CLAuthorizationStatus) { current = status; onChange?(status) }
}

@MainActor
private final class PathDriver: CYNetworkPathDriving {
    var handler: (@Sendable (CYNetworkPathSnapshot) -> Void)?
    var cancellations = 0
    func start(_ handler: @escaping @Sendable (CYNetworkPathSnapshot) -> Void) { self.handler = handler }
    func cancel() { cancellations += 1 }
    func emit(connected: Bool) {
        handler?(CYNetworkPathSnapshot(isConnected: connected, connectionType: connected ? .wifi : .unknown,
                                      isExpensive: false, isConstrained: false))
    }
}

final class PlatformBoundaryTests: XCTestCase {
    @MainActor
    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(condition(), "Condition did not become true")
    }

    @MainActor
    func testConcurrentLocationRequestsWaitForDecision() async {
        let driver = LocationDriver()
        let permission = CYLocationPermission(driver: driver)
        var completed = 0
        let first = Task { let value = await permission.request(); completed += 1; return value }
        let second = Task { let value = await permission.request(); completed += 1; return value }
        await waitUntil { driver.reads >= 4 }
        driver.emit(.notDetermined)
        XCTAssertEqual(completed, 0)
        XCTAssertEqual(driver.requests, 1)
        driver.emit(.authorizedWhenInUse)
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, .authorized)
        XCTAssertEqual(secondResult, .authorized)
    }

    @MainActor
    func testCancellingOneLocationWaiterDoesNotCancelOthers() async {
        let driver = LocationDriver()
        let permission = CYLocationPermission(driver: driver)
        let first = Task { await permission.request() }
        let second = Task { await permission.request() }
        await waitUntil { driver.reads >= 4 }
        first.cancel()
        let cancelled = await first.value
        XCTAssertEqual(cancelled, .notDetermined)
        driver.emit(.denied)
        let result = await second.value
        XCTAssertEqual(result, .denied)
        XCTAssertEqual(driver.requests, 1)
    }

    @MainActor
    func testAlreadyCancelledLocationRequestDoesNotPrompt() async {
        let driver = LocationDriver()
        let permission = CYLocationPermission(driver: driver)
        let task = Task { await permission.request() }
        task.cancel() // Task cannot enter the MainActor until this method suspends.
        let result = await task.value
        XCTAssertEqual(result, .notDetermined)
        XCTAssertEqual(driver.requests, 0)
    }

    @MainActor
    func testRestartRejectsOldAndStoppedNetworkCallbacks() async {
        let old = PathDriver()
        let next = PathDriver()
        var creations = 0
        let monitor = CYNetworkMonitor(makeDriver: {
            creations += 1
            return creations == 1 ? old : next
        })
        monitor.startMonitoring()
        monitor.startMonitoring()
        XCTAssertEqual(creations, 1)
        old.emit(connected: false) // Queued to MainActor, but not applied before stop.
        monitor.stopMonitoring()
        monitor.startMonitoring()
        next.emit(connected: true)
        await waitUntil { monitor.hasReceivedUpdate }
        XCTAssertTrue(monitor.isConnected)
        XCTAssertEqual(old.cancellations, 1)
        // Explicitly submit another stale callback after the new path has arrived.
        old.emit(connected: false)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(monitor.isConnected, "A previous generation must not overwrite the active path")
        monitor.stopMonitoring()
        next.emit(connected: false)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(monitor.isConnected)
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertFalse(monitor.hasReceivedUpdate)
        XCTAssertEqual(next.cancellations, 1)
    }

    @MainActor
    func testBootstrapUpdatesExistingAndFutureLoggerCategories() {
        let saved = CYGlobalTestState()
        defer { saved.restore() }
        let existing = CYLogger(category: "Existing")
        let overridden = CYLogger(category: "Override")
        overridden.setMinimumLevel(.critical)
        CYCoreBootstrap.configure(CYAppConfig(minimumLogLevel: .warning))
        XCTAssertEqual(existing.minimumLevel, .warning)
        XCTAssertEqual(CYLogger.network.minimumLevel, .warning)
        XCTAssertEqual(CYLogger.cache.minimumLevel, .warning)
        XCTAssertEqual(CYLogger(category: "Future").minimumLevel, .warning)
        XCTAssertEqual(overridden.minimumLevel, .critical)
        overridden.resetMinimumLevel()
        XCTAssertEqual(overridden.minimumLevel, .warning)
    }

    func testPrivacyManifestIsPackagedWithCore() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        let entries = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 4)
        XCTAssertTrue(entries.allSatisfy { ($0["NSPrivacyAccessedAPITypeReasons"] as? [String])?.isEmpty == false })
    }
}
