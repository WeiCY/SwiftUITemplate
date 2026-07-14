import XCTest
import os
@testable import CYAppCore

// MARK: - 高优先级补充测试
//
// 覆盖历史 review 中标记为「高风险、零单测」的模块：
// Token 刷新并发单飞、CYEndpoint 默认 snake_case 策略、CacheManager 清命名空间同步清内存、分页刷新保留旧数据。

final class HighPriorityTests: XCTestCase {

    // MARK: - Token 刷新并发单飞（P0 #9 核心）

    func testTokenRefreshCoordinatorSingleFlight() async {
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let interceptor = CYTokenRefreshInterceptor(
            refreshTokenProvider: { "refresh" },
            onTokenRefreshed: { _ in },
            refreshAction: { _ in
                counter.withLock { $0 += 1 }
                // 模拟刷新耗时，制造并发窗口
                try? await Task.sleep(nanoseconds: 50_000_000)
                return TokenPair(accessToken: "a", refreshToken: "r")
            },
            onRefreshFailed: {}
        )
        let coordinator = CYTokenRefreshCoordinator(interceptor: interceptor)

        await withTaskGroup(of: TokenPair?.self) { group in
            for _ in 0..<10 {
                group.addTask { await coordinator.refreshIfNeeded() }
            }
            var results = 0
            for await _ in group { results += 1 }
            XCTAssertEqual(results, 10)
        }

        // 10 个并发请求只应触发一次刷新
        XCTAssertEqual(counter.withLock { $0 }, 1, "并发 401 应只刷新一次")
    }

    func testTokenRefreshCoordinatorNoRefreshToken() async {
        let interceptor = CYTokenRefreshInterceptor(
            refreshTokenProvider: { nil },
            onTokenRefreshed: { _ in },
            refreshAction: { _ in
                XCTFail("无 refreshToken 不应调用刷新")
                return TokenPair(accessToken: "a", refreshToken: "r")
            },
            onRefreshFailed: {}
        )
        let coordinator = CYTokenRefreshCoordinator(interceptor: interceptor)
        let result = await coordinator.refreshIfNeeded()
        XCTAssertNil(result, "无 refreshToken 时刷新应返回 nil")
    }

    // MARK: - CYEndpoint 默认 snake_case 策略（P0 #10）

    private struct SampleEndpoint: CYEndpoint {
        var path: String = "/x"
        var method: CYHTTPMethod = .get
    }

    func testEndpointDefaultSnakeCaseStrategy() {
        let endpoint = SampleEndpoint()
        switch endpoint.keyDecodingStrategy {
        case .convertFromSnakeCase: break
        default: XCTFail("默认 keyDecodingStrategy 应为 convertFromSnakeCase")
        }
        switch endpoint.keyEncodingStrategy {
        case .convertToSnakeCase: break
        default: XCTFail("默认 keyEncodingStrategy 应为 convertToSnakeCase")
        }
    }

    // MARK: - CacheManager 清命名空间同步清内存（P0 #3）

    func testCacheManagerClearNamespaceClearsMemory() {
        let cache = CYCacheManager()
        defer { cache.clear() }

        cache.save(value: "value", forKey: "k", namespace: "Ns")
        let loaded: String? = cache.load(forKey: "k", namespace: "Ns")
        XCTAssertEqual(loaded, "value")

        cache.clear(namespace: "Ns")

        let after: String? = cache.load(forKey: "k", namespace: "Ns")
        XCTAssertNil(after, "clear(namespace:) 应同步清掉内存缓存")
    }

    // MARK: - 分页刷新保留旧数据（P1 #10）

    private struct RowItem: Identifiable, Sendable {
        let id: Int
    }

    private final class FailingPageVM: CYPaginatedListViewModel<RowItem> {
        var firstLoaded = false
        override func fetchPage(page: Int, pageSize: Int) async throws -> [RowItem] {
            if page == 1 && !firstLoaded {
                firstLoaded = true
                return [RowItem(id: 1), RowItem(id: 2)]
            }
            throw NSError(domain: "test", code: 500)
        }
    }

    @MainActor
    func testPaginatedRefreshKeepsOldDataOnFailure() async {
        let vm = FailingPageVM()
        await vm.refresh() // 成功加载旧数据
        XCTAssertEqual(vm.items.count, 2)

        vm.hasMore = true
        await vm.refresh() // 这次 fetchPage 抛错
        XCTAssertEqual(vm.items.count, 2, "刷新失败应保留旧数据，而非清空")
    }

    // MARK: - 业务码策略（P0：自定义 code 统一判定）

    func testBusinessCodePolicyClassifyDefault() {
        let p = CYBusinessCodePolicy.default
        if case .success = p.classify(0, message: nil) {} else { XCTFail("0 应为成功") }
        if case .success = p.classify(200, message: nil) {} else { XCTFail("200 应为成功") }
        if case .tokenExpired(let c, _) = p.classify(10001, message: "x") { XCTAssertEqual(c, 10001) }
        else { XCTFail("10001 应为 tokenExpired") }
        if case .needReLogin(let c, _) = p.classify(10003, message: "y") { XCTAssertEqual(c, 10003) }
        else { XCTFail("10003 应为 needReLogin") }
        if case .businessError(_, _, let display) = p.classify(500, message: nil) {
            XCTAssertEqual(display, .toast)
        } else { XCTFail("普通错误默认应为 toast") }
    }

    func testBusinessCodePolicyCustomAlertAndSilent() {
        var p = CYBusinessCodePolicy.default
        p.alertCodes = [50000]
        p.silentCodes = [90001]
        if case .businessError(_, _, let d) = p.classify(50000, message: nil) { XCTAssertEqual(d, .alert) }
        else { XCTFail("50000 应 alert") }
        if case .businessError(_, _, let d) = p.classify(90001, message: nil) { XCTAssertEqual(d, .silent) }
        else { XCTFail("90001 应 silent") }
        XCTAssertEqual(p.display(for: 50000), .alert)
        XCTAssertEqual(p.display(for: 90001), .silent)
    }

    func testAPIResponseBusinessResultFromJSON() {
        let json = #"{"code":10001,"message":"expired"}"#.data(using: .utf8)!
        let resp = try? JSONDecoder().decode(CYAPIResponse<Int>.self, from: json)
        XCTAssertNotNil(resp)
        if let resp {
            if case .tokenExpired = resp.businessResult {} else { XCTFail("应为 tokenExpired") }
            XCTAssertFalse(resp.isSuccess)
        }
    }

    func testNetworkErrorRequiresTokenRefresh() {
        XCTAssertTrue(CYNetworkError.tokenExpired(code: 10001, message: "x").requiresTokenRefresh)
        XCTAssertTrue(CYNetworkError.httpError(statusCode: 401, data: nil).requiresTokenRefresh)
        XCTAssertFalse(CYNetworkError.businessError(code: 500, message: "x").requiresTokenRefresh)
    }

    func testNetworkErrorDisplayKind() {
        var p = CYBusinessCodePolicy.default
        p.alertCodes = [50000]
        p.silentCodes = [90001]
        CYBusinessCodePolicy.shared = p
        defer { CYBusinessCodePolicy.shared = .default }
        XCTAssertEqual(CYNetworkError.businessError(code: 50000, message: "x").displayKind, .alert)
        XCTAssertEqual(CYNetworkError.businessError(code: 90001, message: "x").displayKind, .silent)
        XCTAssertEqual(CYNetworkError.businessError(code: 123, message: "x").displayKind, .toast)
    }
}
