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
public struct CYPaginatedListView<Item: Identifiable, Row: View, Empty: View>: View {
    
    let items: [Item]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let error: CYAppError?
    let isEmpty: Bool
    let emptyView: () -> Empty
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    let rowContent: (Item) -> Row
    
    public init(
        viewModel: CYPaginatedListViewModel<Item>,
        @ViewBuilder emptyView: @escaping () -> Empty,
        onRefresh: @escaping () async -> Void,
        onLoadMore: @escaping () async -> Void,
        @ViewBuilder rowContent: @escaping (Item) -> Row
    ) {
        self.items = viewModel.items
        self.isLoading = viewModel.isLoading
        self.isLoadingMore = viewModel.isLoadingMore
        self.hasMore = viewModel.hasMore
        self.error = viewModel.error
        self.isEmpty = viewModel.isEmpty
        self.emptyView = emptyView
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.rowContent = rowContent
    }
    
    public var body: some View {
        Group {
            if isEmpty && !isLoading {
                emptyView()
            } else {
                listContent
            }
        }
    }
    
    private var listContent: some View {
        List {
            ForEach(items) { item in
                rowContent(item)
                    .onAppear {
                        // 最后一个 item 出现时触发加载更多
                        if let lastId = items.last?.id, item.id == lastId {
                            if hasMore && !isLoadingMore {
                                Task { await onLoadMore() }
                            }
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
        if isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("加载中...")
                    .font(CYAppFont.caption)
                    .foregroundColor(CYAppColor.textSecondary)
                Spacer()
            }
            .padding(.vertical, CYAppDimens.marginS)
        } else if !hasMore && !items.isEmpty {
            HStack {
                Spacer()
                Text("— 已加载全部 —")
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
        title: String = "暂无数据",
        message: String = "下拉刷新试试",
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
                Text("加载中...")
                    .font(CYAppFont.bodySmall)
                    .foregroundColor(CYAppColor.textSecondary)
            } else if hasMore {
                Button {
                    Task { await action() }
                } label: {
                    Text("加载更多")
                        .font(CYAppFont.label)
                        .foregroundColor(CYAppColor.accent)
                }
            } else {
                Text("— 已加载全部 —")
                    .font(CYAppFont.caption)
                    .foregroundColor(CYAppColor.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, CYAppDimens.marginM)
    }
}
