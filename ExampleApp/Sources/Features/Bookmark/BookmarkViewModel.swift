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

    var bookmarks: [BookmarkItem] = []

    init(repository: BookmarkRepository) {
        self.repository = repository
        super.init()
    }

    func load() async {
        await executeTask { [weak self] in
            guard let self else { return }
            self.bookmarks = try self.repository.fetch(predicate: nil)
        }
    }

    func delete(_ item: BookmarkItem) {
        do {
            try repository.delete(item)
            bookmarks = try repository.fetch(predicate: nil)
            CYToastManager.shared.show("已删除", type: .info)
        } catch {
            CYToastManager.shared.show("删除失败", type: .error)
        }
    }
}
