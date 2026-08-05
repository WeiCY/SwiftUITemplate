import Foundation
import os

// MARK: - 分析服务

public protocol CYAnalyticsServiceProtocol: Sendable {
    func track(event: String, properties: [String: any Sendable]?)
    func identify(userId: String, traits: [String: any Sendable]?)
    func trackScreen(_ screenName: String, category: String?)
}

// MARK: - 默认实现

/// 默认分析服务实现，内置事件队列 + 批量发送。
///
/// 生产环境替换为 Firebase / Amplitude / Mixpanel 时只需修改本类。
///
/// ## 接入示例
/// ```swift
/// CYAppContainer.shared.analyticsService.identify(userId: "12345", traits: ["plan": "pro"])
/// CYAppContainer.shared.analyticsService.track(event: "purchase", properties: ["amount": 29.9])
/// CYAppContainer.shared.analyticsService.trackScreen("Settings")
/// ```
public final class CYAnalyticsService: CYAnalyticsServiceProtocol, @unchecked Sendable {
    private let logger = CYLogger(category: "Analytics")
    
    private let eventQueue = CYAnalyticsEventQueue()
    private let userIdLock = OSAllocatedUnfairLock(initialState: nil as String?)
    
    public init() {}
    
    public func track(event: String, properties: [String: any Sendable]? = nil) {
        let meta = buildMeta(properties: properties)
        eventQueue.enqueue(name: event, meta: meta)
        logger.info("[Track] \(event) \(meta ?? [:])")
    }
    
    public func identify(userId: String, traits: [String: any Sendable]? = nil) {
        userIdLock.withLock { $0 = userId }
        logger.info("[Identify] userId: \(userId), traits: \(String(describing: traits))")
    }
    
    public func trackScreen(_ screenName: String, category: String? = nil) {
        var meta: [String: String] = ["screen": screenName]
        if let category { meta["category"] = category }
        eventQueue.enqueue(name: "screen_view", meta: meta)
        logger.info("[Screen] \(screenName)")
    }
    
    /// 手动发送队列中的事件
    public func flush() {
        let events = eventQueue.drain()
        guard !events.isEmpty else { return }
        logger.info("[Flush] 发送 \(events.count) 条事件")
    }
    
    /// 当前队列事件数
    public var pendingEventCount: Int { eventQueue.count }
    
    private func buildMeta(properties: [String: any Sendable]?) -> [String: String]? {
        guard let properties else { return nil }
        var meta: [String: String] = [:]
        for (key, value) in properties {
            meta[key] = String(describing: value)
        }
        if let userId = userIdLock.withLock({ $0 }) {
            meta["user_id"] = userId
        }
        return meta
    }
}

// MARK: - 事件队列

private final class CYAnalyticsEventQueue: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: [AnalyticsEvent]())
    
    var count: Int { lock.withLock { $0.count } }
    
    func enqueue(name: String, meta: [String: String]?) {
        lock.withLock { $0.append(AnalyticsEvent(name: name, meta: meta, timestamp: Date())) }
    }
    
    func drain() -> [AnalyticsEvent] {
        lock.withLock {
            let events = $0
            $0.removeAll()
            return events
        }
    }
}

private struct AnalyticsEvent: Sendable {
    let name: String
    let meta: [String: String]?
    let timestamp: Date
}
