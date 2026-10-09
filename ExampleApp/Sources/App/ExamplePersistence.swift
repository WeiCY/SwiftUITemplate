import Foundation
import CYAppPersistence

// MARK: - 宿主持久化入口
//
// 模板只提供 `CYPersistenceController` 基础设施，Schema 由宿主决定。

enum ExamplePersistence {
    static let controller = CYPersistenceController(
        for: [BookmarkItem.self, BookmarkTag.self]
    )
}
