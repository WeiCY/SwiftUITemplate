import Foundation
import Observation

// MARK: - Mock Toast Manager

/// 内存 Toast 管理器，用于单元测试和 SwiftUI Preview。
///
/// 不触发实际 UI，只记录调用历史。
///
/// ```swift
/// let mock = MockToastManager()
/// mock.show("Hello", type: .success)
/// XCTAssertEqual(mock.lastMessage, "Hello")
/// XCTAssertEqual(mock.lastType, .success)
/// ```
@MainActor
@Observable
public final class MockToastManager: CYToastManagerProtocol, @unchecked Sendable {
    public var message: String?
    public var type: CYToastType = .info
    public var isPresented = false
    public var presentationID = UUID()
    public var queueCount = 0
    public var queueMode: CYToastQueueMode = .replace

    public var lastMessage: String?
    public var lastType: CYToastType = .info
    public var lastDuration: TimeInterval = 0
    public var showCallCount = 0
    public var dismissCallCount = 0
    public private(set) var callHistory: [(message: String, type: CYToastType)] = []

    public nonisolated init() {}

    public func show(_ message: String, type: CYToastType, duration: TimeInterval) {
        lastMessage = message
        lastType = type
        lastDuration = duration
        showCallCount += 1
        callHistory.append((message, type))
        self.message = message
        self.type = type
        isPresented = true
        presentationID = UUID()
    }


    public func dismiss() {
        dismissCallCount += 1
        isPresented = false
        message = nil
    }

    public func dismissAll() {
        dismissCallCount += 1
        isPresented = false
        message = nil
        callHistory.removeAll()
    }

    public func reset() {
        message = nil
        type = .info
        isPresented = false
        lastMessage = nil
        showCallCount = 0
        dismissCallCount = 0
        callHistory.removeAll()
    }
}
