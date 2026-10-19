import SwiftUI
import CYAppCore

// MARK: - 分页列表 UI 组件
//
// 配合 CYPaginatedListViewModel 使用的通用列表 UI 组件。
// 内置下拉刷新、上拉加载更多指示器、空状态、错误状态。
//
// ## 基本用法
// ```swift
// struct ProductListView: View {
//     @State private var viewModel = ProductListViewModel()
//
//     var body: some View {
//         CYPaginatedListView(
//             viewModel: viewModel,
//             onRefresh: { await viewModel.refresh() },
//             onLoadMore: { await viewModel.loadMore() }
//         ) { item in
//             ProductRow(item: item)
//         }
//         .task { await viewModel.load() }
//     }
// }
// ```
//
// ## 自定义空状态和底部
// ```swift
// CYPaginatedListView(
//     viewModel: viewModel,
//     emptyView: { CustomEmptyView() },
//     onRefresh: { await viewModel.refresh() },
//     onLoadMore: { await viewModel.loadMore() }
// ) { item in
//     ProductRow(item: item)
// }
// ```

/// 分页列表 UI 组件
///
/// 自动处理：下拉刷新、上拉加载更多、空状态、加载中状态
///
/// - Note: 内部通过 `@Bindable` 持有 `@Observable` 的 ViewModel，
///   直接在 `body` 中读取其属性以确保观察订阅生效（不使用 `let` 快照，
///   否则数据更新后列表不会刷新）。
public struct CYPaginatedListView<Item: Identifiable & Sendable, Row: View, Empty: View>: View {

    @Bindable var viewModel: CYPaginatedListViewModel<Item>
    let emptyView: () -> Empty
    let loadingView: () -> AnyView
    let errorView: (CYAppError, @escaping () -> Void) -> AnyView
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    let rowContent: (Item) -> Row
    let preloadThreshold: Int

    public init(
        viewModel: CYPaginatedListViewModel<Item>,
        @ViewBuilder emptyView: @escaping () -> Empty,
        onRefresh: @escaping () async -> Void,
        onLoadMore: @escaping () async -> Void,
        preloadThreshold: Int = 3,
        loadingView: @escaping () -> AnyView = { AnyView(ProgressView()) },
        errorView: @escaping (CYAppError, @escaping () -> Void) -> AnyView = { error, retry in
            AnyView(VStack {
                Text(error.message)
                Button("action_retry".cyLocalized, action: retry)
                    .accessibilityIdentifier("pagination.retry")
            })
        },
        @ViewBuilder rowContent: @escaping (Item) -> Row
    ) {
        self._viewModel = Bindable(viewModel)
        self.emptyView = emptyView
        self.loadingView = loadingView
        self.errorView = errorView
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.rowContent = rowContent
        self.preloadThreshold = max(1, preloadThreshold)
    }
    
    public var body: some View {
        CYPaginatedListContent(
            state: CYPaginationState(
                items: viewModel.items, isLoading: viewModel.isLoading, isLoadingMore: viewModel.isLoadingMore,
                hasMore: viewModel.hasMore, errorMessage: viewModel.errorMessage,
                failure: viewModel.failure.map { failure in
                    switch failure {
                    case .refresh: return .refresh
                    case .append: return .append
                    }
                }
            ),
            emptyView: emptyView, onRefresh: onRefresh, onLoadMore: onLoadMore,
            onRetry: { await viewModel.retry() }, preloadThreshold: preloadThreshold,
            loadingView: loadingView,
            errorView: { message, retry in errorView(viewModel.error ?? .unknown(message), retry) },
            rowContent: rowContent
        )
    }
}

/// Presentation snapshot for host-owned state. Request ownership, page numbers and race isolation remain in the host.
public struct CYPaginationState<Item: Identifiable & Sendable>: Sendable {
    public enum Failure: Sendable { case refresh, append }
    public var items: [Item]
    public var isLoading: Bool
    public var isLoadingMore: Bool
    public var hasMore: Bool
    public var errorMessage: String?
    public var failure: Failure?

    public init(items: [Item], isLoading: Bool = false, isLoadingMore: Bool = false, hasMore: Bool = true,
                errorMessage: String? = nil, failure: Failure? = nil) {
        self.items = items
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.hasMore = hasMore
        self.errorMessage = errorMessage
        self.failure = failure
    }
}

/// One List renderer for both host-owned Observable state and the compatible ViewModel adapter.
/// Owns its List: use directly in a page/NavigationStack/Sheet, not inside another List or ScrollView.
/// All actions belong to the host. Explicit actions and row tasks are cancelled when their views leave.
public struct CYPaginatedListContent<Item: Identifiable & Sendable, Row: View, Empty: View>: View {
    let state: CYPaginationState<Item>
    let emptyView: () -> Empty
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    let onRetry: () async -> Void
    let preloadThreshold: Int
    let loadingView: () -> AnyView
    let errorView: (String, @escaping () -> Void) -> AnyView
    let rowContent: (Item) -> Row
    @State private var actionID = UUID()
    @State private var retries = false
    @State private var requested = false

