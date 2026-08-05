import Foundation
import os

// MARK: - Mock Analytics Service

/// 内存事件记录分析服务，用于测试和调试。
///
/// ```swift
/// let mock = MockAnalyticsService()
/// mock.track(event: "purchase", properties: ["amount": 29.9])
/// mock.trackScreen("Settings")
/// print(mock.recordedEvents)
/// ```
public final class MockAnalyticsService: CYAnalyticsServiceProtocol, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: [AnalyticsRecord]())

    public var recordedEvents: [AnalyticsRecord] { lock.withLock { $0 } }

    public var recordedScreens: [String] {
        lock.withLock { records in
            records.filter { $0.name == "screen_view" }.compactMap { $0.meta?["screen"] }
        }
    }

    public init() {}

    public func track(event: String, properties: [String: any Sendable]? = nil) {
        let meta = properties?.mapValues { String(describing: $0) }
        lock.withLock { $0.append(AnalyticsRecord(name: event, meta: meta, timestamp: Date())) }
    }

    public func identify(userId: String, traits: [String: any Sendable]? = nil) {
        let meta = traits?.mapValues { String(describing: $0) }
        lock.withLock { $0.append(AnalyticsRecord(name: "identify", meta: meta, timestamp: Date())) }
    }

    public func trackScreen(_ screenName: String, category: String? = nil) {
        var meta: [String: String] = ["screen": screenName]
        if let category { meta["category"] = category }
        let capturedMeta = meta
        lock.withLock { $0.append(AnalyticsRecord(name: "screen_view", meta: capturedMeta, timestamp: Date())) }
    }

    public func reset() {
        lock.withLock { $0.removeAll() }
    }

    public struct AnalyticsRecord: Sendable {
        public let name: String
        public let meta: [String: String]?
        public let timestamp: Date
    }
}
