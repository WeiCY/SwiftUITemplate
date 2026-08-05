import Foundation
import Observation

// MARK: - Mock Loading Manager

/// 内存 Loading 管理器，用于单元测试和 SwiftUI Preview。
///
/// ```swift
/// let mock = MockLoadingManager()
/// mock.show("加载中…")
/// XCTAssertTrue(mock.isLoading)
/// mock.hide()
/// XCTAssertFalse(mock.isLoading)
/// ```
@MainActor
@Observable
public final class MockLoadingManager: CYLoadingManagerProtocol, @unchecked Sendable {
    public var isLoading = false
    public var message: String?

    public var showCallCount = 0
    public var hideCallCount = 0
    public private(set) var lastMessage: String?

    public nonisolated init() {}

    public func show(_ message: String?) {
        showCallCount += 1
        lastMessage = message
        self.message = message
        isLoading = true
    }

    public func hide() {
        hideCallCount += 1
        isLoading = false
        message = nil
    }

    public func reset() {
        isLoading = false
        message = nil
        showCallCount = 0
        hideCallCount = 0
        lastMessage = nil
    }
}
