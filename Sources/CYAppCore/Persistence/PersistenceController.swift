import Foundation
import SwiftData

// MARK: - SwiftData 持久化控制器
//
// 配置 ModelContainer，支持磁盘和内存两种模式。
//
// ## App 入口集成
// ```swift
// @main
// struct MyApp: App {
//     var body: some Scene {
//         WindowGroup {
//             RootView()
//         }
//         .modelContainer(CYPersistenceController.shared.container)
//     }
// }
// ```
//
// ## SwiftUI View 中使用
// ```swift
// struct BookmarkListView: View {
//     @Environment(\.modelContext) private var context
//
//     var body: some View {
//         // 通过 context 创建 Repository
//         let repo = CYBookmarkRepository(context: context)
//         // ...
//     }
// }
// ```
//
// ## Preview 中使用
// ```swift
// #Preview {
//     BookmarkListView()
//         .modelContainer(CYPersistenceController.preview.container)
// }
// ```

public struct CYPersistenceController {
    
    /// 生产环境实例（磁盘持久化）
    public static let shared = CYPersistenceController()
    
    /// Preview / 测试用内存实例
    @MainActor
    public static let preview: CYPersistenceController = {
        let controller = CYPersistenceController(inMemory: true)
        let context = controller.container.mainContext
        
        // 插入示例标签
        let techTag = CYTag(name: "科技", color: "#3498DB")
        let newsTag = CYTag(name: "资讯", color: "#E74C3C")
        context.insert(techTag)
        context.insert(newsTag)
        
        // 插入示例书签
        let samples = [
            CYBookmarkItem(title: "Apple Developer", url: "https://developer.apple.com", note: "苹果开发者官网"),
            CYBookmarkItem(title: "SwiftUI Tutorials", url: "https://developer.apple.com/tutorials/swiftui", isFavorite: true),
            CYBookmarkItem(title: "Swift.org", url: "https://swift.org", note: "Swift 语言官网"),
        ]
        
        for sample in samples {
            sample.addTag(techTag)
            context.insert(sample)
        }
        
        try? context.save()
        return controller
    }()
    
    public let container: ModelContainer
    
    /// 创建持久化控制器
    /// - Parameter inMemory: true 为内存模式（Preview/测试），false 为磁盘模式（生产）
    public init(inMemory: Bool = false) {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            container = try ModelContainer(
                for: CYBookmarkItem.self, CYTag.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - 数据迁移（Schema V1）
    
    /// 当前 Schema 版本
    ///
    /// 数据模型变更时，增加版本号并添加迁移计划：
    /// ```swift
    /// static let schemaV1toV2 = VersionedSchema([...])
    /// static let migrationPlan = SchemaMigrationPlan(...)
    /// ```
    public static let currentSchemaVersion = 1
}
