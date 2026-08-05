import Foundation

// MARK: - Mock Auth Service

/// 可配置的 Mock 认证服务。
///
/// ```swift
/// let mock = MockAuthService(userSession: CYUserSession())
/// mock.loginResult = .success(User(id: 1, name: "Test"))
/// mock.shouldFail = true
/// mock.mockError = CYNetworkError.tokenExpired
/// ```
public final class MockAuthService: AuthServiceProtocol {
    private let userSession: UserSessionProtocol

    public var loginResult: Result<User, Error> = .success(
        User(id: 1, name: "MockUser", email: "mock@example.com")
    )
    public var logoutResult: Result<Void, Error> = .success(())
    public var refreshResult: Result<TokenPair, Error> = .success(
        TokenPair(accessToken: "mock_token", refreshToken: "mock_refresh", expiresAt: Date().addingTimeInterval(7200))
    )
    public var defaultDelay: TimeInterval = 0.1
    public var sessionRestoredUser: User?

    public init(userSession: UserSessionProtocol) {
        self.userSession = userSession
    }

    public func login(username: String, password: String) async throws -> User {
        try await Task.sleep(for: .seconds(defaultDelay))
        let user = try loginResult.get()
        let token = TokenPair(accessToken: "mock_\(UUID().uuidString)", refreshToken: "mock_refresh_\(UUID().uuidString)")
        await userSession.saveUser(user, token: token)
        return user
    }

    public func logout() async throws {
        try await Task.sleep(for: .seconds(defaultDelay))
        try logoutResult.get()
        await userSession.clear()
    }

    public func refreshToken(_ refreshToken: String) async throws -> TokenPair {
        try await Task.sleep(for: .seconds(defaultDelay))
        let token = try refreshResult.get()
        await userSession.updateToken(token)
        return token
    }

    public func restoreSession() async -> User? {
        if let user = sessionRestoredUser {
            await userSession.saveUser(user, token: nil)
        }
        return sessionRestoredUser
    }
}
