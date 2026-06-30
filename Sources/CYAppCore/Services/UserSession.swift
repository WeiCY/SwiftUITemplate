import Foundation
import Observation

// MARK: - 用户会话管理
//
// 管理当前登录用户状态和 Token，配合 CYAppState 判断登录状态。
// 通过 UserSessionProtocol 协议抽象，方便 Mock 测试。
//
// 用法：
// ```swift
// let session = CYUserSession()
// session.saveUser(user, token: tokenPair)  // 保存用户 + Token
// session.isLoggedIn                        // true
// session.accessToken                       // "eyJhbG..."
// session.isTokenExpired                    // 是否过期
// session.clear()                           // 清除（登出）
// ```

/// 用户会话协议
@MainActor
public protocol UserSessionProtocol: AnyObject {
    /// 当前登录用户
    var user: User? { get }
    /// 是否已登录
    var isLoggedIn: Bool { get }
    /// 当前 AccessToken（nil = 未登录或已过期）
    var accessToken: String? { get }
    /// 当前 RefreshToken
    var refreshToken: String? { get }
    /// Token 是否已过期
    var isTokenExpired: Bool { get }
    /// 保存用户信息和 Token
    func saveUser(_ user: User, token: TokenPair?)
    /// 仅更新 Token（刷新后调用）
    func updateToken(_ token: TokenPair)
    /// 清除用户信息（登出）
    func clear()
}

@MainActor
@Observable
public final class CYUserSession: UserSessionProtocol {
    /// 当前登录用户
    public var user: User?
    
    /// 当前 AccessToken
    public var accessToken: String?
    
    /// 当前 RefreshToken
    public var refreshToken: String?
    
    /// Token 过期时间
    @ObservationIgnored
    private var tokenExpiresAt: Date?
    
    /// 是否已登录
    public var isLoggedIn: Bool {
        return user != nil
    }
    
    /// Token 是否已过期
    public var isTokenExpired: Bool {
        guard let expiresAt = tokenExpiresAt else { return true }
        return Date() >= expiresAt
    }
    
    public nonisolated init() {}
    
    /// 保存用户信息和 Token
    public func saveUser(_ user: User, token: TokenPair? = nil) {
        self.user = user
        if let token {
            self.accessToken = token.accessToken
            self.refreshToken = token.refreshToken
            self.tokenExpiresAt = token.expiresAt
        }
    }
    
    /// 仅更新 Token（Token 刷新后调用）
    public func updateToken(_ token: TokenPair) {
        self.accessToken = token.accessToken
        self.refreshToken = token.refreshToken
        self.tokenExpiresAt = token.expiresAt
    }
    
    /// 清除用户信息
    public func clear() {
        self.user = nil
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpiresAt = nil
    }
}

// MARK: - Token 对

/// AccessToken + RefreshToken 配对
public struct TokenPair: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    /// Token 过期时间（nil 表示不过期）
    public let expiresAt: Date?
    
    public init(accessToken: String, refreshToken: String, expiresAt: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
    
    /// 通过过期秒数创建
    public static func from(expiresIn seconds: Int, accessToken: String, refreshToken: String) -> TokenPair {
        TokenPair(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(seconds))
        )
    }
}

// MARK: - 用户模型

/// 用户模型
///
/// 包含基本信息、角色、头像等常见字段。
/// 业务项目可按需扩展，保持 Codable + Sendable。
public struct User: Codable, Identifiable, Sendable {
    /// 用户 ID
    public let id: Int
    /// 用户名
    public let name: String
    /// 邮箱
    public let email: String?
    /// 手机号
    public let phone: String?
    /// 头像 URL
    public let avatarURL: String?
    /// 用户角色
    public let role: UserRole
    
    public init(
        id: Int,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        avatarURL: String? = nil,
        role: UserRole = .user
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.avatarURL = avatarURL
        self.role = role
    }
}

// MARK: - 用户角色

/// 用户角色枚举
public enum UserRole: String, Codable, Sendable, CaseIterable {
    /// 普通用户
    case user
    /// VIP 用户
    case vip
    /// 管理员
    case admin
    
    /// 显示名称
    public var displayName: String {
        switch self {
        case .user: return "普通用户"
        case .vip: return "VIP"
        case .admin: return "管理员"
        }
    }
    
    /// 是否为管理员
    public var isStaff: Bool {
        self == .admin
    }
}
