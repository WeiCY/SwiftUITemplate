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
    @ObservationIgnored private var generation = UUID()
    
    /// 失败发生的请求。追加失败后自动加载暂停，必须显式 retry。
    public enum Failure: Equatable, Sendable {
        case refresh
        case append(page: Int)
    }
    public private(set) var failure: Failure?

    /// 是否为空列表（无数据且非加载中）
    public var isEmpty: Bool {
        items.isEmpty && !isLoading && error == nil
    }
    
    // MARK: - Init
    
    public init(pageSize: Int = CYAppConstants.defaultPageSize) {
        self.pageSize = max(1, pageSize)
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
    
    /// 下拉刷新 — 重置到第一页。
    /// 注意：刷新成功前**保留旧数据**，仅在成功后替换，
    /// 避免请求失败时用户看到空白而非原有内容。
    public func refresh() async {
        let id = UUID()
        generation = id
        isLoadingMore = false
        
        isLoading = true
        clearError()
        failure = nil
        do {
            let newItems = try await fetchPage(page: 1, pageSize: pageSize)
            try Task.checkCancellation()
            guard generation == id else { return }
            items = newItems
            hasMore = newItems.count >= pageSize
            currentPage = 1
        } catch {
            guard generation == id else { return }
            let resolved = CYAppError.resolve(error)
            if !resolved.isCancellation {
                self.error = resolved
                failure = .refresh
            }
        }
        guard generation == id else { return }
        isLoading = false
    }

    /// 自动追加；失败后不因行再次出现而重复请求。
    public func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading, failure == nil else { return }
        isLoadingMore = true
        let id = generation
        let nextPage = currentPage + 1
        error = nil
        do {
            let newItems = try await fetchPage(page: nextPage, pageSize: pageSize)
            try Task.checkCancellation()
            guard generation == id else { return }
            items.append(contentsOf: newItems)
            currentPage = nextPage
            hasMore = newItems.count >= pageSize
        } catch {
            guard generation == id else { return }
            let resolved = CYAppError.resolve(error)
            if !resolved.isCancellation {
                self.error = resolved
                failure = .append(page: nextPage)
            }
        }
        guard generation == id else { return }
        isLoadingMore = false
    }

    /// 首次/刷新失败重试第一页；追加失败重试未提交的同一页。
    public override func retry() async {
        guard !isLoading, !isLoadingMore, let failure else { return }
        self.failure = nil
        switch failure {
        case .refresh: await refresh()
        case .append: await loadMore()
        }
    }

    /// 搜索/筛选条件改变时立即失效旧请求并清空分页；随后由宿主防抖并 load。
    public func reset() {
        generation = UUID()
        items = []
        currentPage = 1
        hasMore = true
        isLoading = false
        isLoadingMore = false
        failure = nil
        clearError()
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
