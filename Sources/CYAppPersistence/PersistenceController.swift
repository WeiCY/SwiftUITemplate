import Foundation
import SwiftData

/// SwiftData 基础设施。模型、版本和迁移计划由宿主拥有。
/// 新代码使用 `try CYPersistenceController.create(...)`，由宿主展示错误及重试。
public struct CYPersistenceController: @unchecked Sendable {
    public let container: ModelContainer

    private init(container: ModelContainer) { self.container = container }

    /// 可恢复的创建入口；builder 的原始错误原样抛出，不删除数据库或回退内存。
    public static func create(
        for modelTypes: [any PersistentModel.Type],
        inMemory: Bool = false,
        containerBuilder: ((_ schema: Schema, _ inMemory: Bool) throws -> ModelContainer)? = nil
    ) throws -> Self {
        guard !modelTypes.isEmpty else { throw ConfigurationError.emptySchema }
        let schema = Schema(modelTypes)
        if let containerBuilder { return Self(container: try containerBuilder(schema, inMemory)) }
        return try create(schema: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)])
    }

    /// 版本化 Schema 示例：Schema(versionedSchema: HostSchemaV2.self)。
    public static func create(
        schema: Schema,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
        configurations: [ModelConfiguration] = []
    ) throws -> Self {
        Self(container: try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: configurations))
    }

    /// 兼容入口：失败仍会终止进程。迁移为 `try .create(...)` 并捕获错误。
    @available(*, deprecated, message: "Fail-fast initializer. Use try CYPersistenceController.create(for:inMemory:containerBuilder:).")
    public init(
        for modelTypes: [any PersistentModel.Type],
        inMemory: Bool = false,
        containerBuilder: ((_ schema: Schema, _ inMemory: Bool) throws -> ModelContainer)? = nil
    ) {
        do { self = try Self.create(for: modelTypes, inMemory: inMemory, containerBuilder: containerBuilder) } catch { fatalError("Failed to create ModelContainer: \(error)") }
    }

    public enum ConfigurationError: Error { case emptySchema }

    /// 历史标记，并非迁移机制。请在宿主声明 VersionedSchema / SchemaMigrationPlan。
    @available(*, deprecated, message: "Define VersionedSchema and SchemaMigrationPlan in the host.")
    public static let currentSchemaVersion = 1
}
