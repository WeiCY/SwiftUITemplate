import Foundation
import CoreLocation

/// 位置权限请求器
/// 桥接 CoreLocation 框架权限 API
///
/// 注意：需要在 Info.plist 中添加以下 key：
/// - `NSLocationWhenInUseUsageDescription`（使用期间定位）
/// - `NSLocationAlwaysAndWhenInUseUsageDescription`（始终定位，如需要）
public final class CYLocationPermission: NSObject, CYPermissionRequester, CLLocationManagerDelegate, @unchecked Sendable {
    
    private var locationManager: CLLocationManager?
    private var continuation: CheckedContinuation<CYPermissionStatus, Never>?
    
    public override init() {
        super.init()
    }
    
    public var status: CYPermissionStatus {
        get async {
            let manager = CLLocationManager()
            let status = manager.authorizationStatus
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
            self.continuation = continuation
            let manager = CLLocationManager()
            manager.delegate = self
            self.locationManager = manager
            manager.requestWhenInUseAuthorization()
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
        
        continuation?.resume(returning: status)
        continuation = nil
        locationManager = nil
    }
}
