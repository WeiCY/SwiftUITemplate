import Alamofire
import Foundation
import XCTest
@testable import CYAppCore
@testable import CYAppNetwork

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.lock.withLock({ Self.handler }) else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum TestEndpoint: CYEndpoint {
    case profile
    case upload
    case download

    var path: String {
        switch self {
        case .profile: "/profile"
        case .upload: "/upload"
        case .download: "/download"
        }
    }

    var method: CYHTTPMethod { self == .upload ? .post : .get }
}

private struct TestPayload: Codable, Sendable, Equatable { let value: String }

private actor RequestCapture {
    var request: URLRequest?
    func save(_ request: URLRequest) { self.request = request }
}

private struct HeaderInterceptor: CYRequestInterceptor {
    func intercept(_ request: inout URLRequest) async {
        request.setValue("intercepted", forHTTPHeaderField: "X-Test")
    }
}

private actor ResponseCounter {
    var value = 0
    func increment() { value += 1 }
}

private struct CountingResponseInterceptor: CYResponseInterceptor {
    let counter: ResponseCounter
    func intercept(_ response: URLResponse?, data: Data?) async throws { await counter.increment() }
}

final class NetworkIOTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.lock.withLock { URLProtocolStub.handler = nil }
        super.tearDown()
    }

    func testRequestAppliesInterceptorsAndDecodesResponse() async throws {
        let capture = RequestCapture()
        let counter = ResponseCounter()
        URLProtocolStub.lock.withLock {
            URLProtocolStub.handler = { request in
                Task { await capture.save(request) }
                return (Self.response(for: request), Self.json("{\"code\":0,\"data\":{\"value\":\"ok\"}}"))
            }
        }
        let client = makeClient(requestInterceptors: [HeaderInterceptor()], responseInterceptors: [CountingResponseInterceptor(counter: counter)])

        let result: TestPayload = try await client.request(TestEndpoint.profile)
        XCTAssertEqual(result, TestPayload(value: "ok"))
        let capturedRequest = await capture.request
        let responseCount = await counter.value
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "X-Test"), "intercepted")
        XCTAssertEqual(responseCount, 1)
    }

    func testUploadSendsMultipartData() async throws {
        let capture = RequestCapture()
        URLProtocolStub.lock.withLock {
            URLProtocolStub.handler = { request in
                Task { await capture.save(request) }
                return (Self.response(for: request), Self.json("{\"code\":0,\"data\":{\"value\":\"uploaded\"}}"))
            }
        }
        let client = makeClient()
        let result: TestPayload = try await client.upload(
            TestEndpoint.upload,
            parts: [CYMultipartPart(data: Data("image".utf8), mimeType: "image/jpeg", fileName: "avatar.jpg", paramName: "avatar")],
            additionalParams: ["kind": "profile"]
        )

        XCTAssertEqual(result, TestPayload(value: "uploaded"))
        let request = await capture.request
        XCTAssertEqual(request?.httpMethod, "POST")
    }

    func testDecodingFailureSurfacesAsDecodingFailedError() async {
        // data 字段类型与模型不匹配时，应映射为 .decodingFailed（携带底层 DecodingError）
        URLProtocolStub.lock.withLock {
            URLProtocolStub.handler = { request in
                (Self.response(for: request), Self.json("{\"code\":0,\"data\":{\"value\":123}}"))
            }
        }
        let client = makeClient()
        do {
            let _: TestPayload = try await client.request(TestEndpoint.profile)
            XCTFail("格式错误的 data 应抛出解码错误")
        } catch let error as CYNetworkError {
            guard case .decodingFailed = error else {
                return XCTFail("应抛出 .decodingFailed，实际 \(error)")
            }
        } catch {
            XCTFail("应抛出 CYNetworkError，实际 \(error)")
        }
    }

    func testUploadRejectsOversizedPayload() async {
        // 将上传上限临时调低到 1MB，验证超限文件在发起请求前被拒绝
        let original = CYAppConstants.configuration
        defer { CYAppConstants.configure(original) }
        CYAppConstants.configure(CYAppConfigurationValues(maxUploadSizeMB: 1))

        let client = makeClient()
        let oversized = Data(repeating: 0, count: 1_048_577)
        do {
            let _: TestPayload = try await client.upload(
                TestEndpoint.upload,
                parts: [CYMultipartPart(data: oversized, mimeType: "application/octet-stream")]
            )
            XCTFail("超过上传上限的文件应被拒绝")
        } catch let error as CYNetworkError {
            guard case .payloadTooLarge(let limitMB) = error else {
                return XCTFail("应抛出 .payloadTooLarge，实际 \(error)")
            }
            XCTAssertEqual(limitMB, 1)
        } catch {
            XCTFail("应抛出 CYNetworkError，实际 \(error)")
        }
    }

    func testDownloadWritesDestinationFile() async throws {
        URLProtocolStub.lock.withLock {
            URLProtocolStub.handler = { request in (Self.response(for: request), Data("file-content".utf8)) }
        }
        let client = makeClient()
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }

        let result = try await client.download(TestEndpoint.download, to: destination)
        XCTAssertEqual(result, destination)
        XCTAssertEqual(try Data(contentsOf: result), Data("file-content".utf8))
    }

    private func makeClient(requestInterceptors: [any CYRequestInterceptor] = [], responseInterceptors: [any CYResponseInterceptor] = []) -> CYNetworkClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return CYNetworkClient(baseURL: "https://example.test", requestInterceptors: requestInterceptors, responseInterceptors: responseInterceptors, session: Session(configuration: configuration))
    }

    private static func response(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    }

    private static func json(_ string: String) -> Data { Data(string.utf8) }
}
