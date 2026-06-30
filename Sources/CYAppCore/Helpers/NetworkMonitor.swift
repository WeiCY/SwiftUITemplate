import Foundation
import Network
import Observation

// MARK: - 网络状态监听
//
// 基于 NWPathMonitor 监听网络连接状态和类型变化。
//
// 用法：
// ```swift
// let monitor = CYNetworkMonitor.shared
// monitor.startMonitoring()
//
// if monitor.isConnected { ... }
// if monitor.connectionType == .wifi { ... }
// if monitor.isExpensive { ... }  // 蜂窝数据
// ```

@Observable
public final class CYNetworkMonitor {
    
    /// 全局单例
    public static let shared = CYNetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "CYNetworkMonitor")
    
    /// 是否有网络连接
    public var isConnected: Bool = true
    
    /// 当前网络连接类型
    public var connectionType: CYConnectionType = .unknown
    
    /// 是否为计费网络（蜂窝数据）
    public var isExpensive: Bool = false
    
    /// 是否为低数据模式
    public var isConstrained: Bool = false
    
    /// 网络连接类型枚举
    public enum CYConnectionType: String {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
        
        public var displayName: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "蜂窝数据"
            case .wiredEthernet: return "有线网络"
            case .unknown: return "未知"
            }
        }
    }
    
    private init() {
        monitor = NWPathMonitor()
    }
    
    /// 开始监听网络状态变化
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.isConnected = path.status == .satisfied
            self.isExpensive = path.isExpensive
            self.isConstrained = path.isConstrained
            
            if path.usesInterfaceType(.wifi) {
                self.connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self.connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                self.connectionType = .wiredEthernet
            } else {
                self.connectionType = .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    /// 停止监听网络状态变化
    public func stopMonitoring() {
        monitor.cancel()
    }
}
