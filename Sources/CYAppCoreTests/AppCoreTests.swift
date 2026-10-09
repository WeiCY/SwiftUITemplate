import XCTest
@testable import CYAppCore

private struct TestPayload: Codable, Sendable {
    let id: Int
    let name: String
}

final class AppCoreTests: XCTestCase {

    func testCoreBootstrapAppliesConfiguration() {
        let original = CYAppConstants.configuration
        defer { CYAppConstants.configure(original) }

        let values = CYAppConfigurationValues(
            cacheDirectoryName: "BootstrapCache",
            keychainService: "com.example.bootstrap",
            defaultPageSize: 42
        )
        CYCoreBootstrap.configure(CYAppConfig(
            environment: .development,
            values: values,
            minimumLogLevel: .warning
        ))

        XCTAssertEqual(CYAppConstants.cacheDirectoryName, "BootstrapCache")
        XCTAssertEqual(CYAppConstants.keychainService, "com.example.bootstrap")
        XCTAssertEqual(CYAppConstants.defaultPageSize, 42)
    }
    
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
    
    func testAppErrorResolveCancelledFromNetworkError() {
        let resolved = CYAppError.resolve(CYNetworkError.cancelled)
        XCTAssertTrue(resolved.isCancellation)
        if case .cancelled = resolved {
        } else {
            XCTFail("Expected .cancelled, got \(resolved)")
        }
    }
    
    func testAppErrorResolveCancelledFromCancellationError() {
        let resolved = CYAppError.resolve(CancellationError())
        XCTAssertTrue(resolved.isCancellation)
        if case .cancelled = resolved {
        } else {
            XCTFail("Expected .cancelled, got \(resolved)")
        }
    }
    
    func testAppErrorResolveUnknown() {
        struct CustomError: Error {}
        let resolved = CYAppError.resolve(CustomError())
        if case .unknown = resolved {
        } else {
            XCTFail("Expected .unknown, got \(resolved)")
        }
    }
    
    // MARK: - CYToastManager Tests

    @MainActor
    func testToastReplaceAndIgnoreEmptyMessage() async {
        let manager = CYToastManager()
        manager.show("   ")
        XCTAssertFalse(manager.isPresented)

        manager.show("First", type: .info, duration: 0.1)
        let firstID = manager.presentationID
        manager.show("Second", type: .success, duration: 0.2)

        XCTAssertTrue(manager.isPresented)
        XCTAssertEqual(manager.message, "Second")
        XCTAssertEqual(manager.type, .success)
        XCTAssertNotEqual(manager.presentationID, firstID)

        // CI runners may resume suspended tasks slightly later than requested.
        // Keep the assertion comfortably before the second toast's 200 ms expiry.
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(manager.isPresented)
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertFalse(manager.isPresented)
        XCTAssertNil(manager.message)
    }

    @MainActor
    func testToastQueueAndDismissAll() {
        let manager = CYToastManager()
        manager.queueMode = .queue
        manager.show("First", duration: 10)
        manager.show("Second", duration: 10)

        XCTAssertEqual(manager.message, "First")
        XCTAssertEqual(manager.queueCount, 1)

        manager.dismiss()
        XCTAssertEqual(manager.message, "Second")
        XCTAssertEqual(manager.queueCount, 0)

        manager.dismissAll()
        XCTAssertFalse(manager.isPresented)
        XCTAssertNil(manager.message)
    }

    @MainActor
    func testToastQueueLimitDropsOldest() {
        let manager = CYToastManager()
        manager.queueMode = .queue
        manager.maxQueueSize = 1
        manager.show("First", duration: 10)
        manager.show("Second", duration: 10)
        manager.show("Third", duration: 10)

        XCTAssertEqual(manager.message, "First")
        XCTAssertEqual(manager.queueCount, 1)

        manager.dismiss()
        XCTAssertEqual(manager.message, "Third")
        XCTAssertEqual(manager.queueCount, 0)
    }

    // MARK: - CYAlertManager Tests

    @MainActor
    func testAlertManagerQueuesAlerts() async {
        let manager = CYAlertManager()
        manager.showAlert(title: "First", message: "Message 1")
        manager.showAlert(title: "Second", message: "Message 2")

        XCTAssertEqual(manager.title, "First")
        XCTAssertEqual(manager.queueCount, 1)

        manager.dismiss()
        XCTAssertFalse(manager.isPresented)
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(manager.title, "Second")
        XCTAssertEqual(manager.queueCount, 0)
    }

