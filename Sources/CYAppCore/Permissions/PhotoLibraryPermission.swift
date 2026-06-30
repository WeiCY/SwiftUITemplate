import Foundation
import Photos

/// 相册权限请求器
/// 桥接 Photos 框架权限 API
public struct CYPhotoLibraryPermission: CYPermissionRequester, Sendable {
    
    public init() {}
    
    public var status: CYPermissionStatus {
        get async {
            switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
            case .authorized, .limited: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        }
    }
    
    public func request() async -> CYPermissionStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized, .limited: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
