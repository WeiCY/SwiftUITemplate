import Foundation
import SwiftData
import CYAppPersistence

// ExampleApp-owned business models. They are examples, not template foundation types.
@Model
final class BookmarkItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String
    var note: String?
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \BookmarkTag.bookmarks)
    var tags: [BookmarkTag] = []

    init(id: UUID = UUID(), title: String, url: String, note: String? = nil, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.url = url
        self.note = note
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func addTag(_ tag: BookmarkTag) {
        guard !tags.contains(where: { $0.id == tag.id }) else { return }
        tags.append(tag)
        updatedAt = Date()
    }
}

@Model
final class BookmarkTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String?
    var bookmarks: [BookmarkItem] = []

    init(id: UUID = UUID(), name: String, color: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
    }
}

struct BookmarkRepository: CYRepositoryProtocol {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func fetch(predicate: Predicate<BookmarkItem>?) throws -> [BookmarkItem] {
        try context.fetch(FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    func fetch(predicate: Predicate<BookmarkItem>?, offset: Int, limit: Int) throws -> [BookmarkItem] {
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\BookmarkItem.createdAt, order: .reverse)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func count(predicate: Predicate<BookmarkItem>?) throws -> Int {
        try context.fetchCount(FetchDescriptor(predicate: predicate))
    }

    func insert(_ entity: BookmarkItem) throws { context.insert(entity); try save() }
    func delete(_ entity: BookmarkItem) throws { context.delete(entity); try save() }
    func save() throws { try context.save() }
}

enum ExamplePersistence {
    static let controller = CYPersistenceController(for: [BookmarkItem.self, BookmarkTag.self])
}
