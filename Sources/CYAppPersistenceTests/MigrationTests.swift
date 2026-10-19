import SwiftData
import XCTest
@testable import CYAppPersistence

// A real, disk-backed lightweight migration. Models deliberately belong to the host/test.
enum NotesV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Note.self] }
    @Model final class Note {
        var title: String
        init(title: String) { self.title = title }
    }
}

enum NotesV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Note.self] }
    @Model final class Note {
        var title: String
        var details: String?
        init(title: String, details: String? = nil) { self.title = title; self.details = details }
    }
}

enum NotesMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NotesV1.self, NotesV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: NotesV1.self, toVersion: NotesV2.self)] }
}

@MainActor
final class MigrationTests: XCTestCase {
    func testOriginalInitializationErrorIsCatchable() {
        let expected = NSError(domain: "InjectedStoreFailure", code: 42)
        XCTAssertThrowsError(try CYPersistenceController.create(for: [NotesV1.Note.self], containerBuilder: { _, _ in
            throw expected
        })) { XCTAssertEqual($0 as NSError, expected) }
    }

    func testVersionOneDataSurvivesVersionTwoMigration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.store")
        try writeV1(url: url)
        let schema = Schema(versionedSchema: NotesV2.self)
        let controller = try CYPersistenceController.create(
            schema: schema, migrationPlan: NotesMigration.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let notes = try controller.container.mainContext.fetch(FetchDescriptor<NotesV2.Note>())
        XCTAssertEqual(notes.map(\.title), ["Keep this data"])
        XCTAssertNil(notes.first?.details)
    }

    private func writeV1(url: URL) throws {
        let schema = Schema(versionedSchema: NotesV1.self)
        let controller = try CYPersistenceController.create(schema: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        controller.container.mainContext.insert(NotesV1.Note(title: "Keep this data"))
        try controller.container.mainContext.save()
    }
}
