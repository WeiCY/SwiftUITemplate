import Foundation
import CoreLocation

/// 定位授权在主 actor 创建和驱动；并发调用共享系统授权弹窗。
/// 宿主必须提供 NSLocationWhenInUseUsageDescription。
/// 取消只结束该调用方的等待并返回当前状态，不关闭系统弹窗。
@MainActor
public final class CYLocationPermission: NSObject, CYPermissionRequester {
    private let driver: any CYLocationAuthorizationDriving
    private var waiters: [UUID: CheckedContinuation<CYPermissionStatus, Never>] = [:]
    private var requestInFlight = false

    public override convenience init() {
        self.init(driver: CYSystemLocationAuthorizationDriver())
    }

    init(driver: any CYLocationAuthorizationDriving) {
        self.driver = driver
        super.init()
        driver.onChange = { [weak self] status in self?.receive(status) }
    }

    public var status: CYPermissionStatus {
        get async { Self.map(driver.authorizationStatus) }
    }

    public func request() async -> CYPermissionStatus {
        let current = Self.map(driver.authorizationStatus)
        guard current == .notDetermined, !Task.isCancelled else { return current }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Cancellation may have arrived before registration.
                let latest = Self.map(driver.authorizationStatus)
                guard !Task.isCancelled, latest == .notDetermined else {
                    continuation.resume(returning: latest)
                    return
                }
                waiters[id] = continuation
                if !requestInFlight {
                    requestInFlight = true
                    driver.requestWhenInUseAuthorization()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.waiters.removeValue(forKey: id)?.resume(returning: Self.map(self.driver.authorizationStatus))
            }
        }
    }

    private func receive(_ authorization: CLAuthorizationStatus) {
        let status = Self.map(authorization)
        // CoreLocation also reports its initial state; this is not a user decision.
        guard status != .notDetermined else { return }
        requestInFlight = false
        let pending = waiters
        waiters.removeAll()
        for continuation in pending.values { continuation.resume(returning: status) }
    }

    private static func map(_ status: CLAuthorizationStatus) -> CYPermissionStatus {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}

@MainActor
protocol CYLocationAuthorizationDriving: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var onChange: (@MainActor (CLAuthorizationStatus) -> Void)? { get set }
    func requestWhenInUseAuthorization()
}

@MainActor
private final class CYSystemLocationAuthorizationDriver: NSObject, CYLocationAuthorizationDriving, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onChange: (@MainActor (CLAuthorizationStatus) -> Void)?
    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseAuthorization() { manager.requestWhenInUseAuthorization() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onChange?(self.manager.authorizationStatus)
        }
    }
}
