import SwiftData
import XCTest
@testable import CYAppPersistence

@MainActor
final class PersistenceTests: XCTestCase {
    func testBookmarkRepositoryCRUDAndQueries() throws {
        let controller = CYPersistenceController(inMemory: true)
        let repository = CYBookmarkRepository(context: controller.container.mainContext)
        let tagRepository = CYTagRepository(context: controller.container.mainContext)
        let tag = CYTag(name: "Swift")
        let bookmark = CYBookmarkItem(title: "Swift.org", url: "https://swift.org", isFavorite: true)
        bookmark.addTag(tag)

        try tagRepository.insert(tag)
        try repository.insert(bookmark)

        XCTAssertEqual(try repository.count(predicate: nil), 1)
        XCTAssertEqual(try repository.fetchFavorites().map(\.title), ["Swift.org"])
        XCTAssertEqual(try repository.search(byTitle: "Swift").count, 1)
        XCTAssertEqual(try repository.fetch(byTag: "Swift").count, 1)

        try repository.delete(bookmark)
        XCTAssertEqual(try repository.count(predicate: nil), 0)
    }
}
