import XCTest
@testable import CYAppCore

final class AppCoreTests: XCTestCase {
    
    // MARK: - CYAppError Tests
    
    func testAppErrorMessage() {
        let error = CYAppError.network("timeout")
        XCTAssertTrue(error.message == "timeout")
    }
    
    func testAppErrorBusinessCode() {
        let error = CYAppError.business(code: 10001, message: "token expired")
        XCTAssertTrue(error.businessCode == 10001)
        XCTAssertTrue(error.message == "token expired")
    }
    
    func testAppErrorResolveFromNetworkError() {
        let networkError = CYNetworkError.invalidURL
        let resolved = CYAppError.resolve(networkError)
        if case .network = resolved {
        } else {
            XCTFail("Expected .network, got \(resolved)")
        }
    }
    
    func testAppErrorResolveBusinessError() {
        let networkError = CYNetworkError.businessError(code: 403, message: "forbidden")
        let resolved = CYAppError.resolve(networkError)
        if case .business(let code, let msg) = resolved {
            XCTAssertTrue(code == 403)
            XCTAssertTrue(msg == "forbidden")
        } else {
            XCTFail("Expected .business, got \(resolved)")
        }
    }
    
    func testAppErrorResolveFromDecodingError() {
        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))
        let resolved = CYAppError.resolve(decodingError)
        if case .decoding = resolved {
        } else {
            XCTFail("Expected .decoding, got \(resolved)")
        }
    }
    
    func testAppErrorResolvePassthrough() {
        let original = CYAppError.business(code: 10001, message: "custom error")
        let resolved = CYAppError.resolve(original)
        XCTAssertTrue(resolved == original)
    }
    
    func testAppErrorResolveUnknown() {
        struct CustomError: Error {}
        let resolved = CYAppError.resolve(CustomError())
        if case .unknown = resolved {
        } else {
            XCTFail("Expected .unknown, got \(resolved)")
        }
    }
    
    // MARK: - CYAppEnvironment Tests
    
    func testAppEnvironmentCurrent() {
        let env = CYAppEnvironment.current
        XCTAssertFalse(env.baseURL.isEmpty)
    }
    
    func testAppEnvironmentFeatureFlags() {
        #if DEBUG
        XCTAssertTrue(CYAppEnvironment.development.featureFlags.enableDebugMenu)
        XCTAssertFalse(CYAppEnvironment.production.featureFlags.enableDebugMenu)
        #endif
    }
    
    // MARK: - CYCacheManager Tests
    
    func testCacheManagerSaveAndLoad() {
        let cache = CYCacheManager.shared
        let testValue = "hello_cache"
        cache.save(value: testValue, forKey: "test_key", namespace: "UnitTest")
        let loaded: String? = cache.load(forKey: "test_key", namespace: "UnitTest")
        XCTAssertTrue(loaded == testValue)
        cache.clear(namespace: "UnitTest")
    }
    
    func testCacheManagerRemove() {
        let cache = CYCacheManager.shared
        cache.save(value: 42, forKey: "num_key", namespace: "UnitTest")
        cache.remove(forKey: "num_key", namespace: "UnitTest")
        let loaded: Int? = cache.load(forKey: "num_key", namespace: "UnitTest")
        XCTAssertNil(loaded)
    }
    
    func testCacheManagerTTLExpiration() {
        let cache = CYCacheManager.shared
        cache.save(value: "expired", forKey: "ttl_key", namespace: "UnitTest", ttl: 0)
        Thread.sleep(forTimeInterval: 0.1)
        let loaded: String? = cache.load(forKey: "ttl_key", namespace: "UnitTest")
        XCTAssertNil(loaded, "Cached value should have expired")
    }
    
    // MARK: - CYLogger Tests
    
    func testLoggerShared() {
        let logger = CYLogger.shared
        XCTAssertNotNil(logger)
        logger.info("Test info log")
        logger.debug("Test debug log")
    }
    
    func testLoggerCategory() {
        let netLog = CYLogger(category: "TestCategory")
        XCTAssertNotNil(netLog)
        netLog.info("Category test")
    }
    
    func testLoggerPredefinedCategories() {
        XCTAssertNotNil(CYLogger.network)
        XCTAssertNotNil(CYLogger.ui)
        XCTAssertNotNil(CYLogger.database)
        XCTAssertNotNil(CYLogger.auth)
        XCTAssertNotNil(CYLogger.cache)
    }
    
    func testLoggerLevels() {
        let logger = CYLogger.shared
        logger.setMinimumLevel(.warning)
        logger.debug("should be filtered")
        logger.info("should be filtered")
        logger.warning("should appear")
        logger.error("should appear")
        logger.critical("should appear")
        logger.setMinimumLevel(.debug)
    }
    
    // MARK: - CYBaseViewModel Tests
    
    @MainActor
    func testBaseViewModelInitialState() {
        let vm = CYBaseViewModel()
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.hasError)
    }
    
    @MainActor
    func testBaseViewModelExecuteTaskSuccess() async {
        let vm = CYBaseViewModel()
        var executed = false
        await vm.executeTask { executed = true }
        XCTAssertTrue(executed)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }
    
    @MainActor
    func testBaseViewModelExecuteTaskFailure() async {
        let vm = CYBaseViewModel()
        await vm.executeTask { throw CYNetworkError.invalidURL }
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.hasError)
        XCTAssertNotNil(vm.errorMessage)
    }
    
    @MainActor
    func testBaseViewModelRetry() async {
        let vm = CYBaseViewModel()
        var attemptCount = 0
        await vm.executeTask {
            attemptCount += 1
            if attemptCount == 1 { throw CYNetworkError.unknown }
        }
        XCTAssertTrue(attemptCount == 1)
        XCTAssertTrue(vm.hasError)
        await vm.retry()
        XCTAssertTrue(attemptCount == 2)
        XCTAssertFalse(vm.hasError)
    }
    
    @MainActor
    func testBaseViewModelClearError() async {
        let vm = CYBaseViewModel()
        await vm.executeTask { throw CYNetworkError.unknown }
        XCTAssertTrue(vm.hasError)
        vm.clearError()
        XCTAssertFalse(vm.hasError)
        XCTAssertNil(vm.error)
    }
    
    // MARK: - CYNetworkError Tests
    
    func testNetworkErrorDescriptions() {
        XCTAssertFalse(CYNetworkError.invalidURL.localizedDescription.isEmpty)
        XCTAssertFalse(CYNetworkError.timeout.localizedDescription.isEmpty)
        XCTAssertFalse(CYNetworkError.noConnection.localizedDescription.isEmpty)
        XCTAssertFalse(CYNetworkError.unknown.localizedDescription.isEmpty)
    }
    
    func testNetworkErrorHelpers() {
        XCTAssertTrue(CYNetworkError.httpError(statusCode: 401, data: nil).isUnauthorized)
        XCTAssertFalse(CYNetworkError.httpError(statusCode: 403, data: nil).isUnauthorized)
        XCTAssertTrue(CYNetworkError.httpError(statusCode: 500, data: nil).isServerError)
        XCTAssertFalse(CYNetworkError.httpError(statusCode: 400, data: nil).isServerError)
        XCTAssertTrue(CYNetworkError.httpError(statusCode: 404, data: nil).statusCode == 404)
        XCTAssertTrue(CYNetworkError.businessError(code: 10001, message: "expired").businessCode == 10001)
    }
    
    // MARK: - CYAPIResponse Tests
    
    func testAPIResponseDecodeSuccess() throws {
        let json = """
        {"code": 0, "data": {"id": 1, "name": "John", "email": "john@example.com", "role": "user"}, "message": "ok"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(CYAPIResponse<User>.self, from: json)
        XCTAssertTrue(response.isSuccess)
        XCTAssertTrue(response.data?.name == "John")
    }
    
    func testAPIResponseDecodeBusinessError() throws {
        let json = """
        {"code": 10001, "data": null, "message": "token expired"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(CYAPIResponse<User>.self, from: json)
        XCTAssertFalse(response.isSuccess)
        XCTAssertNil(response.data)
        XCTAssertTrue(response.message == "token expired")
    }
    
    // MARK: - CYAppConstants Tests
    
    func testAppConstantsValues() {
        XCTAssertFalse(CYAppConstants.appName.isEmpty)
        XCTAssertTrue(CYAppConstants.timeoutInterval > 0)
        XCTAssertTrue(CYAppConstants.defaultPageSize > 0)
        XCTAssertTrue(CYAppConstants.maxRetryAttempts == 3)
    }
    
    // MARK: - CYDIContainer Tests
    
    func testAppContainerShared() {
        let container = CYAppContainer.shared
        XCTAssertNotNil(container.networkClient)
        XCTAssertNotNil(container.cacheManager)
        XCTAssertNotNil(container.logger)
        XCTAssertNotNil(container.appState)
    }
    
    @MainActor
    func testAuthServiceUsesContainerUserSession() async throws {
        let container = CYAppContainer.shared
        container.userSession.clear()
        
        let user = try await container.authService.login(username: "shared-session", password: "password")
        
        XCTAssertEqual(container.userSession.user?.id, user.id)
        XCTAssertEqual(container.userSession.user?.name, "shared-session")
        XCTAssertTrue(container.userSession.isLoggedIn)
        XCTAssertNotNil(container.userSession.accessToken)
    }
    
    // MARK: - CYAppState Tests
    
    @MainActor
    func testAppStateInitialState() {
        let state = CYAppState()
        XCTAssertNil(state.user)
        XCTAssertFalse(state.isLoggedIn)
        XCTAssertTrue(state.selectedTab == .home)
        XCTAssertTrue(state.theme == .system)
    }
    
    @MainActor
    func testAppStateSetUser() {
        let state = CYAppState()
        let user = User(id: 1, name: "Test", email: "test@example.com")
        state.setUser(user)
        XCTAssertNotNil(state.user)
        XCTAssertTrue(state.isLoggedIn)
        XCTAssertTrue(state.user?.name == "Test")
    }
    
    @MainActor
    func testAppStateLogout() {
        let state = CYAppState()
        let user = User(id: 1, name: "Test", email: nil)
        state.setUser(user)
        state.selectedTab = .profile
        state.logout()
        XCTAssertNil(state.user)
        XCTAssertFalse(state.isLoggedIn)
        XCTAssertTrue(state.selectedTab == .home)
    }
    
    @MainActor
    func testAppStateReset() {
        let state = CYAppState()
        state.setUser(User(id: 1, name: "Test", email: nil))
        state.selectedTab = .profile
        state.theme = .dark
        state.reset()
        XCTAssertNil(state.user)
        XCTAssertTrue(state.selectedTab == .home)
        XCTAssertTrue(state.theme == .system)
    }
    
    // MARK: - CYAppTab Tests
    
    func testAppTabProperties() {
        XCTAssertTrue(CYAppTab.home.icon == "house")
        XCTAssertTrue(CYAppTab.explore.icon == "safari")
        XCTAssertTrue(CYAppTab.profile.icon == "person")
        XCTAssertTrue(CYAppTab.allCases.count == 3)
    }
    
    // MARK: - CYAppTheme Tests
    
    func testAppThemeIsDarkMode() {
        XCTAssertNil(CYAppTheme.system.isDarkMode)
        XCTAssertFalse(CYAppTheme.light.isDarkMode ?? true)
        XCTAssertTrue(CYAppTheme.dark.isDarkMode ?? false)
    }
    
    // MARK: - User Model Tests
    
    func testUserCreation() {
        let user = User(id: 1, name: "John", email: "john@example.com", phone: "13800138000", avatarURL: "https://example.com/avatar.png", role: .vip)
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "John")
        XCTAssertEqual(user.email, "john@example.com")
        XCTAssertEqual(user.phone, "13800138000")
        XCTAssertEqual(user.avatarURL, "https://example.com/avatar.png")
        XCTAssertEqual(user.role, .vip)
    }
    
    func testUserDefaultValues() {
        let user = User(id: 2, name: "Jane")
        XCTAssertNil(user.email)
        XCTAssertNil(user.phone)
        XCTAssertNil(user.avatarURL)
        XCTAssertEqual(user.role, .user)
    }
    
    func testUserRoleProperties() {
        XCTAssertTrue(UserRole.admin.isStaff)
        XCTAssertFalse(UserRole.user.isStaff)
        XCTAssertFalse(UserRole.vip.isStaff)
        XCTAssertFalse(UserRole.user.displayName.isEmpty)
        XCTAssertFalse(UserRole.vip.displayName.isEmpty)
        XCTAssertFalse(UserRole.admin.displayName.isEmpty)
    }
    
    func testUserCodable() throws {
        let user = User(id: 1, name: "John", email: "john@example.com", role: .admin)
        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(User.self, from: data)
        XCTAssertEqual(decoded.id, user.id)
        XCTAssertEqual(decoded.name, user.name)
        XCTAssertEqual(decoded.email, user.email)
        XCTAssertEqual(decoded.role, user.role)
    }
    
    // MARK: - TokenPair Tests
    
    func testTokenPairCreation() {
        let token = TokenPair(accessToken: "access", refreshToken: "refresh")
        XCTAssertEqual(token.accessToken, "access")
        XCTAssertEqual(token.refreshToken, "refresh")
        XCTAssertNil(token.expiresAt)
    }
    
    func testTokenPairFromExpiresIn() {
        let token = TokenPair.from(expiresIn: 3600, accessToken: "a", refreshToken: "r")
        XCTAssertNotNil(token.expiresAt)
        let expected = Date().addingTimeInterval(3600)
        XCTAssertEqual(token.expiresAt!.timeIntervalSinceReferenceDate, expected.timeIntervalSinceReferenceDate, accuracy: 2.0)
    }
    
    // MARK: - UserSession Tests
    
    @MainActor
    func testUserSessionSaveUserWithToken() {
        let session = CYUserSession()
        let user = User(id: 1, name: "Test")
        let token = TokenPair(accessToken: "access_token", refreshToken: "refresh_token", expiresAt: Date().addingTimeInterval(3600))
        session.saveUser(user, token: token)
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertEqual(session.accessToken, "access_token")
        XCTAssertEqual(session.refreshToken, "refresh_token")
        XCTAssertFalse(session.isTokenExpired)
    }
    
    @MainActor
    func testUserSessionUpdateToken() {
        let session = CYUserSession()
        let user = User(id: 1, name: "Test")
        session.saveUser(user, token: TokenPair(accessToken: "old", refreshToken: "old_r"))
        let newToken = TokenPair(accessToken: "new", refreshToken: "new_r")
        session.updateToken(newToken)
        XCTAssertEqual(session.accessToken, "new")
        XCTAssertEqual(session.refreshToken, "new_r")
    }
    
    @MainActor
    func testUserSessionTokenExpired() {
        let session = CYUserSession()
        let user = User(id: 1, name: "Test")
        let expiredToken = TokenPair(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(-100))
        session.saveUser(user, token: expiredToken)
        XCTAssertTrue(session.isTokenExpired)
    }
    
    @MainActor
    func testUserSessionClear() {
        let session = CYUserSession()
        let user = User(id: 1, name: "Test")
        session.saveUser(user, token: TokenPair(accessToken: "a", refreshToken: "r"))
        session.clear()
        XCTAssertNil(session.user)
        XCTAssertNil(session.accessToken)
        XCTAssertNil(session.refreshToken)
        XCTAssertFalse(session.isLoggedIn)
    }
    
    // MARK: - FormValidator Tests
    
    func testFormFieldRequired() {
        let field = CYFormField(name: "姓名").required()
        XCTAssertNotNil(field.validate(""))
        XCTAssertNotNil(field.validate("   "))
        XCTAssertNil(field.validate("张三"))
    }
    
    func testFormFieldMinLength() {
        let field = CYFormField(name: "密码").minLength(6)
        XCTAssertNotNil(field.validate("12345"))
        XCTAssertNil(field.validate("123456"))
        XCTAssertNil(field.validate("1234567"))
    }
    
    func testFormFieldMaxLength() {
        let field = CYFormField(name: "昵称").maxLength(10)
        XCTAssertNil(field.validate("hello"))
        XCTAssertNil(field.validate("1234567890"))
        XCTAssertNotNil(field.validate("12345678901"))
    }
    
    func testFormFieldEmail() {
        let field = CYFormField(name: "邮箱").email()
        XCTAssertNil(field.validate("test@example.com"))
        XCTAssertNotNil(field.validate("invalid-email"))
        XCTAssertNotNil(field.validate("@missing.com"))
    }
    
    func testFormFieldPhone() {
        let field = CYFormField(name: "手机号").phone()
        XCTAssertNil(field.validate("13800138000"))
        XCTAssertNotNil(field.validate("12345"))
        XCTAssertNotNil(field.validate("abcdefghijk"))
    }
    
    func testFormFieldContainsDigit() {
        let field = CYFormField(name: "密码").containsDigit()
        XCTAssertNil(field.validate("abc123"))
        XCTAssertNotNil(field.validate("abcdef"))
    }
    
    func testFormFieldContainsLetter() {
        let field = CYFormField(name: "密码").containsLetter()
        XCTAssertNil(field.validate("123abc"))
        XCTAssertNotNil(field.validate("123456"))
    }
    
    func testFormFieldContainsUppercase() {
        let field = CYFormField(name: "密码").containsUppercase()
        XCTAssertNil(field.validate("abcDef"))
        XCTAssertNotNil(field.validate("abcdef"))
    }
    
    func testFormFieldChainedRules() {
        let field = CYFormField(name: "密码")
            .required()
            .minLength(8)
            .containsDigit()
            .containsLetter()
            .containsUppercase()
        XCTAssertNotNil(field.validate(""))
        XCTAssertNotNil(field.validate("abc"))
        XCTAssertNotNil(field.validate("abcdefgh"))
        XCTAssertNotNil(field.validate("12345678"))
        XCTAssertNotNil(field.validate("abcd1234"))
        XCTAssertNil(field.validate("Abcd1234"))
    }
    
    func testFormFieldMatch() {
        let field = CYFormField(name: "确认密码").match("password123")
        XCTAssertNil(field.validate("password123"))
        XCTAssertNotNil(field.validate("different"))
    }
    
    func testFormFieldCustomRegex() {
        let field = CYFormField(name: "编号").regex("^\\d{6}$", message: "请输入6位数字编号")
        XCTAssertNil(field.validate("123456"))
        XCTAssertNotNil(field.validate("12345"))
        XCTAssertNotNil(field.validate("abcdef"))
    }
    
    func testFormValidatorValidateAll() {
        let validator = CYFormValidator([
            .init(key: "email", field: CYFormField(name: "邮箱").required().email()),
            .init(key: "password", field: CYFormField(name: "密码").required().minLength(8)),
        ])
        let validValues = ["email": "test@example.com", "password": "12345678"]
        let results = validator.validateAll(validValues)
        XCTAssertNil(results["email"]!)
        XCTAssertNil(results["password"]!)
        let invalidValues = ["email": "", "password": "123"]
        let invalidResults = validator.validateAll(invalidValues)
        XCTAssertNotNil(invalidResults["email"]!)
        XCTAssertNotNil(invalidResults["password"]!)
    }
    
    func testFormValidatorIsAllValid() {
        let validator = CYFormValidator([
            .init(key: "email", field: CYFormField(name: "邮箱").required().email()),
            .init(key: "password", field: CYFormField(name: "密码").required().minLength(8)),
        ])
        XCTAssertTrue(validator.isAllValid(["email": "a@b.com", "password": "12345678"]))
        XCTAssertFalse(validator.isAllValid(["email": "", "password": "12345678"]))
        XCTAssertFalse(validator.isAllValid(["email": "a@b.com", "password": "123"]))
    }
    
    func testFormValidatorFirstError() {
        let validator = CYFormValidator([
            .init(key: "email", field: CYFormField(name: "邮箱").required()),
            .init(key: "password", field: CYFormField(name: "密码").required()),
        ])
        let error = validator.firstError(["email": "", "password": ""])
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.key, "email")
        let noError = validator.firstError(["email": "a@b.com", "password": "123"])
        XCTAssertNil(noError)
    }
    
    // MARK: - PaginatedListViewModel Tests
    
    @MainActor
    func testPaginatedViewModelInitialState() {
        let vm = TestPaginatedViewModel()
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertTrue(vm.hasMore)
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertEqual(vm.currentPage, 1)
        XCTAssertTrue(vm.isEmpty)
    }
    
    @MainActor
    func testPaginatedViewModelLoad() async {
        let vm = TestPaginatedViewModel()
        vm.mockData = (1...10).map { TestItem(id: $0) }
        await vm.load()
        XCTAssertEqual(vm.items.count, 10)
        XCTAssertEqual(vm.currentPage, 1)
        XCTAssertFalse(vm.isLoading)
    }
    
    @MainActor
    func testPaginatedViewModelLoadMore() async {
        let vm = TestPaginatedViewModel(pageSize: 10)
        vm.mockData = (1...10).map { TestItem(id: $0) }
        await vm.load()
        XCTAssertEqual(vm.items.count, 10)
        XCTAssertTrue(vm.hasMore) // 10 >= pageSize(10) → hasMore = true
        vm.mockData = (11...15).map { TestItem(id: $0) }
        await vm.loadMore()
        XCTAssertEqual(vm.items.count, 15)
        XCTAssertEqual(vm.currentPage, 2)
    }
    
    @MainActor
    func testPaginatedViewModelRefresh() async {
        let vm = TestPaginatedViewModel()
        vm.mockData = (1...5).map { TestItem(id: $0) }
        await vm.load()
        XCTAssertEqual(vm.items.count, 5)
        vm.mockData = (10...20).map { TestItem(id: $0) }
        await vm.refresh()
        XCTAssertEqual(vm.items.count, 11)
        XCTAssertEqual(vm.currentPage, 1)
    }
    
    @MainActor
    func testPaginatedViewModelHasMore() async {
        let vm = TestPaginatedViewModel()
        vm.pageSize = 5
        vm.mockData = (1...3).map { TestItem(id: $0) }
        await vm.load()
        XCTAssertFalse(vm.hasMore)
    }
    
    @MainActor
    func testPaginatedViewModelAppendPrepend() {
        let vm = TestPaginatedViewModel()
        vm.items = [TestItem(id: 2), TestItem(id: 3)]
        vm.prepend(TestItem(id: 1))
        XCTAssertEqual(vm.items.first?.id, 1)
        vm.append(TestItem(id: 4))
        XCTAssertEqual(vm.items.last?.id, 4)
    }
    
    @MainActor
    func testPaginatedViewModelRemove() {
        let vm = TestPaginatedViewModel()
        vm.items = [TestItem(id: 1), TestItem(id: 2), TestItem(id: 3)]
        vm.remove(at: 1)
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertEqual(vm.items[0].id, 1)
        XCTAssertEqual(vm.items[1].id, 3)
    }
    
    @MainActor
    func testPaginatedViewModelRemoveByCondition() {
        let vm = TestPaginatedViewModel()
        vm.items = [TestItem(id: 1), TestItem(id: 2), TestItem(id: 3)]
        vm.remove { $0.id == 2 }
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertNil(vm.items.first { $0.id == 2 })
    }
    
    @MainActor
    func testPaginatedViewModelUpdate() {
        let vm = TestPaginatedViewModel()
        vm.items = [TestItem(id: 1), TestItem(id: 2)]
        vm.update(TestItem(id: 99), where: { $0.id == 2 })
        XCTAssertEqual(vm.items[1].id, 99)
    }
}

// MARK: - Test Helpers

struct TestItem: Identifiable, Sendable {
    let id: Int
}

@MainActor
@Observable
final class TestPaginatedViewModel: CYPaginatedListViewModel<TestItem> {
    var mockData: [TestItem] = []
    
    override func fetchPage(page: Int, pageSize: Int) async throws -> [TestItem] {
        return mockData
    }
}
