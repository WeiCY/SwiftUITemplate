import Foundation

/// 权限状态枚举
public enum CYPermissionStatus: String, Sendable {
    case notDetermined  // 用户尚未做出选择
    case denied         // 用户拒绝
    case authorized     // 用户已授权
    case restricted     // 受限（家长控制等）
}

/// 权限类型标识。
/// 使用 struct 而非 enum，业务模块可以通过 extension 新增自定义权限类型，而不需要修改模板源码。
public struct CYPermissionType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let camera = CYPermissionType(rawValue: "camera")
    public static let photoLibrary = CYPermissionType(rawValue: "photoLibrary")
    public static let notification = CYPermissionType(rawValue: "notification")
    public static let location = CYPermissionType(rawValue: "location")
}

/// 权限请求器协议
/// 每种权限类型实现此协议
public protocol CYPermissionRequester: Sendable {
    /// 查询当前权限状态
    var status: CYPermissionStatus { get async }
    /// 请求权限
    func request() async -> CYPermissionStatus
}
