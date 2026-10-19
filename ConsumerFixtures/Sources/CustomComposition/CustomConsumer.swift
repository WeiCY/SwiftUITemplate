import SwiftUI
import Observation
import CYAppCore
import CYAppUI
import CYAppDesignSystem

@MainActor @Observable
public final class HostToast: CYToastManagerProtocol {
    public var message: String?
    public var type: CYToastType = .info
    public var isPresented = false
    public var presentationID = UUID()
    public var queueCount = 0
    public var queueMode: CYToastQueueMode = .replace
    public init() {}
    public func show(_ message: String, type: CYToastType, duration: TimeInterval) {
        self.message = message; self.type = type; isPresented = true; presentationID = UUID()
    }
    public func dismiss() { isPresented = false; message = nil }
    public func dismissAll() { dismiss() }
}

@MainActor @Observable
public final class HostLoading: CYLoadingManagerProtocol {
    public var isLoading = false
    public var message: String?
    public init() {}
    public func show(_ message: String?) { self.message = message; isLoading = true }
    public func hide() { isLoading = false; message = nil }
    public func hideAll() { hide() }
}

@MainActor @Observable
public final class HostAlert: CYAlertManagerProtocol {
    public var isPresented = false
    public var title = ""
    public var message: String?
    public var alertType: CYAlertManager.AlertType = .info
    public init() {}
    public func showAlert(title: String, message: String?, type: CYAlertManager.AlertType) {
        self.title = title; self.message = message; alertType = type; isPresented = true
    }
    public func showConfirmation(title: String, message: String?, confirmTitle: String, confirmStyle isDestructive: Bool,
                                 onConfirm: @escaping @Sendable () -> Void) {
        showAlert(title: title, message: message, type: .confirmation(confirmAction: onConfirm, confirmTitle: confirmTitle, isDestructive: isDestructive))
    }
    public func dismiss() { isPresented = false }
    public func dismissAll() { dismiss() }
}

/// Deterministic local image, including a real cancellation suspension for lifecycle tests.
public actor HostImageLoader: CYImageLoaderProtocol {
    public private(set) var started = 0
    public private(set) var cancelled = 0
    private let onStart: @MainActor @Sendable () -> Void
    private let onCancel: @MainActor @Sendable () -> Void
    public init(onStart: @escaping @MainActor @Sendable () -> Void = {}, onCancel: @escaping @MainActor @Sendable () -> Void = {}) {
        self.onStart = onStart
        self.onCancel = onCancel
    }
    public func loadImage(from url: URL) async throws -> Data {
        started += 1
        await onStart()
        if url.lastPathComponent == "slow" {
            do { try await Task.sleep(for: .seconds(3600)) } catch { cancelled += 1; await onCancel(); throw CancellationError() }
        }
        return Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")!
    }
    public nonisolated func prefetch(urls: [URL]) {}
    public nonisolated func clearCache() {}
}

@MainActor @Observable
public final class HostImageStatus {
    public var started = 0
    public var cancelled = 0
    public init() {}
}

@MainActor
public final class HostComposition {
    public let toast = HostToast()
    public let loading = HostLoading()
    public let alert = HostAlert()
    public let images: HostImageLoader
    public let imageStatus: HostImageStatus
    public let router = CYAppRouter(tabs: ["one", "two"])
    public init() {
        let status = HostImageStatus()
        imageStatus = status
        images = HostImageLoader(onStart: { status.started += 1 }, onCancel: { status.cancelled += 1 })
    }
    public static func checkBrand() -> Bool {
        let original = CYDesignConfiguration.current
        defer { CYDesignConfiguration.configure(original) }
        configureBrand()
        return CYAppDimens.buttonHeight == 52
    }
    public static func configureBrand() { CYDesignConfiguration.configure(.alternate) }
}

public struct CustomConsumerPage: View {
    private let host: HostComposition
    @State private var slow = false
    public init(host: HostComposition) { self.host = host }
    public var body: some View {
        NavigationStack(path: host.router.binding(for: "one")) {
        VStack {
            Button("Host toast") { host.toast.show("Independent toast", type: .success, duration: 30) }
            Button("Host alert") { host.alert.showAlert(title: "Independent alert", message: nil, type: .info) }
            Button("Host loading") { host.loading.show("Independent loading") }
            Toggle("Slow image", isOn: $slow)
            CYRemoteImageView(url: URL(string: "https://local.invalid/\(slow ? "slow" : "image")"), imageLoader: host.images)
                .frame(width: 100, height: 100).accessibilityLabel("Deterministic image")
            NavigationLink("Leave page") { Text("Page left") }
            Button("Host route") { host.router.navigate(to: "Independent route") }
        }
        .navigationDestination(for: String.self) { Text($0) }
        }
        .feedbackOverlay(toastManager: host.toast, loadingManager: host.loading)
        .alertManager(manager: host.alert)
        .environment(host.router)
        .safeAreaInset(edge: .bottom) {
            Text("Started: \(host.imageStatus.started) Cancelled: \(host.imageStatus.cancelled)")
                .accessibilityIdentifier("consumer.image-status")
        }
    }
}
