import Foundation
import SwiftData
import CYAppCore

// MARK: - 组合根
//
// 集中创建 Service / Repository / ViewModel，并把依赖显式注入。
// Feature 只接收已构造好的依赖，不自寻依赖、不引用 Legacy Facade。
// 真实项目可在此按需增减 Service（订阅、AI、定位等）。

@MainActor
final class AppDependencies {
    let homeViewModel: HomeViewModel
    let bookmarkViewModel: BookmarkViewModel

    init(networkClient: any CYNetworkClientProtocol, modelContext: ModelContext) {
        let articleService = ArticleService(client: networkClient)
        let bookmarkRepository = BookmarkRepository(context: modelContext)

        self.homeViewModel = HomeViewModel(
            service: articleService,
            repository: bookmarkRepository
        )
        self.bookmarkViewModel = BookmarkViewModel(repository: bookmarkRepository)
    }
}
