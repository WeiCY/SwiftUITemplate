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
        .navigationTitle("bookmarks_title".exampleLocalized)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.bookmarks.isEmpty && !viewModel.isLoading {
            CYEmptyStateView(
                systemImage: "bookmark",
                title: "bookmarks_empty_title".exampleLocalized,
                message: "bookmarks_empty_message".exampleLocalized
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
                    viewModel.delete(at: indexSet)
                }
            }
            .listStyle(.plain)
        }
    }
}
