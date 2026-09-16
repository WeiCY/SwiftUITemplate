import XCTest
import Foundation
@testable import CYAppNetwork
@testable import CYAppCore

private actor Counter {
    var value = 0
    func increment() -> Int {
        value += 1
        return value
    }
}

/// 凭证恢复测试用端点。
private struct RefreshTestEndpoint: CYEndpoint {
    let path = "/test"
    var method: CYHTTPMethod { .get }
    var authentication: CYAuthenticationPolicy { .required }
}

final class NetworkClientTests: XCTestCase {

    // MARK: - 刷新成功，重放成功

    func testRefreshAndRetrySucceeds() async throws {
        let client = CYNetworkClient(baseURL: "https://api.example.com")
        client.setCredentialRecovery(CYCredentialRecovery(action: { true }))

        let counter = Counter()
        let result: String = try await client.performRequest(RefreshTestEndpoint()) {
            let callIndex = await counter.increment()
            if callIndex == 1 {
                throw CYNetworkError.httpError(statusCode: 401, data: nil)
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        let finalCount = await counter.value
        XCTAssertEqual(finalCount, 2)
    }

    // MARK: - 未设置刷新协调器，直接抛出原错误，不重试

    func testNoRefreshCoordinatorThrowsWithoutRetry() async {
        let client = CYNetworkClient(baseURL: "https://api.example.com")

        let counter = Counter()
        do {
            let _: String = try await client.performRequest(RefreshTestEndpoint()) {
                _ = await counter.increment()
                throw CYNetworkError.httpError(statusCode: 401, data: nil)
            }
            XCTFail("Expected error")
        } catch {
            guard let networkError = error as? CYNetworkError else {
                XCTFail("Expected CYNetworkError")
                return
            }
            XCTAssertTrue(networkError.isUnauthorized)
        }

        let count = await counter.value
        XCTAssertEqual(count, 1)
    }

    // MARK: - 刷新失败，抛出原错误，不重试

    func testRefreshFailureThrowsWithoutRetry() async {
        let client = CYNetworkClient(baseURL: "https://api.example.com")
        client.setCredentialRecovery(CYCredentialRecovery(action: { throw CYNetworkError.invalidURL }))

        let counter = Counter()
        do {
            let _: String = try await client.performRequest(RefreshTestEndpoint()) {
                _ = await counter.increment()
                throw CYNetworkError.httpError(statusCode: 401, data: nil)
            }
            XCTFail("Expected error")
        } catch {
            guard let networkError = error as? CYNetworkError else {
                XCTFail("Expected CYNetworkError")
                return
            }
            XCTAssertTrue(networkError.isUnauthorized)
        }

        let count = await counter.value
        XCTAssertEqual(count, 1)
    }

    // MARK: - 刷新成功但重放仍 401，不再循环

    func testRefreshSuccessButReplayStill401DoesNotLoop() async {
        let client = CYNetworkClient(baseURL: "https://api.example.com")
        client.setCredentialRecovery(CYCredentialRecovery(action: { true }))

        let counter = Counter()
        do {
            let _: String = try await client.performRequest(RefreshTestEndpoint()) {
                _ = await counter.increment()
                throw CYNetworkError.httpError(statusCode: 401, data: nil)
            }
            XCTFail("Expected error")
        } catch {
            guard let networkError = error as? CYNetworkError else {
                XCTFail("Expected CYNetworkError")
                return
            }
            XCTAssertTrue(networkError.isUnauthorized)
        }

        let finalCount = await counter.value
        XCTAssertEqual(finalCount, 2)
    }

    // MARK: - 普通业务错误不触发刷新

    func testBusinessErrorDoesNotTriggerRefresh() async {
        let client = CYNetworkClient(baseURL: "https://api.example.com")
        client.setCredentialRecovery(CYCredentialRecovery(action: { true }))

        let counter = Counter()
        do {
            let _: String = try await client.performRequest(RefreshTestEndpoint()) {
                _ = await counter.increment()
                throw CYNetworkError.businessError(code: 500, message: "server error")
            }
            XCTFail("Expected error")
        } catch {
            guard let networkError = error as? CYNetworkError else {
                XCTFail("Expected CYNetworkError")
                return
            }
            if case .businessError(let code, _) = networkError {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected businessError, got \(networkError)")
            }
        }

        let count = await counter.value
        XCTAssertEqual(count, 1)
    }
}
