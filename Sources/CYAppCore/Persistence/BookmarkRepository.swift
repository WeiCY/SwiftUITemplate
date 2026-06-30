import Foundation
import SwiftData

// MARK: - 书签 Repository 实现
//
// 演示 SwiftData + CYRepositoryProtocol 的标准用法，包含：
// - 基础 CRUD
// - 分页查询
// - 按标题/标签搜索
// - 收藏筛选
//
// ## 在 ViewModel 中使用
// ```swift
// @Observable
// final class BookmarkViewModel: CYBaseViewModel {
//     var items: [CYBookmarkItem] = []
//     private let repository: CYBookmarkRepository
//
//     init(context: ModelContext) {
//         self.repository = CYBookmarkRepository(context: context)
//     }
//
//     func load() async {
//         await executeTask {
//             items = try repository.fetch(predicate: nil)
//         }
//     }
//
//     func addBookmark(title: String, url: String) async {
//         await executeTask {
//             try repository.insert(CYBookmarkItem(title: title, url: url))
//         }
//     }
// }
// ```

public struct CYBookmarkRepository: CYRepositoryProtocol {
    public typealias Entity = CYBookmarkItem
    
    private let context: ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - CYRepositoryProtocol 实现
    
    public func fetch(predicate: Predicate<CYBookmarkItem>?) throws -> [CYBookmarkItem] {
        let descriptor = FetchDescriptor<CYBookmarkItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    public func fetch(predicate: Predicate<CYBookmarkItem>?, offset: Int, limit: Int) throws -> [CYBookmarkItem] {
        var descriptor = FetchDescriptor<CYBookmarkItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    public func count(predicate: Predicate<CYBookmarkItem>?) throws -> Int {
        let descriptor = FetchDescriptor<CYBookmarkItem>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }
    
    public func insert(_ entity: CYBookmarkItem) throws {
        context.insert(entity)
        try save()
    }
    
    public func delete(_ entity: CYBookmarkItem) throws {
        context.delete(entity)
        try save()
    }
    
    public func save() throws {
        try context.save()
    }
    
    // MARK: - 便捷查询
    
    /// 按标题搜索书签
    public func search(byTitle title: String) throws -> [CYBookmarkItem] {
        let predicate = #Predicate<CYBookmarkItem> { $0.title.contains(title) }
        return try fetch(predicate: predicate)
    }
    
    /// 查询收藏的书签
    public func fetchFavorites() throws -> [CYBookmarkItem] {
        let predicate = #Predicate<CYBookmarkItem> { $0.isFavorite == true }
        return try fetch(predicate: predicate)
    }
    
    /// 按标签名查询书签
    public func fetch(byTag tagName: String) throws -> [CYBookmarkItem] {
        let predicate = #Predicate<CYBookmarkItem> { item in
            item.tags.contains { $0.name == tagName }
        }
        return try fetch(predicate: predicate)
    }
    
    /// 查询指定时间范围内的书签
    public func fetch(from startDate: Date, to endDate: Date) throws -> [CYBookmarkItem] {
        let predicate = #Predicate<CYBookmarkItem> { item in
            item.createdAt >= startDate && item.createdAt <= endDate
        }
        return try fetch(predicate: predicate)
    }
}

// MARK: - 标签 Repository

/// 标签 Repository 实现
public struct CYTagRepository: CYRepositoryProtocol {
    public typealias Entity = CYTag
    
    private let context: ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    public func fetch(predicate: Predicate<CYTag>?) throws -> [CYTag] {
        let descriptor = FetchDescriptor<CYTag>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    public func fetch(predicate: Predicate<CYTag>?, offset: Int, limit: Int) throws -> [CYTag] {
        var descriptor = FetchDescriptor<CYTag>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    public func count(predicate: Predicate<CYTag>?) throws -> Int {
        let descriptor = FetchDescriptor<CYTag>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }
    
    public func insert(_ entity: CYTag) throws {
        context.insert(entity)
        try save()
    }
    
    public func delete(_ entity: CYTag) throws {
        context.delete(entity)
        try save()
    }
    
    public func save() throws {
        try context.save()
    }
    
    /// 按名称查找标签
    public func find(byName name: String) throws -> CYTag? {
        let predicate = #Predicate<CYTag> { $0.name == name }
        return try fetch(predicate: predicate).first
    }
}
