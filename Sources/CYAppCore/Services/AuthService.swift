import Foundation

// MARK: - 认证服务
//
// 封装用户登录/登出/Token刷新逻辑，通过协议抽象方便替换实际实现。
// 依赖 CYUserSession 保存用户会话信息。
//
// 用法：
// ```swift
// let authService = CYAuthService(userSession: CYUserSession())
//
// // 登录
// let user = try await authService.login(username: "john", password: "123")
//
// // 刷新 Token（通常在拦截器中自动调用）
// let newToken = try await authService.refreshToken("old_refresh_token")
//
// // 登出
// try await authService.logout()
// ```

/// 认证服务协议
public protocol AuthServiceProtocol {
    /// 登录（用户名+密码）
    func login(username: String, password: String) async throws -> User
    /// 登出
    func logout() async throws
    /// 使用 RefreshToken 换取新 Token
    func refreshToken(_ refreshToken: String) async throws -> TokenPair
}

/// 默认认证服务实现（Mock）
///
/// 当前为 Mock 实现，业务项目替换为实际 API 调用：
/// ```swift
/// final class MyAppAuthService: AuthServiceProtocol {
///     private let client: CYNetworkClientProtocol
///     private let session: UserSessionProtocol
///
///     func login(username: String, password: String) async throws -> User {
///         let response: LoginResponse = try await client.post(AuthEndpoint.login, body: LoginBody(username: username, password: password))
///         let token = TokenPair(accessToken: response.accessToken, refreshToken: response.refreshToken, expiresAt: response.expiresAt)
///         await session.saveUser(response.user, token: token)
///         return response.user
///     }
/// }
/// ```
public final class CYAuthService: AuthServiceProtocol {
    private let userSession: UserSessionProtocol
    
    public init(userSession: UserSessionProtocol) {
        self.userSession = userSession
    }
    
    /// 登录（Mock 实现，替换为实际 API 调用）
    public func login(username: String, password: String) async throws -> User {
        try await Task.sleep(for: .seconds(1))
        let user = User(
            id: 1,
            name: username,
            email: "\(username)@example.com",
            avatarURL: "https://api.dicebear.com/7.x/avataaars/svg?seed=\(username)",
            role: .user
        )
        let token = TokenPair.from(
            expiresIn: 7200,
            accessToken: "mock_access_token_\(UUID().uuidString)",
            refreshToken: "mock_refresh_token_\(UUID().uuidString)"
        )
        
        await userSession.saveUser(user, token: token)
        return user
    }
    
    /// 登出
    public func logout() async throws {
        try await Task.sleep(for: .milliseconds(500))
        await userSession.clear()
    }
    
    /// 刷新 Token（Mock 实现，替换为实际 API 调用）
    public func refreshToken(_ refreshToken: String) async throws -> TokenPair {
        try await Task.sleep(for: .milliseconds(500))
        let newToken = TokenPair.from(
            expiresIn: 7200,
            accessToken: "mock_new_access_\(UUID().uuidString)",
            refreshToken: "mock_new_refresh_\(UUID().uuidString)"
        )
        await userSession.updateToken(newToken)
        return newToken
    }
}
