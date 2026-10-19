import XCTest
@testable import CYAppCore

private struct PageRow: Identifiable, Sendable { let id: Int }

@MainActor
private final class RecoveryPages: CYPaginatedListViewModel<PageRow> {
    var requests: [Int] = []
    var failPage: Int?
    var cancellation = false
    override func fetchPage(page: Int, pageSize: Int) async throws -> [PageRow] {
        requests.append(page)
        if cancellation { throw CancellationError() }
        if failPage == page { throw CYNetworkError.noConnection }
        return [PageRow(id: page)]
    }
}

@MainActor
final class PaginationRecoveryTests: XCTestCase {
    func testInitialFailureRetriesFirstPage() async {
        let vm = RecoveryPages(pageSize: 1)
        vm.failPage = 1
        await vm.load()
        XCTAssertFalse(vm.isEmpty)
        XCTAssertEqual(vm.failure, .refresh)
        vm.failPage = nil
        await vm.retry()
        XCTAssertEqual(vm.requests, [1, 1])
        XCTAssertEqual(vm.items.map(\.id), [1])
        XCTAssertNil(vm.error)
    }

    func testAppendFailureRequiresExplicitRetryAndDoesNotSkipOrDuplicate() async {
        let vm = RecoveryPages(pageSize: 1)
        await vm.load()
        vm.failPage = 2
        await vm.loadMore()
        await vm.loadMore()
        XCTAssertEqual(vm.requests, [1, 2])
        XCTAssertEqual(vm.currentPage, 1)
        XCTAssertEqual(vm.failure, .append(page: 2))
        vm.failPage = nil
        await vm.retry()
        XCTAssertEqual(vm.requests, [1, 2, 2])
        XCTAssertEqual(vm.items.map(\.id), [1, 2])
        XCTAssertEqual(vm.currentPage, 2)
        await vm.retry()
        XCTAssertEqual(vm.requests, [1, 2, 2])
    }

    func testCancellationDoesNotBecomeFailure() async {
        let vm = RecoveryPages(pageSize: 1)
        await vm.load()
        vm.cancellation = true
        await vm.loadMore()
        XCTAssertNil(vm.failure)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoadingMore)
        await vm.refresh()
        XCTAssertNil(vm.error)
        XCTAssertEqual(vm.items.map(\.id), [1])
    }
}
