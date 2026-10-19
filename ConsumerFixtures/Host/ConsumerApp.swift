import SwiftUI
import SwiftData
import CoreOnly
import OfflinePersistence
import DesignSystemConsumer
import CustomComposition

@main
struct ConsumerApp: App {
    @State private var first = HostComposition()
    @State private var second = HostComposition()
    init() { HostComposition.configureBrand() }
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    DesignConsumerPage(model: makePages())
                }.tabItem { Text("Paging") }
                CustomConsumerPage(host: first).tabItem { Text("Custom A") }
                CustomConsumerPage(host: second).tabItem { Text("Custom B") }
                NavigationStack { DesignInputConsumerPage() }.tabItem { Text("Inputs") }
                NavigationStack { OfflinePage() }
                    .modelContainer(for: Note.self, inMemory: true).tabItem { Text("Offline") }
            }
            .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--large-type") ? .accessibility2 : .large)
        }
    }
    private func makePages() -> ConsumerPages {
        let large = ProcessInfo.processInfo.arguments.contains("--large-list")
        let model = ConsumerPages { page in
            if large { return page == 1 ? (0..<10_000).map { ConsumerRow(id: $0) } : [] }
            return page <= 3 ? (0..<20).map { ConsumerRow(id: (page - 1) * 20 + $0) } : []
        }
        if large { model.failFirst = false; model.failAppend = false }
        return model
    }
}
