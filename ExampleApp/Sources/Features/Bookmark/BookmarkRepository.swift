import Foundation
import SwiftData
import CYAppPersistence

// MARK: - Bookmark Repository
//
// 基于模板的 `CYRepositoryProtocol`，只操作宿主自己的 `BookmarkItem`。
// ViewModel 通过它读写收藏，不直接接触 ModelContext。

struct BookmarkRepository: CYRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch(predicate: Predicate<BookmarkItem>?) throws -> [BookmarkItem] {
        try context.fetch(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
    }

    func fetch(predicate: Predicate<BookmarkItem>?, offset: Int, limit: Int) throws -> [BookmarkItem] {
        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func count(predicate: Predicate<BookmarkItem>?) throws -> Int {
        try context.fetchCount(FetchDescriptor(predicate: predicate))
    }

    func insert(_ entity: BookmarkItem) throws {
        context.insert(entity)
        try save()
    }

    func delete(_ entity: BookmarkItem) throws {
        context.delete(entity)
        try save()
    }

    func save() throws {
        try context.save()
    }

    // MARK: - 业务便捷方法

    func find(sourceID: Int) throws -> BookmarkItem? {
        try fetch(predicate: #Predicate { $0.sourceID == sourceID }).first
    }

    func isBookmarked(sourceID: Int) throws -> Bool {
        try count(predicate: #Predicate { $0.sourceID == sourceID }) > 0
    }

    func allSourceIDs() throws -> Set<Int> {
        Set(try fetch(predicate: nil).map(\.sourceID))
    }
}
