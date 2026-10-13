import Foundation
import XCTest
@testable import CYAppCore

private actor ReviewGate {
    private var continuation: CheckedContinuation<Int, Never>?
    var isWaiting: Bool { continuation != nil }
    func wait() async -> Int {
        await withCheckedContinuation { continuation = $0 }
    }
    func release(_ value: Int) { continuation?.resume(returning: value); continuation = nil }
}

private struct ReviewRow: Identifiable, Sendable { let id: Int }

@MainActor
private final class ReviewPageVM: CYPaginatedListViewModel<ReviewRow> {
    var pageTwo: CheckedContinuation<[ReviewRow], Never>?
    var failsRefresh = false
    override func fetchPage(page: Int, pageSize: Int) async throws -> [ReviewRow] {
        if page == 1, failsRefresh { throw CYNetworkError.noConnection }
        if page == 1 { return [ReviewRow(id: 100)] }
        return await withCheckedContinuation { pageTwo = $0 }
    }
}

private struct ReviewPermission: CYPermissionRequester {
    var status: CYPermissionStatus { get async { .restricted } }
    func request() async -> CYPermissionStatus { .restricted }
}

private struct ReviewEndpoint: CYEndpoint {
    let queryItems: [URLQueryItem]?
    var headers: [String: String]? = nil
    var path: String { "/search" }
    var method: CYHTTPMethod { .get }
}

@MainActor
private final class ReviewRefreshVM: CYPaginatedListViewModel<ReviewRow> {
    var responses: [CheckedContinuation<[ReviewRow], Error>] = []
    override func fetchPage(page: Int, pageSize: Int) async throws -> [ReviewRow] {
        try await withCheckedThrowingContinuation { responses.append($0) }
    }
}

final class TemplateReviewCoreRegressionTests: XCTestCase {
    func testCacheKeysRemainDistinct() async {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }
        _ = await cache.save(value: "first", forKey: "a/b")
        _ = await cache.save(value: "second", forKey: "a_b")
        let value: String? = await cache.load(forKey: "a/b")
        XCTAssertEqual(value, "first")
    }

    @MainActor
    func testRegisteredBuiltInPermissionIsPreserved() async {
        let manager = CYPermissionManager()
        manager.register(.location, requester: ReviewPermission())
        let value = await manager.status(of: .location)
        XCTAssertEqual(value, .restricted)
    }

    @MainActor
    func testRefreshDiscardsPreviousLoadMoreResponse() async {
        let vm = ReviewPageVM(pageSize: 1)
        vm.items = [ReviewRow(id: 1)]
        let loadMore = Task { await vm.loadMore() }
        while vm.pageTwo == nil { await Task.yield() }
        await vm.refresh()
        vm.pageTwo?.resume(returning: [ReviewRow(id: 2)])
        await loadMore.value
        XCTAssertEqual(vm.items.map(\.id), [100])
        XCTAssertEqual(vm.currentPage, 1)
    }

    func testCancelledTaskDoesNotRemoveReplacement() async throws {
        let deduplicator = CYRequestDeduplicator()
        let oldGate = ReviewGate()
        let newGate = ReviewGate()
        let old = Task { try await deduplicator.execute(key: "same") { await oldGate.wait() } }
        while !(await oldGate.isWaiting) { await Task.yield() }
        await deduplicator.cancel(key: "same")
        let replacement = Task { try await deduplicator.execute(key: "same") { await newGate.wait() } }
        while !(await newGate.isWaiting) { await Task.yield() }
        await oldGate.release(1)
        _ = try await old.value
        let next = Task { try await deduplicator.execute(key: "same") { 3 } }
        for _ in 0..<100 { await Task.yield() }
        await newGate.release(2)
        let replacementValue = try await replacement.value
        let nextValue = try await next.value
        XCTAssertEqual(nextValue, replacementValue)
    }

    func testQueryKeysDoNotCollide() {
        let first = ReviewEndpoint(queryItems: [URLQueryItem(name: "a", value: "1&b=2")])
        let second = ReviewEndpoint(queryItems: [URLQueryItem(name: "a", value: "1"), URLQueryItem(name: "b", value: "2")])
        XCTAssertNotEqual(first.deduplicationKey, second.deduplicationKey)
    }

    func testQueryNullEmptyAndHeadersStayDistinct() {
        let nilValue = ReviewEndpoint(queryItems: [URLQueryItem(name: "a", value: nil)])
        let empty = ReviewEndpoint(queryItems: [URLQueryItem(name: "a", value: "")])
        XCTAssertNotEqual(nilValue.deduplicationKey, empty.deduplicationKey)
        let english = ReviewEndpoint(queryItems: nil, headers: ["Accept-Language": "en"])
        let chinese = ReviewEndpoint(queryItems: nil, headers: ["Accept-Language": "zh-Hans"])
        XCTAssertNotEqual(english.deduplicationKey, chinese.deduplicationKey)
    }

    func testCacheNamespacesAndEmptyNamespacePersistCorrectly() async {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }
        let rootSave = await cache.save(value: "root", forKey: "same", namespace: "")
        let nestedSave = await cache.save(value: "nested", forKey: "same", namespace: "../outside")
        XCTAssertNoThrow(try rootSave.get())
        XCTAssertNoThrow(try nestedSave.get())
        let fresh = CYCacheManager(directoryName: "cache", baseDirectory: base)
        let root: String? = await fresh.load(forKey: "same")
        let nested: String? = await fresh.load(forKey: "same", namespace: "../outside")
        XCTAssertEqual(root, "root")
        XCTAssertEqual(nested, "nested")
        _ = await fresh.clear(namespace: "../outside")
        let after: String? = await fresh.load(forKey: "same", namespace: "../outside")
        let retainedRoot: String? = await fresh.load(forKey: "same", namespace: "")
        XCTAssertNil(after)
        XCTAssertEqual(retainedRoot, "root")
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.appendingPathComponent("outside").path))
    }

    @MainActor
    func testRefreshFailurePreservesPaginationMetadata() async {
        let vm = ReviewPageVM(pageSize: 1)
        vm.items = [ReviewRow(id: 4)]
        vm.hasMore = false
        vm.currentPage = 4
        vm.failsRefresh = true
        await vm.refresh()
        XCTAssertEqual(vm.items.map(\.id), [4])
        XCTAssertFalse(vm.hasMore)
        XCTAssertEqual(vm.currentPage, 4)
        XCTAssertNotNil(vm.error)
    }

    @MainActor
    func testCancelledLoadMoreDoesNotDisplayErrorOrAppendResults() async {
        let vm = ReviewPageVM(pageSize: 1)
        vm.items = [ReviewRow(id: 1)]
        let task = Task { await vm.loadMore() }
        while vm.pageTwo == nil { await Task.yield() }
        task.cancel()
        vm.pageTwo?.resume(returning: [ReviewRow(id: 2)])
        await task.value
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertEqual(vm.items.map(\.id), [1])
    }

    @MainActor
    func testLateRefreshFailureCannotOverwriteLatestSuccess() async {
        let vm = ReviewRefreshVM(pageSize: 1)
        let first = Task { await vm.refresh() }
        while vm.responses.count < 1 { await Task.yield() }
        let next = Task { await vm.refresh() }
        while vm.responses.count < 2 { await Task.yield() }
        vm.responses[1].resume(returning: [ReviewRow(id: 100)])
        await next.value
        vm.responses[0].resume(throwing: CYNetworkError.noConnection)
        await first.value
        XCTAssertEqual(vm.items.map(\.id), [100])
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }
}
