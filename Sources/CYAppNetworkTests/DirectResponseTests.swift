import Foundation
import Synchronization
import XCTest
import CYAppCore
@testable import CYAppNetwork

private struct DirectValue: Codable, Sendable { let name: String }
private struct DirectEndpoint: CYEndpoint {
    let path = "/resource"
    var method: CYHTTPMethod = .get
    var authentication: CYAuthenticationPolicy = .required
    var timeoutInterval: TimeInterval? = 150
}

final class DirectResponseTests: XCTestCase {
    override func tearDown() { DirectURLProtocol.handler.withLock { $0 = nil } }

    private func makeClient(interceptors: [any CYRequestInterceptor] = [], responses: [any CYResponseInterceptor] = []) -> CYNetworkClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DirectURLProtocol.self]
        return CYNetworkClient(baseURL: "https://direct.example.test", requestInterceptors: interceptors,
                               responseInterceptors: responses, sessionConfiguration: configuration)
    }

    func testDirectJSONRecovers401AndReappliesCredentials() async throws {
        let state = Mutex((requests: 0, recoveries: 0, credential: "old"))
        DirectURLProtocol.handler.withLock { handler in
            handler = { request in
                let attempt = state.withLock { $0.requests += 1; return $0.requests }
                XCTAssertEqual(request.timeoutInterval, 150)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), attempt == 1 ? "Bearer old" : "Bearer new")
                return (attempt == 1 ? 401 : 200, Data(#"{"name":"direct"}"#.utf8))
            }
        }
        let client = makeClient(interceptors: [CYCredentialInterceptor { state.withLock { "Bearer \($0.credential)" } }])
        client.setCredentialRecovery(CYCredentialRecovery(action: {
            state.withLock { $0.recoveries += 1; $0.credential = "new" }; return true
        }))
        let value: DirectValue = try await client.send(DirectEndpoint(), strategy: .direct)
        XCTAssertEqual(value.name, "direct")
        XCTAssertEqual(state.withLock { $0.requests }, 2)
        XCTAssertEqual(state.withLock { $0.recoveries }, 1)
    }

    func testDirectJSONStopsAfterOneReplayAndReportsOnlyTerminal401() async throws {
        let state = Mutex((requests: 0, recoveries: 0, failures: 0))
        DirectURLProtocol.handler.withLock { handler in
            handler = { _ in
                state.withLock { $0.requests += 1 }
                return (401, Data())
            }
        }
        let client = makeClient(responses: [CYAuthenticationFailureInterceptor { state.withLock { $0.failures += 1 } }])
        client.setCredentialRecovery(CYCredentialRecovery(action: { state.withLock { $0.recoveries += 1 }; return true }))
        do {
            let _: DirectValue = try await client.send(DirectEndpoint(), strategy: .direct)
            XCTFail("Expected 401")
        } catch {
            guard case CYNetworkError.httpError(statusCode: 401, data: _) = error else { return XCTFail("Expected HTTP 401") }
        }
        XCTAssertEqual(state.withLock { $0.requests }, 2)
        XCTAssertEqual(state.withLock { $0.recoveries }, 1)
        XCTAssertEqual(state.withLock { $0.failures }, 1)
    }

    func testPublicDirectJSONDoesNotRecoverCredentials() async throws {
        let recoveries = Mutex(0)
        DirectURLProtocol.handler.withLock { handler in handler = { _ in (401, Data()) } }
        let client = makeClient()
        client.setCredentialRecovery(CYCredentialRecovery(action: { recoveries.withLock { $0 += 1 }; return true }))
        do {
            let _: DirectValue = try await client.send(DirectEndpoint(authentication: .none), strategy: .direct)
            XCTFail("Expected 401")
        } catch { XCTAssertEqual(recoveries.withLock { $0 }, 0) }
    }

    func testMultipartDirectResponseRecoversOnceAndHonorsEndpointTimeout() async throws {
        let state = Mutex((requests: 0, recoveries: 0))
        DirectURLProtocol.handler.withLock { handler in
            handler = { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.timeoutInterval, 150)
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
                let attempt = state.withLock { $0.requests += 1; return $0.requests }
                return (attempt == 1 ? 401 : 200, Data(#"{"name":"uploaded"}"#.utf8))
            }
        }
        let client = makeClient()
        client.setCredentialRecovery(CYCredentialRecovery(action: { state.withLock { $0.recoveries += 1 }; return true }))
        let value: DirectValue = try await client.upload(DirectEndpoint(method: .post), strategy: .direct,
            parts: [CYMultipartPart(data: Data([1,2,3]), mimeType: "image/png")])
        XCTAssertEqual(value.name, "uploaded")
        XCTAssertEqual(state.withLock { $0.requests }, 2)
        XCTAssertEqual(state.withLock { $0.recoveries }, 1)
    }

    func testDirectValidationFailurePreservesBodyWithoutRecovering() async throws {
        let recoveries = Mutex(0)
        let body = Data(#"{"statusCode":422,"code":"VALIDATION_ERROR"}"#.utf8)
        DirectURLProtocol.handler.withLock { handler in handler = { _ in (422, body) } }
        let client = makeClient()
        client.setCredentialRecovery(CYCredentialRecovery(action: { recoveries.withLock { $0 += 1 }; return true }))
        do {
            let _: DirectValue = try await client.send(DirectEndpoint(), strategy: .direct)
            XCTFail("Expected validation error")
        } catch {
            guard case CYNetworkError.httpError(statusCode: 422, data: let actual) = error else { return XCTFail("Expected HTTP 422") }
            XCTAssertEqual(actual, body)
        }
        XCTAssertEqual(recoveries.withLock { $0 }, 0)
    }
}

private final class DirectURLProtocol: URLProtocol, @unchecked Sendable {
    static let handler = Mutex<(@Sendable (URLRequest) throws -> (Int, Data))?>(nil)
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "direct.example.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let respond = Self.handler.withLock({ $0 }) else { throw URLError(.badServerResponse) }
            let (status, data) = try respond(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
