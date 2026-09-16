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
// struct ItemListView: View {
//     @Environment(\.modelContext) private var context
//
//     var body: some View {
//         // 使用宿主 App 自己的 Model 和 Repository
//     }
// }
// ```
//
// ## Preview 中使用
// ```swift
// #Preview {
//     ItemListView()
//         .modelContainer(previewController.container)
// }
// ```

public struct CYPersistenceController: @unchecked Sendable {
    public let container: ModelContainer
    
    /// 创建持久化控制器
    /// - Parameters:
    ///   - modelTypes: 宿主 App 拥有的 SwiftData 模型类型。
    ///   - inMemory: true 为内存模式（Preview/测试），false 为磁盘模式（生产）。
    public init(
        for modelTypes: [any PersistentModel.Type],
        inMemory: Bool = false,
        containerBuilder: ((_ schema: Schema, _ inMemory: Bool) throws -> ModelContainer)? = nil
    ) {
        precondition(!modelTypes.isEmpty, "CYPersistenceController requires at least one model type")
        let schema = Schema(modelTypes)
        do {
            if let containerBuilder {
                container = try containerBuilder(schema, inMemory)
            } else {
                let configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: inMemory
                )
                container = try ModelContainer(for: schema, configurations: [configuration])
            }
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
