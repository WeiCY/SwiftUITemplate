import SwiftUI
import CYAppCore
import CYAppDesignSystem
import CYAppUI

// MARK: - Home Feature

struct HomeView: View {
    @Environment(CYAppRouter.self) private var router
    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        CYBaseView(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            loadingMessage: "加载中…",
            onRetry: { Task { await viewModel.retry() } }
        ) {
            content
        }
        .navigationTitle("文章")
        .toolbar { toolbar }
        .task {
            if viewModel.articles.isEmpty {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.articles.isEmpty && !viewModel.isLoading {
            CYEmptyStateView(
                systemImage: "doc.text",
                title: "暂无文章",
                message: "下拉或点击刷新重新加载",
                actionTitle: "重新加载",
                action: { Task { await viewModel.load() } }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: CYAppDimens.marginM) {
                    ForEach(viewModel.articles) { article in
                        articleRow(article)
                    }
                }
                .padding(CYAppDimens.marginM)
            }
        }
    }

    private func articleRow(_ article: Article) -> some View {
        CardView {
            HStack(alignment: .top, spacing: CYAppDimens.marginM) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(CYAppFont.h4)
                        .foregroundStyle(CYAppColor.textPrimary)

                    Text(article.summary)
                        .font(CYAppFont.bodySmall)
                        .foregroundStyle(CYAppColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button {
                    viewModel.toggleBookmark(article)
                } label: {
                    Image(systemName: viewModel.isBookmarked(article) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CYAppColor.primary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                router.navigate(to: AppRoute.articleDetail(article))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("重新加载", systemImage: "arrow.clockwise") {
                    Task { await viewModel.load() }
                }
                Toggle("模拟网络失败", isOn: $viewModel.simulateFailure)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - 路由目标

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        CYPageContainer(title: article.title, subtitle: "Article #\(article.id)") {
            VStack(alignment: .leading, spacing: CYAppDimens.marginM) {
                Text(article.summary)
                    .font(CYAppFont.bodyMedium)
                    .foregroundStyle(CYAppColor.textPrimary)

                Text(article.url)
                    .font(CYAppFont.bodySmall)
                    .foregroundStyle(CYAppColor.accent)
            }
        }
    }
}
