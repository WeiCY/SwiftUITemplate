import XCTest
import SwiftData
import CYAppPersistence
import CYAppCore
@testable import ExampleApp

@MainActor
final class BookmarkRegressionTests: XCTestCase {
    private func makeViewModel(count: Int) throws -> (BookmarkViewModel, CYPersistenceController) {
        let controller = CYPersistenceController(for: [BookmarkItem.self, BookmarkTag.self], inMemory: true)
        let repository = BookmarkRepository(context: controller.container.mainContext)
        for index in 0..<count {
            let item = BookmarkItem(sourceID: index, title: "Bookmark \(index)", url: "https://example.test/\(index)")
            item.createdAt = Date(timeIntervalSince1970: Double(index))
            try repository.insert(item)
        }
        return (BookmarkViewModel(repository: repository), controller)
    }

    func testMultipleOffsetsDeleteOriginalItems() async throws {
        let (vm, controller) = try makeViewModel(count: 3)
        await vm.load()
        let expectedRemaining = vm.bookmarks[2].id
        vm.delete(at: IndexSet([0, 1]))
        XCTAssertEqual(vm.bookmarks.map(\.id), [expectedRemaining])
        XCTAssertEqual(try controller.container.mainContext.fetchCount(FetchDescriptor<BookmarkItem>()), 1)
    }

    func testDeletingAllOffsetsDoesNotReadMutatedArray() async throws {
        let (vm, controller) = try makeViewModel(count: 2)
        await vm.load()
        vm.delete(at: IndexSet([0, 1]))
        XCTAssertTrue(vm.bookmarks.isEmpty)
        XCTAssertEqual(try controller.container.mainContext.fetchCount(FetchDescriptor<BookmarkItem>()), 0)
    }
}
