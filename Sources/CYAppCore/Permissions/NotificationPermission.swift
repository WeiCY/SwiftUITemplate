import Foundation
import UserNotifications

/// 通知权限请求器
/// 桥接 UserNotifications 框架权限 API
public struct CYNotificationPermission: CYPermissionRequester, Sendable {
    
    public init() {}
    
    public var status: CYPermissionStatus {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: return .authorized
            case .denied: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        }
    }
    
    public func request() async -> CYPermissionStatus {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }
}
