import SwiftUI
import SwiftData
import CYAppCore
import CYAppPersistence

@Model public final class Note {
    public var title: String
    public init(title: String) { self.title = title }
}

public struct OfflinePage: View {
    @Environment(\.modelContext) private var context
    @Query private var notes: [Note]
    @State private var editing: Note?
    @State private var error: String?
    public init() {}
    public var body: some View {
        List {
            Button("Add sample note") {
                let note = Note(title: "Original")
                context.insert(note)
                do { try context.save(); error = nil } catch {
                    context.delete(note)
                    self.error = error.localizedDescription
                }
            }.accessibilityIdentifier("offline.add")
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(notes) { note in
                Button(note.title) { editing = note }
            }
        }
        .navigationTitle("Local editing")
        .sheet(item: $editing) { note in NoteEditor(note: note) }
    }
}

/// Native Form + a draft: Cancel never mutates the stored model.
private struct NoteEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let note: Note
    @State private var draft: String
    @State private var error: String?

    init(note: Note) {
        self.note = note
        _draft = State(initialValue: note.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $draft).accessibilityIdentifier("offline.draft")
                if let error { Text(error).foregroundStyle(.red) }
                Button("Save") { save() }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("offline.save")
            }
            .navigationTitle("Edit draft")
            .toolbar { Button("Cancel") { dismiss() }.accessibilityIdentifier("offline.cancel") }
        }
    }

    private func save() {
        let previous = note.title
        note.title = draft
        do { try context.save(); dismiss() } catch {
            note.title = previous
            self.error = error.localizedDescription
        }
    }
}

@MainActor
public enum OfflineConsumer {
    public static func check() throws -> Bool {
        let store = try CYPersistenceController.create(for: [Note.self], inMemory: true)
        let context = store.container.mainContext
        let note = Note(title: "Original")
        context.insert(note)
        try context.save()
        note.title = "Updated"
        try context.save()
        guard try context.fetch(FetchDescriptor<Note>()).first?.title == "Updated" else { return false }
        context.delete(note)
        try context.save()
        guard try context.fetchCount(FetchDescriptor<Note>()) == 0 else { return false }
        let expected = NSError(domain: "FixtureStore", code: 77)
        do {
            _ = try CYPersistenceController.create(for: [Note.self], containerBuilder: { _, _ in throw expected })
            return false
        } catch { return error as NSError == expected }
    }
}
