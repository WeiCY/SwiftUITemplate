import Foundation
import XCTest
@testable import CYAppCore

final class UsageSafetyTests: XCTestCase {
    @MainActor
    func testToastNonpositiveCapacityKeepsCurrentMessageWithoutQueueing() {
        for capacity in [0, -1] {
            let toast = CYToastManager()
            toast.queueMode = .queue
            toast.maxQueueSize = capacity
            toast.show("current", duration: 60)
            toast.show("ignored", duration: 60)
            XCTAssertEqual(toast.message, "current")
            XCTAssertEqual(toast.queueCount, 0)
            XCTAssertEqual(toast.maxQueueSize, 0)
            toast.dismissAll()
        }
    }

    @MainActor
    func testToastShrinkingQueueRetainsNewestPendingMessage() {
        let toast = CYToastManager()
        toast.queueMode = .queue
        toast.show("current", duration: 60)
        toast.show("older", duration: 60)
        toast.show("newer", duration: 60)
        toast.maxQueueSize = 1
        XCTAssertEqual(toast.queueCount, 1)
        toast.dismiss()
        XCTAssertEqual(toast.message, "newer")
        XCTAssertEqual(toast.queueCount, 0)
        toast.dismissAll()
    }

    @MainActor
    func testDisablingToastQueueDiscardsPendingMessages() {
        let toast = CYToastManager()
        toast.queueMode = .queue
        toast.show("current", duration: 60)
        toast.show("pending", duration: 60)
        toast.maxQueueSize = 0
        toast.dismiss()
        XCTAssertFalse(toast.isPresented)
        XCTAssertEqual(toast.queueCount, 0)
    }

    @MainActor
    func testNonfiniteToastDurationDoesNotCrashOrDismissImmediately() async {
        let toast = CYToastManager()
        for duration in [Double.infinity, -Double.infinity, Double.nan] {
            toast.show("message", duration: duration)
            await Task.yield()
            XCTAssertTrue(toast.isPresented)
            toast.dismissAll()
        }
    }

    func testCacheRecoversAfterSystemRemovesItsDirectory() async throws {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }
        let first = await cache.save(value: "before", forKey: "key")
        try first.get()
        try FileManager.default.removeItem(at: base.appendingPathComponent("cache"))
        let saved = await cache.save(value: "after", forKey: "key")
        try saved.get()
        // A fresh instance proves disk persistence, rather than reading the memory cache.
        let fresh = CYCacheManager(directoryName: "cache", baseDirectory: base)
        let loaded: String? = await fresh.load(forKey: "key")
        XCTAssertEqual(loaded, "after")
    }

    func testCacheReportsBlockedDirectoryWithoutOverwritingFile() async throws {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }
        let blocked = base.appendingPathComponent("cache")
        try Data("keep".utf8).write(to: blocked)
        let result = await cache.save(value: "value", forKey: "key")
        guard case .failure(.fileSystem(_)) = result else {
            return XCTFail("A file blocking the cache directory must produce a filesystem error")
        }
        XCTAssertEqual(try Data(contentsOf: blocked), Data("keep".utf8))
    }

    func testAnalyticsBufferIsBoundedAndFlushClearsIt() async {
        let service = CYAnalyticsService(maxPendingEvents: 3)
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<30 {
                group.addTask { service.track(event: "event", properties: ["index": index]) }
            }
        }
        XCTAssertEqual(service.pendingEventCount, 3)
        service.flush()
        XCTAssertEqual(service.pendingEventCount, 0)
        service.trackScreen("home")
        XCTAssertEqual(service.pendingEventCount, 1)
    }

    func testAnalyticsNonpositiveCapacityDisablesBuffer() {
        for capacity in [0, -1] {
            let service = CYAnalyticsService(maxPendingEvents: capacity)
            service.identify(userId: "test", traits: ["name": "example"])
            service.track(event: "event")
            service.trackScreen("home")
            XCTAssertEqual(service.pendingEventCount, 0)
        }
    }

    func testDiskTrimClearsMemoryAndAllNamespacesButPreservesUnrelatedFiles() async throws {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }
        let rootSave = await cache.save(value: "root", forKey: "key")
        let nestedSave = await cache.save(value: "nested", forKey: "key", namespace: "photos")
        try rootSave.get()
        try nestedSave.get()
        let foreign = base.appendingPathComponent("cache/v2/notes.txt")
        try Data("keep".utf8).write(to: foreign)
        let trimmed = await cache.trimDisk(to: 0)
        try trimmed.get()
        let root: String? = await cache.load(forKey: "key")
        let nested: String? = await cache.load(forKey: "key", namespace: "photos")
        XCTAssertNil(root)
        XCTAssertNil(nested)
        XCTAssertEqual(try Data(contentsOf: foreign), Data("keep".utf8))
    }

    func testDisabledMemoryCacheCannotReturnDeletedDiskValue() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let cache = CYCacheManager(directoryName: "cache", baseDirectory: base, memoryByteLimit: 0)
        let saved = await cache.save(value: "value", forKey: "key")
        try saved.get()
        try FileManager.default.removeItem(at: base)
        let loaded: String? = await cache.load(forKey: "key")
        XCTAssertNil(loaded)
    }


    func testDiskTrimEvictsOlderWriteBeforeNewerWrite() async throws {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("cache/v2")
        let oldSave = await cache.save(value: "old", forKey: "old")
        try oldSave.get()
        let oldURL = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: oldURL.path)
        let newSave = await cache.save(value: "new", forKey: "new")
        try newSave.get()
        let newURL = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first { $0 != oldURL })
        let budget = try Data(contentsOf: newURL).count
        let trimmed = await cache.trimDisk(to: budget)
        try trimmed.get()
        let old: String? = await cache.load(forKey: "old")
        let new: String? = await cache.load(forKey: "new")
        XCTAssertNil(old)
        XCTAssertEqual(new, "new")
    }

}