    // MARK: - CYLoadingManager Tests

    @MainActor
    func testLoadingShowAndHide() {
        let manager = CYLoadingManager()
        manager.show("Loading")
        XCTAssertTrue(manager.isLoading)
        XCTAssertEqual(manager.message, "Loading")

        manager.hide()
        XCTAssertFalse(manager.isLoading)
        XCTAssertNil(manager.message)
    }

    // MARK: - CYAppEnvironment Tests
    
    func testAppEnvironmentCurrent() {
        let env = CYAppEnvironment.current
        XCTAssertTrue(CYAppEnvironment.allCases.contains(env))
        XCTAssertNotNil(env.featureFlags)
    }
    
    func testAppEnvironmentFeatureFlags() {
        #if DEBUG
        XCTAssertTrue(CYAppEnvironment.development.featureFlags.enableDebugMenu)
        XCTAssertFalse(CYAppEnvironment.production.featureFlags.enableDebugMenu)
        #endif
    }
    
    // MARK: - CYCacheManager Tests
    
    func testCacheManagerSaveAndLoad() async {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }

        let testValue = "hello_cache"
        let result = await cache.save(value: testValue, forKey: "test_key", namespace: "UnitTest")
        XCTAssertNoThrow(try result.get())
        let loaded: String? = await cache.load(forKey: "test_key", namespace: "UnitTest")
        XCTAssertTrue(loaded == testValue)
        let clearResult = await cache.clear(namespace: "UnitTest")
        XCTAssertNoThrow(try clearResult.get())
    }
    
    func testCacheManagerRemove() async {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }

        let saveResult = await cache.save(value: 42, forKey: "num_key", namespace: "UnitTest")
        XCTAssertNoThrow(try saveResult.get())
        let removeResult = await cache.remove(forKey: "num_key", namespace: "UnitTest")
        XCTAssertNoThrow(try removeResult.get())
        let loaded: Int? = await cache.load(forKey: "num_key", namespace: "UnitTest")
        XCTAssertNil(loaded)
    }
    
    func testCacheManagerTTLExpiration() async {
        let (cache, base) = TestCacheFactory.makeTempCache()
        defer { try? FileManager.default.removeItem(at: base) }

        let saveResult = await cache.save(value: "expired", forKey: "ttl_key", namespace: "UnitTest", ttl: 0)
        XCTAssertNoThrow(try saveResult.get())
        try? await Task.sleep(nanoseconds: 100_000_000)
        let loaded: String? = await cache.load(forKey: "ttl_key", namespace: "UnitTest")
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
    func testBaseViewModelExecuteTaskIgnoresCancellation() async {
        let vm = CYBaseViewModel()
        await vm.executeTask { throw CYNetworkError.cancelled }
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.hasError, "请求取消不应展示错误")
        XCTAssertNil(vm.error)
        XCTAssertNil(vm.errorMessage)
    }
    
    @MainActor
    func testBaseViewModelExecuteTaskIgnoresCancellationError() async {
        let vm = CYBaseViewModel()
        await vm.executeTask { throw CancellationError() }
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.hasError, "CancellationError 不应展示错误")
        XCTAssertNil(vm.error)
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
        XCTAssertTrue(CYNetworkError.cancelled.isCancellation)
        XCTAssertFalse(CYNetworkError.unknown.isCancellation)
        XCTAssertEqual(CYNetworkError.cancelled.displayKind, .silent)
    }
    
    // MARK: - CYAPIResponse Tests
    
    func testAPIResponseDecodeSuccess() throws {
        let json = Data("""
        {"code": 0, "data": {"id": 1, "name": "John", "email": "john@example.com", "role": "user"}, "message": "ok"}
        """.utf8)
        let response = try JSONDecoder().decode(CYAPIResponse<TestPayload>.self, from: json)
        XCTAssertTrue(response.isSuccess)
        XCTAssertTrue(response.data?.name == "John")
    }
    
    func testAPIResponseDecodeBusinessError() throws {
        let json = Data("""
        {"code": 10001, "data": null, "message": "token expired"}
        """.utf8)
        let response = try JSONDecoder().decode(CYAPIResponse<TestPayload>.self, from: json)
        XCTAssertFalse(response.isSuccess)
        XCTAssertNil(response.data)
        XCTAssertTrue(response.message == "token expired")
    }
    
    func testAPIResponseMalformedDataThrowsInsteadOfSilentlyNil() throws {
        // data 字段存在但类型与模型不匹配时，应抛出真实的 DecodingError，
        // 而不是被吞成 "data 为 nil"。
        let json = Data("""
        {"code": 0, "data": {"id": "not-an-int", "name": "John", "role": "user"}, "message": "ok"}
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CYAPIResponse<TestPayload>.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError, "应抛出 DecodingError，实际 \(error)")
        }
    }
    
    func testAPIResponseMalformedMessageThrows() throws {
        let json = Data(#"{"code": 0, "data": null, "message": 123}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CYAPIResponse<Int>.self, from: json))
    }
    
    // MARK: - CYAppConstants Tests
    
    func testAppConstantsValues() {
        XCTAssertTrue(CYAppConstants.defaultPageSize > 0)
        XCTAssertTrue(CYAppConstants.maxUploadSizeMB > 0)
    }

    func testAppConstantsConfiguration() {
        let original = CYAppConstants.configuration
        defer { CYAppConstants.configure(original) }

        CYAppConstants.configure(CYAppConfigurationValues(
            cacheDirectoryName: "UnitTestCache",
            keychainService: "com.example.tests",
            defaultPageSize: 50,
            maxUploadSizeMB: 25
        ))

        XCTAssertEqual(CYAppConstants.cacheDirectoryName, "UnitTestCache")
        XCTAssertEqual(CYAppConstants.keychainService, "com.example.tests")
        XCTAssertEqual(CYAppConstants.defaultPageSize, 50)
        XCTAssertEqual(CYAppConstants.maxUploadSizeMB, 25)
    }
    
    // MARK: - CYDIContainer Tests
    
    func testAppContainerShared() {
        let container = CYAppContainer.shared
        XCTAssertNotNil(container.cacheManager)
        XCTAssertNotNil(container.logger)
    }

    func testNetworkCapabilityIsSeparatedFromBaseDI() {
        // 基础容器协议不要求网络能力
        let base: any DIContainerProtocol = CYAppContainer.shared
        XCTAssertNotNil(base.cacheManager)

        // 容器可选地同时提供网络能力，供网络 Feature 组合依赖
        let networkCapable: any DIContainerProtocol & NetworkProviding = CYAppContainer.shared
        XCTAssertTrue(networkCapable is CYAppContainer)
    }
    
    // MARK: - CYTabID Tests

    func testTabIdentifier() {
        let home: CYTabID = "home"
        XCTAssertEqual(home.rawValue, "home")
    }
}

extension AppCoreTests {

    // MARK: - CYAppTheme Tests
    
    func testAppThemeIsDarkMode() {
        XCTAssertNil(CYAppTheme.system.isDarkMode)
        XCTAssertFalse(CYAppTheme.light.isDarkMode ?? true)
        XCTAssertTrue(CYAppTheme.dark.isDarkMode ?? false)
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
            .init(key: "password", field: CYFormField(name: "密码").required().minLength(8))
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
            .init(key: "password", field: CYFormField(name: "密码").required().minLength(8))
        ])
        XCTAssertTrue(validator.isAllValid(["email": "a@b.com", "password": "12345678"]))
        XCTAssertFalse(validator.isAllValid(["email": "", "password": "12345678"]))
        XCTAssertFalse(validator.isAllValid(["email": "a@b.com", "password": "123"]))
    }
    
    func testFormValidatorFirstError() {
        let validator = CYFormValidator([
            .init(key: "email", field: CYFormField(name: "邮箱").required()),
            .init(key: "password", field: CYFormField(name: "密码").required())
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

/// 为缓存测试创建「临时目录 + 独立实例」的组合，避免：
/// 1. 写入系统 `~/Library/Caches` 受 macOS TCC / 沙箱限制而失败；
/// 2. 使用 `.shared` 单例导致测试之间、测试与应用之间相互污染。
enum TestCacheFactory {
    static func makeTempCache(directoryName: String = "cache") -> (CYCacheManager, URL) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("CYCacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return (CYCacheManager(directoryName: directoryName, baseDirectory: base), base)
    }
}

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
