import Foundation

/// 权限状态枚举
public enum CYPermissionStatus: String, Sendable {
    case notDetermined  // 用户尚未做出选择
    case denied         // 用户拒绝
    case authorized     // 用户已授权
    case restricted     // 受限（家长控制等）
}

/// 权限类型枚举
public enum CYPermissionType: String, CaseIterable, Sendable {
    case camera
    case photoLibrary
    case notification
    case location
}

/// 权限请求器协议
/// 每种权限类型实现此协议
public protocol CYPermissionRequester: Sendable {
    /// 查询当前权限状态
    var status: CYPermissionStatus { get async }
    /// 请求权限
    func request() async -> CYPermissionStatus
}
