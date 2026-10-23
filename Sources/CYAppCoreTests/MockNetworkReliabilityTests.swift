import Foundation
import XCTest
@testable import CYAppCore

private struct MockReliabilityEndpoint: CYEndpoint {
    let path = "/items"
    var method: CYHTTPMethod = .get
    var queryItems: [URLQueryItem]?
    var body: CYRequestParams?
    var headers: [String: String]?
}

private struct MockReliabilityValue: Codable, Sendable, Equatable {
    let displayName: String
}

@MainActor
final class MockNetworkReliabilityTests: XCTestCase {
    private func makeMock() -> MockNetworkClient {
        let mock = MockNetworkClient()
        mock.defaultDelay = 0
        return mock
    }

    func testProtocolTypedRawRequestWrapsRegisteredPayload() async throws {
        let mock = makeMock()
        mock.registerResponse(MockReliabilityValue(displayName: "hello"))
        let client: any CYNetworkClientProtocol = mock
        let result: CYAPIResponse<MockReliabilityValue> = try await client.requestRaw(MockReliabilityEndpoint())
        XCTAssertEqual(result.data?.displayName, "hello")
        XCTAssertEqual(mock.recordedRequests.count, 1)
    }

    func testRawEnvelopeRegistrationErrorIsNotSwallowedByPayloadFallback() async {
        let mock = makeMock()
        mock.registerResponse(MockReliabilityValue(displayName: "must not return"))
        mock.registerError(for: CYAPIResponse<MockReliabilityValue>.self, CYNetworkError.timeout)
        do {
            let _: CYAPIResponse<MockReliabilityValue> = try await mock.requestRaw(MockReliabilityEndpoint())
            XCTFail("Expected registered timeout")
        } catch {
            guard case CYNetworkError.timeout = error else { return XCTFail("Expected registered timeout") }
        }
    }

    func testMockDistinguishesPaginationQueryParameters() async throws {
        let mock = makeMock()
        let first = MockReliabilityEndpoint(queryItems: [URLQueryItem(name: "page", value: "1")])
        let second = MockReliabilityEndpoint(queryItems: [URLQueryItem(name: "page", value: "2")])
        mock.registerResponse(for: first, MockReliabilityValue(displayName: "first"))
        mock.registerResponse(for: second, MockReliabilityValue(displayName: "second"))
        let a: MockReliabilityValue = try await mock.request(first)
        let b: MockReliabilityValue = try await mock.request(second)
        XCTAssertEqual(a.displayName, "first")
        XCTAssertEqual(b.displayName, "second")
    }

    func testMockDistinguishesBodyAndHeaders() async throws {
        let mock = makeMock()
        let endpoints = [
            MockReliabilityEndpoint(method: .post, body: ["id": .int(1)], headers: ["Accept-Language": "en"]),
            MockReliabilityEndpoint(method: .post, body: ["id": .int(2)], headers: ["Accept-Language": "en"]),
            MockReliabilityEndpoint(method: .post, body: ["id": .int(2)], headers: ["Accept-Language": "zh"])
        ]
        for (index, endpoint) in endpoints.enumerated() {
            mock.registerResponse(for: endpoint, MockReliabilityValue(displayName: "\(index)"))
        }
        for (index, endpoint) in endpoints.enumerated() {
            let value: MockReliabilityValue = try await mock.request(endpoint)
            XCTAssertEqual(value.displayName, "\(index)")
        }
    }

    func testMockUsesEndpointEncodingStrategy() async throws {
        let mock = makeMock()
        mock.registerResponse(MockReliabilityValue(displayName: "ok"))
        let _: MockReliabilityValue = try await mock.request(MockReliabilityEndpoint(method: .post),
                                                             body: MockReliabilityValue(displayName: "input"))
        let body = try XCTUnwrap(mock.recordedRequests.first?.body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(object, ["display_name": "input"])
    }

    func testMockPropagatesEncodingFailureWithoutRecordingASentRequest() async {
        struct InvalidBody: Encodable, Sendable { let value = Double.nan }
        let mock = makeMock()
        mock.registerResponse(MockReliabilityValue(displayName: "must not return"))
        do {
            let _: MockReliabilityValue = try await mock.request(MockReliabilityEndpoint(method: .post), body: InvalidBody())
            XCTFail("Expected encoding error")
        } catch {
            guard case CYNetworkError.encodingFailed = error else { return XCTFail("Expected encoding error") }
        }
        XCTAssertTrue(mock.recordedRequests.isEmpty)
    }
}
