import Foundation
import Observation

// MARK: - Toast 协议

@MainActor
public protocol CYToastManagerProtocol: AnyObject, Sendable {
    var message: String? { get }
    var type: CYToastType { get }
    var isPresented: Bool { get }
    var presentationID: UUID { get }
    var queueCount: Int { get }
    var queueMode: CYToastQueueMode { get set }
    func show(_ message: String, type: CYToastType, duration: TimeInterval)
    func dismiss()
    func dismissAll()
}

// MARK: - Toast 消息管理

/// 多条 Toast 到达时的展示策略。
public enum CYToastQueueMode: Sendable {
    /// 新消息立即替换当前消息。
    case replace
    /// 新消息按到达顺序依次展示。
    case queue
}

/// 管理全局 Toast 的展示、队列和自动消失。
///
/// 带有操作按钮（`action`）的 Toast 不会自动消失，需要用户主动交互：
/// - 点击操作按钮（`performAction()`）
/// - 点击关闭按钮或 Toast 本体（`dismiss()`）
/// - 点击空白区域（需 `tapOutsideToDismiss` 样式开启）
@Observable
@MainActor
public final class CYToastManager: CYToastManagerProtocol, @unchecked Sendable {
    public nonisolated static let shared = CYToastManager()

    public private(set) var message: String?
    public private(set) var type: CYToastType = .info
    public private(set) var isPresented = false
    /// 每次展示都会变化，供 SwiftUI 重播转场动画。
    public private(set) var presentationID = UUID()
    public private(set) var queueCount = 0
    public var queueMode: CYToastQueueMode = .replace

    /// 队列模式下最多保留的待展示消息数，超出时会丢弃最旧消息。默认 10。
    public var maxQueueSize: Int = 10

    @ObservationIgnored
    private var dismissTask: Task<Void, Never>?
    @ObservationIgnored
    private var queue: [ToastRequest] = []

    public nonisolated init() {}

    /// 显示 Toast。空白消息会被忽略，时长最短为 0.1 秒。
    ///
    /// - Parameters:
    ///   - message: Toast 文案。
    ///   - type: Toast 类型。
    ///   - duration: 自动消失时长（秒）。
    public func show(
        _ message: String,
        type: CYToastType = .info,
        duration: TimeInterval = 2.0
    ) {
        let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        let request = ToastRequest(
            message: message,
            type: type,
            duration: max(duration, 0.1)
        )

        if queueMode == .queue, isPresented {
            if queue.count >= maxQueueSize {
                queue.removeFirst()
            }
            queue.append(request)
            queueCount = queue.count
        } else {
            present(request)
        }
    }

    /// 关闭当前 Toast；队列模式下继续展示下一条。
    public func dismiss() {
        dismissTask?.cancel()
        finishCurrent()
    }

    /// 关闭当前 Toast 并清空等待队列。
    public func dismissAll() {
        dismissTask?.cancel()
        queue.removeAll()
        queueCount = 0
        isPresented = false
        message = nil
    }

    private func present(_ request: ToastRequest) {
        dismissTask?.cancel()
        message = request.message
        type = request.type
        presentationID = UUID()
        isPresented = true

        let currentID = presentationID
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(request.duration))
            guard !Task.isCancelled, self?.presentationID == currentID else { return }
            self?.finishCurrent()
        }
    }

    private func finishCurrent() {
        isPresented = false
        message = nil

        guard queueMode == .queue, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        queueCount = queue.count
        present(next)
    }
}

private struct ToastRequest: Sendable {
    let message: String
    let type: CYToastType
    let duration: TimeInterval
}

/// Toast 消息类型。
public enum CYToastType: Sendable {
    case info
    case success
    case error
    case warning

    public var icon: String {
        switch self {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .error: return "xmark.circle"
        case .warning: return "exclamationmark.triangle"
        }
    }

    /// 该类型 Toast 的建议默认展示时长（秒）。
    /// 错误类提示需要更多阅读时间，因此默认更长。
    public var defaultDuration: TimeInterval {
        switch self {
        case .info: 2.0
        case .success: 2.0
        case .error: 3.0
        case .warning: 2.5
        }
    }
}
