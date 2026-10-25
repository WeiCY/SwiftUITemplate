import Foundation
import os

// MARK: - 分析服务

public protocol CYAnalyticsServiceProtocol: Sendable {
    func track(event: String, properties: [String: any Sendable]?)
    func identify(userId: String, traits: [String: any Sendable]?)
    func trackScreen(_ screenName: String, category: String?)
}

// MARK: - 默认实现

/// 有界内存事件缓冲示例，不持久化、不上传数据；`flush()` 仅清空队列。
/// 生产分析由宿主实现 `CYAnalyticsServiceProtocol` 并在组合根注入，勿修改模板源码。
/// 日志仅包含固定操作名及数量，不输出事件名、用户标识、属性或页面内容。
public final class CYAnalyticsService: CYAnalyticsServiceProtocol, Sendable {
    private let logger = CYLogger(category: "Analytics")
    
    private let eventQueue: CYAnalyticsEventQueue
    private let userIdLock = OSAllocatedUnfairLock(initialState: nil as String?)
    
    /// - Parameter maxPendingEvents: 最大待处理事件数，默认 100；非正值不保留事件。
    public init(maxPendingEvents: Int = 100) {
        eventQueue = CYAnalyticsEventQueue(capacity: max(0, maxPendingEvents))
    }
    
    public func track(event: String, properties: [String: any Sendable]? = nil) {
        let meta = buildMeta(properties: properties)
        eventQueue.enqueue(name: event, meta: meta)
        logger.debug("[Track] queued event")
    }
    
    public func identify(userId: String, traits: [String: any Sendable]? = nil) {
        userIdLock.withLock { $0 = userId }
        logger.debug("[Identify] updated identity")
    }
    
    public func trackScreen(_ screenName: String, category: String? = nil) {
        var meta: [String: String] = ["screen": screenName]
        if let category { meta["category"] = category }
        eventQueue.enqueue(name: "screen_view", meta: meta)
        logger.debug("[Screen] queued event")
    }
    
    /// 清空内存事件队列；此默认实现没有网络传输。
    public func flush() {
        let events = eventQueue.drain()
        guard !events.isEmpty else { return }
        logger.debug("[Flush] discarded \(events.count) buffered events")
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

private final class CYAnalyticsEventQueue: Sendable {
    private let capacity: Int
    private let lock = OSAllocatedUnfairLock(initialState: [AnalyticsEvent]())

    init(capacity: Int) { self.capacity = capacity }
    
    var count: Int { lock.withLock { $0.count } }
    
    func enqueue(name: String, meta: [String: String]?) {
        lock.withLock {
            guard capacity > 0 else { return }
            if $0.count >= capacity { $0.removeFirst() }
            $0.append(AnalyticsEvent(name: name, meta: meta, timestamp: Date()))
        }
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
