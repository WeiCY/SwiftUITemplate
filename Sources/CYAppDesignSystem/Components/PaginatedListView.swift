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
        @ViewBuilder rowContent: @escaping (Item) -> Row
    ) {
        self._viewModel = Bindable(viewModel)
        self.emptyView = emptyView
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.rowContent = rowContent
        self.preloadThreshold = max(1, preloadThreshold)
    }
    
    public var body: some View {
        Group {
            if viewModel.isEmpty && !viewModel.isLoading {
                emptyView()
            } else {
                listContent
            }
        }
    }
    
    private var listContent: some View {
        List {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                rowContent(item)
                    .onAppear {
                        // 距离末尾 preloadThreshold 行时提前触发加载更多
                        let thresholdIndex = max(0, viewModel.items.count - preloadThreshold)
                        if index >= thresholdIndex, viewModel.hasMore, !viewModel.isLoadingMore, !viewModel.isLoading {
                            Task { await onLoadMore() }
                        }
                    }
            }
            
            // 底部加载更多指示器
            footerView
        }
        .listStyle(.plain)
        .refreshable { await onRefresh() }
    }
    
    @ViewBuilder
    private var footerView: some View {
        if viewModel.isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("loading".cyLocalized)
                    .font(CYAppFont.caption)
                    .foregroundColor(CYAppColor.textSecondary)
                Spacer()
            }
            .padding(.vertical, CYAppDimens.marginS)
        } else if !viewModel.hasMore && !viewModel.items.isEmpty {
            HStack {
                Spacer()
                Text("pagination_end".cyLocalized)
                    .font(CYAppFont.caption)
                    .foregroundColor(CYAppColor.textTertiary)
                Spacer()
            }
            .padding(.vertical, CYAppDimens.marginM)
        }
    }
}

// MARK: - 默认空状态的便捷初始化

public extension CYPaginatedListView where Empty == CYDefaultEmptyView {
    /// 使用默认空状态的初始化
    init(
        viewModel: CYPaginatedListViewModel<Item>,
        onRefresh: @escaping () async -> Void,
        onLoadMore: @escaping () async -> Void,
        @ViewBuilder rowContent: @escaping (Item) -> Row
    ) {
        self.init(
            viewModel: viewModel,
            emptyView: { CYDefaultEmptyView() },
            onRefresh: onRefresh,
            onLoadMore: onLoadMore,
            rowContent: rowContent
        )
    }
}

// MARK: - 默认空状态视图

/// 默认的分页列表空状态视图
public struct CYDefaultEmptyView: View {
    let title: String
    let message: String
    let systemImage: String
    
    public init(
        title: String = "empty_title".cyLocalized,
        message: String = "empty_message".cyLocalized,
        systemImage: String = "tray"
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
    
    public var body: some View {
        VStack(spacing: CYAppDimens.marginM) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundColor(CYAppColor.textTertiary)
            
            Text(title)
                .font(CYAppFont.h4)
                .foregroundColor(CYAppColor.textPrimary)
            
            Text(message)
                .font(CYAppFont.bodySmall)
                .foregroundColor(CYAppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CYAppDimens.marginXL)
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
                    .foregroundColor(CYAppColor.textSecondary)
            } else if hasMore {
                Button {
                    Task { await action() }
                } label: {
                    Text("load_more".cyLocalized)
                        .font(CYAppFont.label)
                        .foregroundColor(CYAppColor.accent)
                }
            } else {
                Text("pagination_end".cyLocalized)
                    .font(CYAppFont.caption)
                    .foregroundColor(CYAppColor.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, CYAppDimens.marginM)
    }
}
