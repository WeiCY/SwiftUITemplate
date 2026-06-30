import Foundation
import Observation

/// 通用分页列表 ViewModel 基类
///
/// 内置下拉刷新、上拉加载更多、无限滚动支持。
/// 子类只需实现 `fetchPage` 方法即可：
///
/// ```swift
/// @Observable
/// final class ProductListViewModel: CYPaginatedListViewModel<Product> {
///     override func fetchPage(page: Int, pageSize: Int) async throws -> [Product] {
///         return try await networkClient.request(ProductEndpoint.list(page: page, size: pageSize))
///     }
/// }
///
/// // View 中使用：
/// List {
///     ForEach(viewModel.items) { item in ... }
///     if viewModel.hasMore {
///         ProgressView().onAppear { Task { await viewModel.loadMore() } }
///     }
/// }
/// .refreshable { await viewModel.refresh() }
/// ```
@MainActor
@Observable
open class CYPaginatedListViewModel<Item: Identifiable & Sendable>: CYBaseViewModel {
    
    // MARK: - 公开状态
    
    /// 当前列表数据
    public var items: [Item] = []
    
    /// 是否还有更多数据可加载
    public var hasMore: Bool = true
    
    /// 是否正在加载更多
    public var isLoadingMore: Bool = false
    
    /// 当前页码
    public var currentPage: Int = 1
    
    /// 每页大小
    public var pageSize: Int
    
    /// 是否为空列表（无数据且非加载中）
    public var isEmpty: Bool {
        items.isEmpty && !isLoading
    }
    
    // MARK: - Init
    
    public init(pageSize: Int = CYAppConstants.defaultPageSize) {
        self.pageSize = pageSize
        super.init()
    }
    
    // MARK: - 抽象方法
    
    /// 子类必须重写：加载指定页的数据
    /// - 参数：
    ///   - page: 页码（从 1 开始）
    ///   - pageSize: 每页大小
    /// - Returns: 该页的数据数组
    open func fetchPage(page: Int, pageSize: Int) async throws -> [Item] {
        fatalError("Subclass must override fetchPage(page:pageSize:)")
    }
    
    // MARK: - 首次加载
    
    /// 首次加载数据（重置页码和数据）
    public func load() async {
        await refresh()
    }
    
    // MARK: - 下拉刷新
    
    /// 下拉刷新 — 重置到第一页，清空旧数据
    public func refresh() async {
        currentPage = 1
        hasMore = true
        items = []
        
        await executeTask { [weak self] in
            guard let self else { return }
            let newItems = try await self.fetchPage(page: 1, pageSize: self.pageSize)
            self.items = newItems
            self.hasMore = newItems.count >= self.pageSize
            self.currentPage = 1
        }
    }
    
    // MARK: - 加载更多
    
    /// 上拉加载更多（无限滚动）
    public func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        do {
            let newItems = try await fetchPage(page: nextPage, pageSize: pageSize)
            items.append(contentsOf: newItems)
            currentPage = nextPage
            hasMore = newItems.count >= pageSize
        } catch {
            self.error = CYAppError.resolve(error)
        }
        
        isLoadingMore = false
    }
    
    // MARK: - 数据管理
    
    /// 追加单条数据到列表头部
    public func prepend(_ item: Item) {
        items.insert(item, at: 0)
    }
    
    /// 追加单条数据到列表尾部
    public func append(_ item: Item) {
        items.append(item)
    }
    
    /// 删除指定索引的数据
    public func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
    }
    
    /// 更新指定 ID 的数据项
    public func update(_ item: Item, where condition: (Item) -> Bool) {
        if let index = items.firstIndex(where: condition) {
            items[index] = item
        }
    }
    
    /// 删除指定 ID 的数据
    public func remove(where condition: (Item) -> Bool) {
        items.removeAll(where: condition)
    }
}
