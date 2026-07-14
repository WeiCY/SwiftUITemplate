import Foundation
import CoreLocation

/// 位置权限请求器
/// 桥接 CoreLocation 框架权限 API
///
/// 注意：需要在 Info.plist 中添加以下 key：
/// - `NSLocationWhenInUseUsageDescription`（使用期间定位）
/// - `NSLocationAlwaysAndWhenInUseUsageDescription`（始终定位，如需要）
public final class CYLocationPermission: NSObject, CYPermissionRequester, CLLocationManagerDelegate, @unchecked Sendable {
    
    /// 复用同一个 CLLocationManager 实例，避免每次请求都新建。
    private let locationManager = CLLocationManager()
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CYPermissionStatus, Never>?
    
    public override init() {
        super.init()
    }
    
    public var status: CYPermissionStatus {
        get async {
            let status = locationManager.authorizationStatus
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        }
    }
    
    public func request() async -> CYPermissionStatus {
        let currentStatus = await status
        guard currentStatus == .notDetermined else { return currentStatus }
        
        return await withCheckedContinuation { continuation in
            lock.lock()
            // 已有进行中的请求：直接以当前状态唤醒新续体，避免覆盖导致原续体泄漏 / 永不恢复
            if self.continuation != nil {
                lock.unlock()
                continuation.resume(returning: currentStatus)
                return
            }
            self.continuation = continuation
            lock.unlock()
            
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CYPermissionStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: status = .authorized
        case .denied: status = .denied
        case .restricted: status = .restricted
        case .notDetermined: status = .notDetermined
        @unknown default: status = .notDetermined
        }
        
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        
        continuation?.resume(returning: status)
    }
}
