import SwiftUI
import CYAppCore
import CYAppDesignSystem
import CYAppUI

// MARK: - Bookmark Feature

struct BookmarkView: View {
    @State private var viewModel: BookmarkViewModel

    init(viewModel: BookmarkViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        CYBaseView(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            onRetry: { Task { await viewModel.retry() } }
        ) {
            content
        }
        .navigationTitle("收藏")
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.bookmarks.isEmpty && !viewModel.isLoading {
            CYEmptyStateView(
                systemImage: "bookmark",
                title: "还没有收藏",
                message: "在首页点击书签图标即可收藏文章"
            )
        } else {
            List {
                ForEach(viewModel.bookmarks) { item in
                    CYListRow(
                        title: item.title,
                        subtitle: item.url,
                        icon: "bookmark.fill",
                        showDisclosure: false
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.delete(viewModel.bookmarks[index])
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
