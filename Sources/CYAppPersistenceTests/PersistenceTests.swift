import SwiftData
import XCTest
@testable import CYAppPersistence

@Model
private final class TestItem {
    @Attribute(.unique) var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

private struct TestItemRepository: CYRepositoryProtocol {
    let context: ModelContext

    func fetch(predicate: Predicate<TestItem>?) throws -> [TestItem] {
        try context.fetch(FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.name)]))
    }

    func fetch(predicate: Predicate<TestItem>?, offset: Int, limit: Int) throws -> [TestItem] {
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\TestItem.name)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func count(predicate: Predicate<TestItem>?) throws -> Int {
        try context.fetchCount(FetchDescriptor(predicate: predicate))
    }

    func insert(_ entity: TestItem) throws { context.insert(entity); try save() }
    func delete(_ entity: TestItem) throws { context.delete(entity); try save() }
    func save() throws { try context.save() }
}

@MainActor
final class PersistenceTests: XCTestCase {
    func testHostModelsWorkWithPersistenceFoundation() throws {
        let controller = CYPersistenceController(for: [TestItem.self], inMemory: true)
        let repository = TestItemRepository(context: controller.container.mainContext)
        let item = TestItem(name: "Example")

        try repository.insert(item)
        XCTAssertEqual(try repository.count(predicate: nil), 1)
        XCTAssertEqual(try repository.fetch(predicate: nil).map(\.name), ["Example"])

        try repository.delete(item)
        XCTAssertEqual(try repository.count(predicate: nil), 0)
    }
}
