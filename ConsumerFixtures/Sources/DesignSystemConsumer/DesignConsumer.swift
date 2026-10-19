import SwiftUI
import Observation
import CYAppDesignSystem

public struct ConsumerRow: Identifiable, Sendable {
    public let id: Int
    public init(id: Int) { self.id = id }
}

/// Host-owned domain state, deliberately not a template ViewModel subclass.
@MainActor
@Observable
public final class ConsumerPages {
    public var items: [ConsumerRow] = []
    public var page = 1
    public var loading = false
    public var appending = false
    public var hasMore = true
    public var failure: CYPaginationState<ConsumerRow>.Failure?
    public var error: String?
    public var failFirst = true
    public var failAppend = true
    public private(set) var requests: [Int] = []
    private var generation = UUID()
    private let fetch: (Int) async throws -> [ConsumerRow]

    public init(fetch: @escaping (Int) async throws -> [ConsumerRow] = { page in
        try Task.checkCancellation()
        return page <= 3 ? (0..<20).map { ConsumerRow(id: (page - 1) * 20 + $0) } : []
    }) { self.fetch = fetch }

    public var state: CYPaginationState<ConsumerRow> {
        .init(items: items, isLoading: loading, isLoadingMore: appending, hasMore: hasMore, errorMessage: error, failure: failure)
    }

    public func refresh() async {
        generation = UUID()
        await request(page: 1, refresh: true)
    }
    public func append() async {
        guard hasMore, !loading, !appending, failure == nil else { return }
        await request(page: page + 1, refresh: false)
    }
    public func retry() async {
        guard let failure else { return }
        self.failure = nil
        switch failure {
        case .refresh: await refresh()
        case .append: await append()
        }
    }
    private func request(page: Int, refresh: Bool) async {
        let id = generation
        loading = refresh
        appending = !refresh
        error = nil
        failure = nil
        requests.append(page)
        do {
            if refresh ? failFirst : failAppend { throw ConsumerFailure.simulated }
            let rows = try await fetch(page)
            try Task.checkCancellation()
            guard generation == id else { return }
            items = refresh ? rows : items + rows
            self.page = page
            hasMore = !rows.isEmpty
        } catch {
            guard generation == id else { return }
            if !(error is CancellationError), !Task.isCancelled {
                self.error = "Consumer failure"
                failure = refresh ? .refresh : .append
            }
        }
        guard generation == id else { return }
        loading = false
        appending = false
    }
    private enum ConsumerFailure: Error { case simulated }
}

public struct DesignConsumerPage: View {
    @State private var model: ConsumerPages
    @State private var text = ""
    @State private var refreshID = UUID()
    public init(model: ConsumerPages = ConsumerPages()) { _model = State(initialValue: model) }
    public var body: some View {
        VStack {
            CYTextField(placeholder: "Host input", text: $text, showsClearButton: true)
            HStack {
                Toggle("First failure", isOn: $model.failFirst).accessibilityIdentifier("consumer.first")
                Toggle("Append failure", isOn: $model.failAppend).accessibilityIdentifier("consumer.append")
            }
            PrimaryButton(title: "Refresh host state", action: { refreshID = UUID() }, isLoading: model.loading)
            CardView { Text("Host-owned Observable state") }
            Text("Loaded: \(model.items.count)").accessibilityIdentifier("consumer.count")
            CYPaginatedListContent(state: model.state, onRefresh: { await model.refresh() },
                                   onLoadMore: { await model.append() }, onRetry: { await model.retry() }) {
                Text("Consumer row \($0.id)")
            }
        }
        .navigationTitle("Independent paging")
        .task(id: refreshID) { await model.refresh() }
    }
}

/// External public-only usage: host focus plus native safe area, without template keyboard/navigation wrappers.
public struct DesignInputConsumerPage: View {
    @State private var code = ""
    @FocusState private var focused: Bool
    public init() {}
    public var body: some View {
        CYPageContainer(title: "Inputs", showsHeader: false, usesScrollView: false) {
            Form {
                CYVerificationCodeInput(code: $code, title: "Consumer OTP") { _ in focused = false }
                    .focused($focused)
                Text("Code: \(code)").accessibilityIdentifier("consumer.otpValue")
                Button("Restart input") { code = ""; focused = true }.accessibilityIdentifier("consumer.restartInput")
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CYBottomActionBar { Text("Local input") } trailing: {
                Button("Done") { focused = false }.accessibilityIdentifier("consumer.inputDone")
            }
        }
        .navigationTitle("Inputs")
    }
}
