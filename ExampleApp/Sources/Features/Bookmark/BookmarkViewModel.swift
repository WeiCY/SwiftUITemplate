import Foundation
import Observation
import CYAppCore

// MARK: - Bookmark ViewModel
//
// 全部数据来自 SwiftData Repository，演示 Persistence 的读 / 删流程。

@MainActor
@Observable
final class BookmarkViewModel: CYBaseViewModel {
    private let repository: BookmarkRepository
    private let toast: any CYToastManagerProtocol

    var bookmarks: [BookmarkItem] = []

    init(repository: BookmarkRepository, toast: any CYToastManagerProtocol) {
        self.repository = repository
        self.toast = toast
        super.init()
    }

    func load() async {
        await executeTask { [weak self] in
            guard let self else { return }
            self.bookmarks = try self.repository.fetch(predicate: nil)
        }
    }

    func delete(_ item: BookmarkItem) {
        delete([item])
    }

    func delete(at offsets: IndexSet) {
        // 取原数组快照，避免每次删除后刷新数组导致后续索引失效。
        delete(offsets.compactMap { bookmarks.indices.contains($0) ? bookmarks[$0] : nil })
    }

    private func delete(_ items: [BookmarkItem]) {
        guard !items.isEmpty else { return }
        do {
            try repository.delete(items)
            bookmarks = try repository.fetch(predicate: nil)
            toast.show("bookmark_deleted".exampleLocalized, type: .info)
        } catch {
            toast.show("bookmark_delete_failed".exampleLocalized, type: .error)
        }
    }
}
