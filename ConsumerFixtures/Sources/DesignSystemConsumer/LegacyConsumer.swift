import SwiftUI
import CYAppCore
import CYAppDesignSystem

/// Compile the existing public initializer from an external package as a compatibility gate.
@MainActor
private final class LegacyPages: CYPaginatedListViewModel<ConsumerRow> {
    override func fetchPage(page: Int, pageSize: Int) async throws -> [ConsumerRow] {
        try Task.checkCancellation()
        return page == 1 ? [ConsumerRow(id: 0)] : []
    }
}

public struct LegacyConsumerPage: View {
    @State private var model = LegacyPages()
    public init() {}
    public var body: some View {
        CYPaginatedListView(viewModel: model, onRefresh: { await model.refresh() }, onLoadMore: { await model.loadMore() }) {
            Text("Legacy row \($0.id)")
        }.task { await model.load() }
    }
}
