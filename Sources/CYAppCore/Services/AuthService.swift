import Foundation

// MARK: - 认证服务
//
// 封装用户登录/登出/Token刷新逻辑，通过协议抽象方便替换实际实现。
// 依赖 CYUserSession 保存用户会话，通过 CYKeychainHelper 持久化 Token。
//
// ## 用法
// ```swift
// let authService = CYAppContainer.shared.authService
//
// // 登录
// let user = try await authService.login(username: "john", password: "123")
//
// // 刷新 Token（通常在拦截器中自动调用）
// let newToken = try await authService.refreshToken("old_refresh_token")
//
// // 登出
// try await authService.logout()
//
// // 应用启动时恢复会话
// let restored = await authService.restoreSession()
// ```

// MARK: - 协议

public protocol AuthServiceProtocol {
    func login(username: String, password: String) async throws -> User
    func logout() async throws
    func refreshToken(_ refreshToken: String) async throws -> TokenPair
    func restoreSession() async -> User?
}

// MARK: - 实现

/// 默认认证服务实现（Mock + Keychain 持久化）
///
/// 生产环境替换为实际 API 调用：
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
    private let keychain = CYKeychainHelper.standard
    
    private enum KeychainKey {
        static let service = "com.cyapp.auth"
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let expiresAt = "expires_at"
        static let userData = "user_data"
    }
    
    public init(userSession: UserSessionProtocol) {
        self.userSession = userSession
    }
    
    // MARK: - 登录
    
    /// 登录（Mock 实现）
    ///
    /// 生产环境替换为 `client.post(AuthEndpoint.login, body:)`
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
        persistToken(token)
        persistUser(user)
        
        return user
    }
    
    // MARK: - 登出
    
    /// 登出 — 清除内存会话 + Keychain 持久化数据
    public func logout() async throws {
        try await Task.sleep(for: .milliseconds(500))
        await userSession.clear()
        clearPersistedSession()
    }
    
    // MARK: - Token 刷新
    
    /// 刷新 Token（Mock 实现）
    public func refreshToken(_ refreshToken: String) async throws -> TokenPair {
        try await Task.sleep(for: .milliseconds(500))
        let newToken = TokenPair.from(
            expiresIn: 7200,
            accessToken: "mock_new_access_\(UUID().uuidString)",
            refreshToken: "mock_new_refresh_\(UUID().uuidString)"
        )
        await userSession.updateToken(newToken)
        persistToken(newToken)
        return newToken
    }
    
    // MARK: - 会话持久化
    
    /// 从 Keychain 恢复上一次的登录会话。
    ///
    /// App 启动时调用，自动恢复未过期的 Token 和用户信息。
    /// 若 Token 已过期则清除持久化数据并返回 nil。
    ///
    /// - Returns: 恢复的用户（nil = 需要重新登录）
    public func restoreSession() async -> User? {
        guard let accessToken = keychain.readString(service: KeychainKey.service, account: KeychainKey.accessToken),
              let refreshToken = keychain.readString(service: KeychainKey.service, account: KeychainKey.refreshToken),
              let userData = keychain.read(service: KeychainKey.service, account: KeychainKey.userData),
              let user = try? JSONDecoder().decode(User.self, from: userData)
        else { return nil }
        
        let dateStr = keychain.readString(service: KeychainKey.service, account: KeychainKey.expiresAt) ?? ""
        let expiresAt = ISO8601DateFormatter().date(from: dateStr)
        
        let token = TokenPair(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
        await userSession.saveUser(user, token: token)
        
        if let expiresAt, Date() >= expiresAt {
            clearPersistedSession()
            await userSession.clear()
            return nil
        }
        
        return user
    }
    
    // MARK: - Private
    
    private func persistToken(_ token: TokenPair) {
        keychain.save(token.accessToken, service: KeychainKey.service, account: KeychainKey.accessToken)
        keychain.save(token.refreshToken, service: KeychainKey.service, account: KeychainKey.refreshToken)
        if let expiresAt = token.expiresAt {
            keychain.save(ISO8601DateFormatter().string(from: expiresAt), service: KeychainKey.service, account: KeychainKey.expiresAt)
        }
    }
    
    private func persistUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            keychain.save(data, service: KeychainKey.service, account: KeychainKey.userData)
        }
    }
    
    private func clearPersistedSession() {
        keychain.delete(service: KeychainKey.service, account: KeychainKey.accessToken)
        keychain.delete(service: KeychainKey.service, account: KeychainKey.refreshToken)
        keychain.delete(service: KeychainKey.service, account: KeychainKey.expiresAt)
        keychain.delete(service: KeychainKey.service, account: KeychainKey.userData)
    }
}
