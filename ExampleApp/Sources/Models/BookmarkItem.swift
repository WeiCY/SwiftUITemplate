import Foundation
import SwiftData

// MARK: - 业务模型（持久化域）
//
// ExampleApp 自有的 SwiftData 模型，示例“模板只提供 Persistence 基础设施，
// 具体模型由宿主定义”。BookmarkItem 与网络域 Article 通过 sourceID 关联。

@Model
final class BookmarkItem {
    @Attribute(.unique) var id: UUID
    /// 关联的 Article.id，用于判断某篇文章是否已收藏。
    var sourceID: Int
    var title: String
    var url: String
    var note: String?
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \BookmarkTag.bookmarks)
    var tags: [BookmarkTag] = []

    init(
        id: UUID = UUID(),
        sourceID: Int = 0,
        title: String,
        url: String,
        note: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.url = url
        self.note = note
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 从网络域 Article 创建收藏项。
    static func from(_ article: Article) -> BookmarkItem {
        BookmarkItem(
            sourceID: article.id,
            title: article.title,
            url: article.url
        )
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
