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
public final class CYNetworkMonitor: @unchecked Sendable {
    
    /// 全局单例
    public static let shared = CYNetworkMonitor()

    /// NWPathMonitor 回调所在的串行队列（非主线程）
    private let queue = DispatchQueue(label: "CYNetworkMonitor")

    /// 保护 `monitor` 与 `isMonitoring` 的串行队列，
    /// 避免主线程（start/stop）与回调队列之间的读写竞争。
    private let stateQueue = DispatchQueue(label: "CYNetworkMonitor.state")

    private var _monitor: NWPathMonitor?
    private var _isMonitoring: Bool = false

    /// 是否正在监听
    public var isMonitoring: Bool {
        stateQueue.sync { _isMonitoring }
    }

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

    private init() {}

    /// 开始监听网络状态变化。
    /// NWPathMonitor.cancel() 不可逆，因此每次 start 都重建一个新的 monitor，
    /// 使 stop 之后可再次 start。
    public func startMonitoring() {
        stateQueue.sync {
            guard !_isMonitoring else { return }

            let newMonitor = NWPathMonitor()
            newMonitor.pathUpdateHandler = { [weak self] path in
                guard let self else { return }
                let isConnected = path.status == .satisfied
                let isExpensive = path.isExpensive
                let isConstrained = path.isConstrained
                let connectionType: CYConnectionType = {
                    if path.usesInterfaceType(.wifi) { return .wifi }
                    if path.usesInterfaceType(.cellular) { return .cellular }
                    if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
                    return .unknown
                }()

                Task { @MainActor in
                    self.isConnected = isConnected
                    self.isExpensive = isExpensive
                    self.isConstrained = isConstrained
                    self.connectionType = connectionType
                }
            }
            newMonitor.start(queue: queue)
            _monitor = newMonitor
            _isMonitoring = true
        }
    }

    /// 停止监听网络状态变化
    public func stopMonitoring() {
        stateQueue.sync {
            _monitor?.cancel()
            _monitor = nil
            _isMonitoring = false
        }
    }
}
