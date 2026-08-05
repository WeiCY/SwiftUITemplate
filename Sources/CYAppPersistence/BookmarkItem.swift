import Foundation
import SwiftData

// MARK: - 示例数据模型 — 书签
//
// 演示 SwiftData @Model 的标准用法，包含：
// - 唯一 ID
// - 可选字段
// - 与 Tag 的多对多关系
// - 索引
//
// ## 创建书签
// ```swift
// let bookmark = CYBookmarkItem(title: "Apple", url: "https://apple.com")
// bookmark.addTag(CYTag(name: "科技"))
// context.insert(bookmark)
// try context.save()
// ```
//
// ## 查询书签
// ```swift
// let descriptor = FetchDescriptor<CYBookmarkItem>(
//     predicate: #Predicate { $0.isFavorite == true },
//     sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
// )
// let favorites = try context.fetch(descriptor)
// ```

/// 书签数据模型
@Model
public final class CYBookmarkItem {
    /// 唯一标识
    @Attribute(.unique) public var id: UUID
    /// 标题
    public var title: String
    /// URL
    public var url: String
    /// 描述（可选）
    public var note: String?
    /// 是否收藏
    public var isFavorite: Bool
    /// 创建时间
    public var createdAt: Date
    /// 更新时间
    public var updatedAt: Date
    
    /// 关联的标签（多对多关系）
    @Relationship(deleteRule: .nullify, inverse: \CYTag.bookmarks)
    public var tags: [CYTag] = []
    
    public init(
        id: UUID = UUID(),
        title: String,
        url: String,
        note: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.note = note
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - 便捷方法
    
    /// 添加标签
    public func addTag(_ tag: CYTag) {
        if !tags.contains(where: { $0.id == tag.id }) {
            tags.append(tag)
            updatedAt = Date()
        }
    }
    
    /// 移除标签
    public func removeTag(_ tag: CYTag) {
        tags.removeAll { $0.id == tag.id }
        updatedAt = Date()
    }
    
    /// 切换收藏状态
    public func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = Date()
    }
}

// MARK: - 标签模型

/// 标签数据模型（与书签多对多关系）
///
/// 演示 SwiftData @Relationship 的用法：
/// - 反向关系
/// - 删除规则（nullify = 删标签不删书签）
@Model
public final class CYTag {
    /// 唯一标识
    @Attribute(.unique) public var id: UUID
    /// 标签名
    public var name: String
    /// 标签颜色（hex 值，如 "#FF5733"）
    public var color: String?
    
    /// 关联的书签
    public var bookmarks: [CYBookmarkItem] = []
    
    public init(id: UUID = UUID(), name: String, color: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
    }
}
