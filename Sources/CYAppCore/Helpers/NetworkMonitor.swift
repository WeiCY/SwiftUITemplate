import Foundation
import Network
import Observation

/// UI-facing path status, isolated to MainActor. Path availability does not guarantee a server is reachable.
@MainActor
@Observable
public final class CYNetworkMonitor {
    public static let shared = CYNetworkMonitor()

    public private(set) var isMonitoring = false
    /// Optimistic initial value; inspect hasReceivedUpdate before treating this as a measured path.
    public private(set) var isConnected = true
    public private(set) var hasReceivedUpdate = false
    public private(set) var connectionType: CYConnectionType = .unknown
    public private(set) var isExpensive = false
    public private(set) var isConstrained = false

    @ObservationIgnored private var driver: (any CYNetworkPathDriving)?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let makeDriver: @MainActor () -> any CYNetworkPathDriving

    public enum CYConnectionType: String, Sendable {
        case wifi, cellular, wiredEthernet, unknown

        public var displayName: String {
            switch self {
            case .wifi: "connection_wifi".cyLocalized
            case .cellular: "connection_cellular".cyLocalized
            case .wiredEthernet: "connection_wired".cyLocalized
            case .unknown: "connection_unknown".cyLocalized
            }
        }
    }

    private convenience init() { self.init(makeDriver: { CYSystemNetworkPathDriver() }) }

    init(makeDriver: @escaping @MainActor () -> any CYNetworkPathDriving) {
        self.makeDriver = makeDriver
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        generation = UUID()
        let current = generation
        let next = makeDriver()
        driver = next
        isMonitoring = true
        hasReceivedUpdate = false
        next.start { [weak self] snapshot in
            Task { @MainActor in
                guard let self, self.isMonitoring, self.generation == current else { return }
                self.isConnected = snapshot.isConnected
                self.connectionType = snapshot.connectionType
                self.isExpensive = snapshot.isExpensive
                self.isConstrained = snapshot.isConstrained
                self.hasReceivedUpdate = true
            }
        }
    }

    /// Retains the last values for display, but marks them stale and rejects already queued callbacks.
    public func stopMonitoring() {
        generation = UUID()
        isMonitoring = false
        hasReceivedUpdate = false
        driver?.cancel()
        driver = nil
    }
}

struct CYNetworkPathSnapshot: Sendable {
    let isConnected: Bool
    let connectionType: CYNetworkMonitor.CYConnectionType
    let isExpensive: Bool
    let isConstrained: Bool
}

@MainActor
protocol CYNetworkPathDriving: AnyObject {
    func start(_ handler: @escaping @Sendable (CYNetworkPathSnapshot) -> Void)
    func cancel()
}

@MainActor
private final class CYSystemNetworkPathDriver: CYNetworkPathDriving {
    private let monitor = NWPathMonitor()

    func start(_ handler: @escaping @Sendable (CYNetworkPathSnapshot) -> Void) {
        monitor.pathUpdateHandler = { path in
            let type: CYNetworkMonitor.CYConnectionType
            if path.usesInterfaceType(.wifi) { type = .wifi }
            else if path.usesInterfaceType(.cellular) { type = .cellular }
            else if path.usesInterfaceType(.wiredEthernet) { type = .wiredEthernet }
            else { type = .unknown }
            handler(CYNetworkPathSnapshot(isConnected: path.status == .satisfied, connectionType: type,
                                          isExpensive: path.isExpensive, isConstrained: path.isConstrained))
        }
        monitor.start(queue: DispatchQueue(label: "CYNetworkMonitor"))
    }

    func cancel() { monitor.cancel() }
}
