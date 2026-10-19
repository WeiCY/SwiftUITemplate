import Foundation
import Observation
import CYAppCore
import CYAppPersistence

/// 重试仅重新打开存储，不删除数据库，不回退到内存。
@MainActor
@Observable
final class ExamplePersistence {
    private(set) var controller: CYPersistenceController?
    private(set) var dependencies: AppDependencies?
    private(set) var error: Error?
    private let builder: () throws -> CYPersistenceController

    init(builder: @escaping () throws -> CYPersistenceController = {
        try CYPersistenceController.create(for: [BookmarkItem.self, BookmarkTag.self])
    }) { self.builder = builder }

    func open(networkClient: any CYNetworkClientProtocol) {
        guard controller == nil else { return }
        do {
            let controller = try builder()
            let custom = ProcessInfo.processInfo.arguments.contains("--custom-feedback")
            dependencies = AppDependencies(
                networkClient: networkClient, modelContext: controller.container.mainContext,
                toast: custom ? ExampleToastManager() : CYToastManager(),
                loading: custom ? MockLoadingManager() : CYLoadingManager(),
                alert: custom ? ExampleAlertManager() : CYAlertManager(),
                imageLoader: ProcessInfo.processInfo.arguments.contains("--ui-testing") ? CatalogImageLoader() : CYFactoryContainer.shared.imageLoader
            )
            self.controller = controller
            error = nil
        } catch { self.error = error }
    }
}
