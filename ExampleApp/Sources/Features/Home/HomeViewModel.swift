import Foundation
import Observation
import CYAppCore

// MARK: - Home ViewModel
//
// 演示一个真实 Feature 的 ViewModel 结构：
// - 依赖 Service（网络）+ Repository（持久化）
// - 用 CYBaseViewModel.executeTask 自动管理 loading / error / retry
// - 收藏操作直接写入持久化，并同步 UI 状态

@MainActor
@Observable
final class HomeViewModel: CYBaseViewModel {
    private let service: any ArticleServiceProtocol
    private let repository: BookmarkRepository

    var articles: [Article] = []
    private var bookmarkedSourceIDs: Set<Int> = []

    init(service: any ArticleServiceProtocol, repository: BookmarkRepository) {
        self.service = service
        self.repository = repository
        super.init()
    }

    /// 演示用失败开关，透传给 Service，用于展示 error / retry。
    var simulateFailure: Bool {
        get { service.simulateFailure }
        set { service.simulateFailure = newValue }
    }

    // MARK: - 加载

    func load() async {
        await executeTask { [weak self] in
            guard let self else { return }
            let fetched = try await self.service.fetchArticles()
            self.articles = fetched
            self.bookmarkedSourceIDs = try self.repository.allSourceIDs()
        }
    }

    // MARK: - 收藏

    func isBookmarked(_ article: Article) -> Bool {
        bookmarkedSourceIDs.contains(article.id)
    }

    func toggleBookmark(_ article: Article) {
        do {
            if let existing = try repository.find(sourceID: article.id) {
                try repository.delete(existing)
                CYToastManager.shared.show("已取消收藏", type: .info)
            } else {
                try repository.insert(.from(article))
                CYToastManager.shared.show("已收藏", type: .success)
            }
            bookmarkedSourceIDs = try repository.allSourceIDs()
        } catch {
            CYToastManager.shared.show("收藏操作失败", type: .error)
        }
    }
}
