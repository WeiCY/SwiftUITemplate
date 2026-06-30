import Foundation

// MARK: - 分析服务协议

/// 分析服务协议
/// 业务代码通过此协议上报事件，不直接依赖具体 SDK
public protocol CYAnalyticsServiceProtocol: Sendable {
    /// 上报分析事件
    /// - 参数：
    ///   - event: 事件名称
    ///   - properties: 事件属性（Sendable 约束确保并发安全）
    func track(event: String, properties: [String: any Sendable]?)
}

// MARK: - 默认实现

/// 默认分析服务实现（日志输出）
/// 替换为 Firebase / Amplitude / Mixpanel 时只需修改此类
public final class CYAnalyticsService: CYAnalyticsServiceProtocol, @unchecked Sendable {
    private let logger = CYLogger.shared
    
    public init() {}
    
    public func track(event: String, properties: [String: any Sendable]? = nil) {
        logger.info("Analytics Event: \(event) | Properties: \(String(describing: properties))")
    }
}
