import CYTestSupport
import Alamofire
import Foundation
import XCTest
import CYAppCore
@testable import CYAppNetwork

private final class ReviewURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let empty = request.url?.path.hasPrefix("/empty") == true
        let status = request.url?.path == "/empty205" ? 205 : (empty ? 204 : 200)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: empty ? Data() : Data("{\"code\":0,\"data\":{}}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private struct ReviewNetworkEndpoint: CYEndpoint {
    let path: String
    var authentication: CYAuthenticationPolicy = .none
    var method: CYHTTPMethod { .delete }
}

private actor ReviewCounter {
    var value = 0
    func increment() { value += 1 }
}

private struct ReviewThrowingInterceptor: CYResponseInterceptor {
    let counter: ReviewCounter
    var error: CYNetworkError = .businessError(code: 42, message: "interceptor rejected")
    func intercept(_ response: URLResponse?, data: Data?) async throws {
        await counter.increment()
        throw error
    }
}

final class TemplateReviewNetworkRegressionTests: XCTestCase {
    private func makeClient(interceptors: [any CYResponseInterceptor] = []) -> CYNetworkClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ReviewURLProtocol.self]
        return CYNetworkClient(baseURL: "https://review.test", responseInterceptors: interceptors, session: Session(configuration: config))
    }

    @MainActor
    func testNoContentWorksWithCustomSuccessCode() async throws {
        let globalState = CYGlobalTestState()
        defer { globalState.restore() }
        let original = CYBusinessCodePolicy.shared.withLock { $0 }
        defer { CYBusinessCodePolicy.shared.withLock { $0 = original } }
        CYBusinessCodePolicy.configure { $0.successCodes = [200] }
        try await makeClient().requestVoid(ReviewNetworkEndpoint(path: "/empty"))
        try await makeClient().requestVoid(ReviewNetworkEndpoint(path: "/empty205"))
    }

    func testThrowingResponseInterceptorRunsOnce() async {
        let counter = ReviewCounter()
        do {
            let _: CYEmptyResponse = try await makeClient(interceptors: [ReviewThrowingInterceptor(counter: counter)])
                .request(ReviewNetworkEndpoint(path: "/payload"))
            XCTFail("Expected interceptor error")
        } catch let error as CYNetworkError {
            guard case .businessError(let code, _) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(code, 42)
        } catch {
            XCTFail("Interceptor error should remain unwrapped: \(error)")
        }
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }

    func testInterceptorAuthenticationErrorDoesNotReplaySuccessfulRequest() async {
        let counter = ReviewCounter()
        let recoveryCounter = ReviewCounter()
        let client = makeClient(interceptors: [ReviewThrowingInterceptor(counter: counter, error: .tokenExpired(code: 401, message: "rejected"))])
        client.setCredentialRecovery(CYCredentialRecovery(action: {
            await recoveryCounter.increment()
            return true
        }))
        do {
            let _: CYEmptyResponse = try await client.request(ReviewNetworkEndpoint(path: "/payload", authentication: .required))
            XCTFail("Expected interceptor rejection")
        } catch let error as CYNetworkError {
            guard case .tokenExpired = error else { return XCTFail("Unexpected error: \(error)") }
        } catch { XCTFail("Unexpected error: \(error)") }
        let recoveries = await recoveryCounter.value
        let interceptions = await counter.value
        XCTAssertEqual(recoveries, 0)
        XCTAssertEqual(interceptions, 1)
    }

    func testDownloadPropagatesSuccessfulResponseInterceptorError() async {
        let counter = ReviewCounter()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        do {
            _ = try await makeClient(interceptors: [ReviewThrowingInterceptor(counter: counter)])
                .download(ReviewNetworkEndpoint(path: "/file"), to: destination)
            XCTFail("Expected interceptor rejection")
        } catch let error as CYNetworkError {
            guard case .businessError(let code, _) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(code, 42)
        } catch { XCTFail("Unexpected error: \(error)") }
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }
}
