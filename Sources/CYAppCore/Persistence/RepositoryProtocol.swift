import Foundation
import SwiftData

// MARK: - 通用 Repository 协议
//
// 提供标准的 CRUD 操作接口，支持分页和排序。
// 子类实现具体的持久化逻辑。
//
// ## 基本用法
// ```swift
// struct CYBookmarkRepository: CYRepositoryProtocol {
//     typealias Entity = CYBookmarkItem
//     let context: ModelContext
//
//     func fetch(predicate: Predicate<CYBookmarkItem>?) throws -> [CYBookmarkItem] {
//         try context.fetch(FetchDescriptor(predicate: predicate))
//     }
// }
// ```
//
// ## ViewModel 中使用
// ```swift
// @Observable
// final class BookmarkViewModel: CYBaseViewModel {
//     var items: [CYBookmarkItem] = []
//     private let repo: CYBookmarkRepository
//
//     func load() async {
//         await executeTask {
//             items = try repo.fetch(predicate: nil)
//         }
//     }
// }
// ```

/// 通用 Repository 协议
public protocol CYRepositoryProtocol {
    associatedtype Entity: PersistentModel
    
    /// 查询数据
    /// - Parameter predicate: 过滤条件，nil 返回全部
    /// - Returns: 匹配的数据列表
    func fetch(predicate: Predicate<Entity>?) throws -> [Entity]
    
    /// 分页查询
    /// - Parameters:
    ///   - predicate: 过滤条件
    ///   - offset: 起始偏移
    ///   - limit: 每页数量
    /// - Returns: 分页后的数据列表
    func fetch(predicate: Predicate<Entity>?, offset: Int, limit: Int) throws -> [Entity]
    
    /// 查询总数
    /// - Parameter predicate: 过滤条件
    /// - Returns: 匹配的记录数
    func count(predicate: Predicate<Entity>?) throws -> Int
    
    /// 插入数据
    func insert(_ entity: Entity) throws
    
    /// 批量插入
    func insert(_ entities: [Entity]) throws
    
    /// 删除数据
    func delete(_ entity: Entity) throws
    
    /// 批量删除
    func delete(_ entities: [Entity]) throws
    
    /// 保存更改
    func save() throws
}

/// Repository 协议默认实现
public extension CYRepositoryProtocol {
    
    func fetch(predicate: Predicate<Entity>? = nil) throws -> [Entity] {
        return try fetch(predicate: predicate)
    }
    
    func insert(_ entities: [Entity]) throws {
        for entity in entities {
            try insert(entity)
        }
    }
    
    func delete(_ entities: [Entity]) throws {
        for entity in entities {
            try delete(entity)
        }
    }
}
