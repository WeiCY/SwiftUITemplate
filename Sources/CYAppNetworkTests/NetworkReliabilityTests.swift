import Foundation
import Synchronization
import XCTest
@testable import CYAppCore
@testable import CYAppNetwork

private struct ReliabilityEndpoint: CYEndpoint {
    var path = "/value"
    var method: CYHTTPMethod = .get
    var authentication: CYAuthenticationPolicy = .none
}

private struct ReliabilityValue: Decodable, Sendable {
    let name: String
}

private final class ReliabilityResponseCounter: CYResponseInterceptor {
    let count = Mutex(0)
    func intercept(_ response: URLResponse?, data: Data?) async throws {
        count.withLock { $0 += 1 }
    }
}

@MainActor
final class NetworkReliabilityTests: XCTestCase {
    override func tearDown() {
        ReliabilityURLProtocol.handler.withLock { $0 = nil }
        super.tearDown()
    }

    private func makeClient(responseInterceptors: [any CYResponseInterceptor] = []) -> CYNetworkClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReliabilityURLProtocol.self]
        return CYNetworkClient(baseURL: "https://reliability.example.test",
                               responseInterceptors: responseInterceptors, sessionConfiguration: configuration)
    }

    private func respond(_ status: Int, _ body: String = "") {
        ReliabilityURLProtocol.handler.withLock { handler in
            handler = { _ in (status, Data(body.utf8), nil) }
        }
    }

    func testBusinessFailureWinsOverIncompatibleSuccessData() async throws {
        respond(200, #"{"code":422,"message":"name required","data":{"fields":["name"]}}"#)
        let counter = ReliabilityResponseCounter()
        let client = makeClient(responseInterceptors: [counter])
        do {
            let _: ReliabilityValue = try await client.request(ReliabilityEndpoint())
            XCTFail("Expected business error")
        } catch {
            guard case CYNetworkError.businessError(let code, let message) = error else {
                return XCTFail("Expected business error, got \(error)")
            }
            XCTAssertEqual(code, 422)
            XCTAssertEqual(message, "name required")
        }
        XCTAssertEqual(counter.count.withLock { $0 }, 1)
    }

    func testTokenExpiredWithErrorDataStillRecoversAndReplays() async throws {
        let requests = Mutex(0)
        let recoveries = Mutex(0)
        ReliabilityURLProtocol.handler.withLock { handler in
            handler = { _ in
                let attempt = requests.withLock { $0 += 1; return $0 }
                let body = attempt == 1
                    ? #"{"code":10001,"message":"expired","data":[]}"#
                    : #"{"code":0,"data":{"name":"ok"}}"#
                return (200, Data(body.utf8), nil)
            }
        }
        let client = makeClient()
        client.setCredentialRecovery(CYCredentialRecovery(action: {
            recoveries.withLock { $0 += 1 }
            return true
        }))
        let result: ReliabilityValue = try await client.request(ReliabilityEndpoint(authentication: .required))
        XCTAssertEqual(result.name, "ok")
        XCTAssertEqual(requests.withLock { $0 }, 2)
        XCTAssertEqual(recoveries.withLock { $0 }, 1)
    }

    func testSuccessStillReportsPreciseDataDecodingPath() async throws {
        respond(200, #"{"code":0,"data":{"name":7}}"#)
        do {
            let _: ReliabilityValue = try await makeClient().request(ReliabilityEndpoint())
            XCTFail("Expected decoding error")
        } catch {
            guard case CYNetworkError.decodingFailed(let underlying) = error,
                  case DecodingError.typeMismatch(_, let context) = underlying else {
                return XCTFail("Expected original decoding error, got \(error)")
            }
            XCTAssertEqual(context.codingPath.map(\.stringValue), ["data", "name"])
        }
    }

    func testEncodableFailureIsMappedBeforeSending() async {
        struct InvalidBody: Encodable, Sendable { let value = Double.nan }
        let requests = Mutex(0)
        ReliabilityURLProtocol.handler.withLock { handler in
            handler = { _ in requests.withLock { $0 += 1 }; return (200, Data(), nil) }
        }
        do {
            let _: ReliabilityValue = try await makeClient().request(ReliabilityEndpoint(method: .post), body: InvalidBody())
            XCTFail("Expected encoding error")
        } catch {
            guard case CYNetworkError.encodingFailed = error else { return XCTFail("Expected encoding error, got \(error)") }
        }
        XCTAssertEqual(requests.withLock { $0 }, 0)
    }

    func testRawEnvelopeKeepsStrictDecodingAndDoesNotRecover() async throws {
        respond(200, #"{"code":10001,"data":{"name":7}}"#)
        let recoveries = Mutex(0)
        let client = makeClient()
        client.setCredentialRecovery(CYCredentialRecovery(action: { recoveries.withLock { $0 += 1 }; return true }))
        do {
            let _: CYAPIResponse<ReliabilityValue> = try await client.requestRaw(ReliabilityEndpoint(authentication: .required))
            XCTFail("Expected decoding error")
        } catch {
            guard case CYNetworkError.decodingFailed = error else { return XCTFail("Expected decoding error") }
        }
        XCTAssertEqual(recoveries.withLock { $0 }, 0)
    }

    func testMultipartEnvelopeAccepts204And205WithoutData() async throws {
        let client = makeClient()
        for status in [204, 205] {
            respond(status)
            let _: CYEmptyResponse = try await client.upload(ReliabilityEndpoint(method: .post), parts: [])
        }
    }

    func testEmptyEnvelopeSupportsHTTPAndBusinessSuccessWithoutData() async throws {
        let client = makeClient()
        for status in [204, 205] {
            respond(status)
            try await client.requestVoid(ReliabilityEndpoint())
        }
        respond(200, #"{"code":0,"message":"ok"}"#)
        try await client.requestVoid(ReliabilityEndpoint())
    }

    func testNonEmptyModelStillRejectsMissingData() async throws {
        let client = makeClient()
        for status in [200, 204] {
            respond(status, status == 200 ? #"{"code":0}"# : "")
            do {
                let _: ReliabilityValue = try await client.request(ReliabilityEndpoint())
                XCTFail("A non-empty model requires data")
            } catch {
                guard case CYNetworkError.decodingFailed = error else { return XCTFail("Expected decoding failure") }
            }
        }
    }

    func testMultipartBusinessFailureUsesSameEnvelopeRules() async throws {
        respond(200, #"{"code":422,"message":"unsupported image","data":[]}"#)
        do {
            let _: ReliabilityValue = try await makeClient().upload(ReliabilityEndpoint(method: .post), parts: [])
            XCTFail("Expected business error")
        } catch {
            guard case CYNetworkError.businessError(422, "unsupported image") = error else {
                return XCTFail("Expected upload business error, got \(error)")
            }
        }
    }

    func testDirectEmptyDoesNotHideTransportCancellationAfterHeaders() async throws {
        ReliabilityURLProtocol.handler.withLock { handler in
            handler = { _ in (204, Data(), URLError(.cancelled)) }
        }
        do {
            let _: CYEmptyResponse = try await makeClient().send(ReliabilityEndpoint(), strategy: .direct)
            XCTFail("A 204 header cannot turn cancellation into success")
        } catch {
            guard case CYNetworkError.cancelled = error else { return XCTFail("Expected cancellation, got \(error)") }
        }
    }

    func testCancelledRequestDuringInterceptorNeverReachesTransport() async throws {
        let entered = expectation(description: "interceptor entered")
        let gate = ReliabilityGate()
        let requests = Mutex(0)
        ReliabilityURLProtocol.handler.withLock { handler in
            handler = { _ in requests.withLock { $0 += 1 }; return (200, Data(#"{"name":"ok"}"#.utf8), nil) }
        }
        let client = makeClient()
        client.addRequestInterceptor(ReliabilityGateInterceptor(gate: gate, entered: entered))
        let task = Task { () throws -> ReliabilityValue in
            try await client.send(ReliabilityEndpoint(), strategy: .direct)
        }
        await fulfillment(of: [entered], timeout: 2)
        task.cancel()
        await gate.open()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch {
            guard case CYNetworkError.cancelled = error else { return XCTFail("Expected cancellation") }
        }
        XCTAssertEqual(requests.withLock { $0 }, 0)
    }
}

actor ReliabilityGate {
    private var opened = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuations.append($0) }
    }
    func open() {
        opened = true
        let pending = continuations
        continuations.removeAll()
        for continuation in pending { continuation.resume() }
    }
}

private struct ReliabilityGateInterceptor: CYRequestInterceptor {
    let gate: ReliabilityGate
    let entered: XCTestExpectation
    func intercept(_ request: inout URLRequest) async {
        entered.fulfill()
        await gate.wait()
    }
}

private final class ReliabilityURLProtocol: URLProtocol, @unchecked Sendable {
    static let handler = Mutex<(@Sendable (URLRequest) throws -> (Int, Data, URLError?))?>(nil)
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "reliability.example.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let respond = Self.handler.withLock({ $0 }) else { throw URLError(.badServerResponse) }
            let (status, data, error) = try respond(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let error { client?.urlProtocol(self, didFailWithError: error); return }
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
