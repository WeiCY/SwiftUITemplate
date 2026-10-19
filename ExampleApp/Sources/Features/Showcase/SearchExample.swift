import SwiftUI
import Observation
import CYAppCore
import CYAppDesignSystem

struct SearchResult: Identifiable, Sendable { let id: Int; let title: String }

@MainActor
@Observable
final class SearchExampleModel: CYPaginatedListViewModel<SearchResult> {
    private(set) var query = ""
    var failFirst = false
    var failAppend = false
    private let search: (String, Int, Int) async throws -> [SearchResult]

    init(search: @escaping (String, Int, Int) async throws -> [SearchResult] = { query, page, size in
        try await Task.sleep(for: .milliseconds(300))
        guard query.lowercased() != "empty" else { return [] }
        return (0..<size).compactMap { offset in
            let id = (page - 1) * size + offset
            return id < 25 ? SearchResult(id: id, title: "\(query.isEmpty ? "Result" : query) #\(id)") : nil
        }
    }) {
        self.search = search
        super.init(pageSize: 10)
    }

    func changeQuery(_ value: String) {
        query = value
        reset()
    }

    override func fetchPage(page: Int, pageSize: Int) async throws -> [SearchResult] {
        if (page == 1 && failFirst) || (page > 1 && failAppend) {
            throw CYAppError.network("模拟分页失败；关闭开关后点重试 / Disable failure, then retry")
        }
        return try await search(query, page, pageSize)
    }
}

struct SearchExample: View {
    @State private var query = ""
    @State private var model = SearchExampleModel()
    @State private var reloadID = UUID()

    var body: some View {
        VStack {
            CYSearchBar(text: $query, placeholder: "搜索；empty 返回空 / Search")
                .padding(.horizontal)
            Toggle("首次失败 / First page failure", isOn: $model.failFirst)
                .accessibilityIdentifier("paging.failFirst")
            Toggle("追加失败 / Append failure", isOn: $model.failAppend)
            Button("重新开始 / Restart") { model.reset(); reloadID = UUID() }
                .accessibilityIdentifier("paging.restart")
            Text("首次失败：打开开关后重新开始；追加失败：打开开关后向下滚动。")
                .font(.caption)
            CYPaginatedListView(viewModel: model, onRefresh: { await model.refresh() }, onLoadMore: { await model.loadMore() }) {
                Text($0.title)
            }
        }
        .navigationTitle("搜索与分页 / Search")
        .onChange(of: query) { _, value in model.changeQuery(value) }
        .task(id: [query, reloadID.uuidString]) {
            do {
                try await Task.sleep(for: .milliseconds(300))
                await model.load()
            } catch { /* debounce cancellation is expected */ }
        }
    }
}
