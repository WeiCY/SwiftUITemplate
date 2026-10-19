import Foundation
import SwiftData
import CYAppCore

// MARK: - 组合根
//
// 集中创建 Service / Repository / ViewModel，并把依赖显式注入。
// Feature 只接收已构造好的依赖，不自寻依赖、不引用 Legacy Facade。
// 真实项目可在此按需增减 Service（订阅、AI、定位等）。

@MainActor
final class AppDependencies {
    let toast: any CYToastManagerProtocol
    let loading: any CYLoadingManagerProtocol
    let alert: any CYAlertManagerProtocol
    let imageLoader: any CYImageLoaderProtocol
    let homeViewModel: HomeViewModel
    let bookmarkViewModel: BookmarkViewModel

    init(networkClient: any CYNetworkClientProtocol, modelContext: ModelContext,
         toast: any CYToastManagerProtocol = CYToastManager(),
         loading: any CYLoadingManagerProtocol = CYLoadingManager(),
         alert: any CYAlertManagerProtocol = CYAlertManager(),
         imageLoader: any CYImageLoaderProtocol = CYDefaultImageLoader.shared) {
        self.toast = toast
        self.loading = loading
        self.alert = alert
        self.imageLoader = imageLoader
        let articleService = ArticleService(client: networkClient)
        let bookmarkRepository = BookmarkRepository(context: modelContext)

        self.homeViewModel = HomeViewModel(
            service: articleService,
            repository: bookmarkRepository, toast: toast
        )
        self.bookmarkViewModel = BookmarkViewModel(repository: bookmarkRepository, toast: toast)
    }
}

// 自定义反馈实现：Observation 会跟踪转发属性读取到的可观察底层状态。
// UI 测试用 --custom-feedback 验证这些存在类型实例确实驱动覆盖层。
@MainActor
final class ExampleToastManager: CYToastManagerProtocol {
    private let state = CYToastManager()
    var message: String? { state.message }
    var type: CYToastType { state.type }
    var isPresented: Bool { state.isPresented }
    var presentationID: UUID { state.presentationID }
    var queueCount: Int { state.queueCount }
    var queueMode: CYToastQueueMode {
        get { state.queueMode }
        set { state.queueMode = newValue }
    }
    func show(_ message: String, type: CYToastType, duration: TimeInterval) { state.show(message, type: type, duration: duration) }
    func dismiss() { state.dismiss() }
    func dismissAll() { state.dismissAll() }
}

@MainActor
final class ExampleAlertManager: CYAlertManagerProtocol {
    private let state = CYAlertManager()
    var isPresented: Bool {
        get { state.isPresented }
        set { state.isPresented = newValue }
    }
    var title: String {
        get { state.title }
        set { state.title = newValue }
    }
    var message: String? {
        get { state.message }
        set { state.message = newValue }
    }
    var alertType: CYAlertManager.AlertType {
        get { state.alertType }
        set { state.alertType = newValue }
    }
    func showAlert(title: String, message: String?, type: CYAlertManager.AlertType) {
        state.showAlert(title: title, message: message, type: type)
    }
    func showConfirmation(title: String, message: String?, confirmTitle: String, confirmStyle isDestructive: Bool,
                          onConfirm: @escaping @Sendable () -> Void) {
        state.showConfirmation(title: title, message: message, confirmTitle: confirmTitle, confirmStyle: isDestructive, onConfirm: onConfirm)
    }
    func dismiss() { state.dismiss() }
    func dismissAll() { state.dismissAll() }
}

/// Automation uses a deterministic local GIF rather than a public image service.
struct CatalogImageLoader: CYImageLoaderProtocol {
    func loadImage(from url: URL) async throws -> Data {
        try Task.checkCancellation()
        return Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")!
    }
    func prefetch(urls: [URL]) {}
    func clearCache() {}
}
