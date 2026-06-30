import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// 统一权限管理器
/// 集中管理所有权限的查询和请求
///
/// 用法：
/// ```swift
/// // 查询状态
/// let status = await CYPermissionManager.shared.status(of: .camera)
///
/// // 请求权限
/// let result = await CYPermissionManager.shared.request(.camera)
/// if result == .denied {
///     CYPermissionManager.shared.openSettings()
/// }
/// ```
@Observable
@MainActor
public final class CYPermissionManager {
    
    public nonisolated static let shared = CYPermissionManager()
    
    private var requesters: [CYPermissionType: any CYPermissionRequester] = [:]
    
    /// 缓存的权限状态
    public var statuses: [CYPermissionType: CYPermissionStatus] = [:]
    
    /// 是否已完成内置权限注册
    @ObservationIgnored
    private var isRegistered = false
    
    public nonisolated init() {}
    
    /// 注册内置权限请求器（首次调用时自动执行）
    private func ensureRegistered() {
        guard !isRegistered else { return }
        isRegistered = true
        requesters[.camera] = CYCameraPermission()
        requesters[.photoLibrary] = CYPhotoLibraryPermission()
        requesters[.notification] = CYNotificationPermission()
        requesters[.location] = CYLocationPermission()
    }
    
    /// 注册自定义权限请求器
    public func register(_ type: CYPermissionType, requester: any CYPermissionRequester) {
        requesters[type] = requester
    }
    
    /// 查询权限状态
    public func status(of type: CYPermissionType) async -> CYPermissionStatus {
        ensureRegistered()
        guard let requester = requesters[type] else { return .notDetermined }
        let status = await requester.status
        statuses[type] = status
        return status
    }
    
    /// 请求权限
    public func request(_ type: CYPermissionType) async -> CYPermissionStatus {
        ensureRegistered()
        guard let requester = requesters[type] else { return .notDetermined }
        let status = await requester.request()
        statuses[type] = status
        return status
    }
    
    /// 打开系统设置页
    #if canImport(UIKit)
    public func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    #endif
}
