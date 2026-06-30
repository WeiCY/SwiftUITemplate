import Foundation
import AVFoundation

/// 相机权限请求器
/// 桥接 AVFoundation 权限 API
public struct CYCameraPermission: CYPermissionRequester, Sendable {
    
    public init() {}
    
    public var status: CYPermissionStatus {
        get async {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        }
    }
    
    public func request() async -> CYPermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }
}