    public init(
        state: CYPaginationState<Item>,
        @ViewBuilder emptyView: @escaping () -> Empty,
        onRefresh: @escaping () async -> Void,
        onLoadMore: @escaping () async -> Void,
        onRetry: @escaping () async -> Void,
        preloadThreshold: Int = 3,
        loadingView: @escaping () -> AnyView = { AnyView(ProgressView()) },
        errorView: @escaping (String, @escaping () -> Void) -> AnyView = { message, retry in
            AnyView(VStack {
                Text(message)
                Button("action_retry".cyLocalized, action: retry).accessibilityIdentifier("pagination.retry")
            })
        },
        @ViewBuilder rowContent: @escaping (Item) -> Row
    ) {
        self.state = state
        self.emptyView = emptyView
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.onRetry = onRetry
        self.preloadThreshold = max(1, preloadThreshold)
        self.loadingView = loadingView
        self.errorView = errorView
        self.rowContent = rowContent
    }

    public var body: some View {
        List {
            if state.items.isEmpty {
                if state.isLoading { loadingView().frame(maxWidth: .infinity) } else if let error = state.errorMessage { errorView(error) { request(retry: true) } } else {
                    emptyView()
                    Button("action_retry".cyLocalized) { request(retry: false) }
                }
            } else if state.failure == .refresh, let error = state.errorMessage {
                errorView(error) { request(retry: true) }
            }
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                rowContent(item)
                    .task {
                        let threshold = max(0, state.items.count - preloadThreshold)
                        if index >= threshold, state.failure == nil, state.errorMessage == nil,
                           state.hasMore, !state.isLoadingMore, !state.isLoading {
                            await onLoadMore()
                        }
                    }
            }
            footer
        }
        .listStyle(.plain)
        .refreshable { await onRefresh() }
        .task(id: actionID) {
            guard requested else { return }
            let id = actionID
            defer { if actionID == id { requested = false } }
            if retries { await onRetry() } else { await onRefresh() }
        }
    }

    private func request(retry: Bool) {
        retries = retry
        requested = true
        actionID = UUID()
    }

    @ViewBuilder private var footer: some View {
        if state.failure == .append, let error = state.errorMessage {
            errorView(error) { request(retry: true) }
        } else if state.isLoadingMore {
            HStack { Spacer(); ProgressView(); Text("loading".cyLocalized); Spacer() }
                .font(CYAppFont.caption).padding(.vertical, CYAppDimens.marginS)
        } else if !state.hasMore, !state.items.isEmpty {
            Text("pagination_end".cyLocalized).font(CYAppFont.caption)
                .foregroundStyle(CYAppColor.textTertiary).frame(maxWidth: .infinity)
        }
    }
}

public extension CYPaginatedListContent where Empty == CYEmptyStateView {
    init(state: CYPaginationState<Item>, onRefresh: @escaping () async -> Void,
         onLoadMore: @escaping () async -> Void, onRetry: @escaping () async -> Void,
         @ViewBuilder rowContent: @escaping (Item) -> Row) {
        self.init(state: state, emptyView: {
            CYEmptyStateView(title: "empty_title".cyLocalized, message: "empty_message".cyLocalized)
        }, onRefresh: onRefresh, onLoadMore: onLoadMore, onRetry: onRetry, rowContent: rowContent)
    }
}

// MARK: - 默认空状态的便捷初始化

public extension CYPaginatedListView where Empty == CYEmptyStateView {
    /// 使用默认空状态的初始化
    init(
        viewModel: CYPaginatedListViewModel<Item>,
        onRefresh: @escaping () async -> Void,
        onLoadMore: @escaping () async -> Void,
        @ViewBuilder rowContent: @escaping (Item) -> Row
    ) {
        self.init(
            viewModel: viewModel,
            emptyView: {
                CYEmptyStateView(
                    title: "empty_title".cyLocalized,
                    message: "empty_message".cyLocalized
                )
            },
            onRefresh: onRefresh,
            onLoadMore: onLoadMore,
            rowContent: rowContent
        )
    }
}

// MARK: - 加载更多按钮组件

/// 列表底部的"加载更多"按钮（适用于非无限滚动场景）
public struct CYLoadMoreButton: View {
    let isLoading: Bool
    let hasMore: Bool
    let action: () async -> Void
    
    public init(isLoading: Bool, hasMore: Bool, action: @escaping () async -> Void) {
        self.isLoading = isLoading
        self.hasMore = hasMore
        self.action = action
    }
    
    public var body: some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("loading".cyLocalized)
                    .font(CYAppFont.bodySmall)
                    .foregroundStyle(CYAppColor.textSecondary)
            } else if hasMore {
                Button {
                    Task { await action() }
                } label: {
                    Text("load_more".cyLocalized)
                        .font(CYAppFont.label)
                        .foregroundStyle(CYAppColor.accent)
                }
            } else {
                Text("pagination_end".cyLocalized)
                    .font(CYAppFont.caption)
                    .foregroundStyle(CYAppColor.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, CYAppDimens.marginM)
    }
}
