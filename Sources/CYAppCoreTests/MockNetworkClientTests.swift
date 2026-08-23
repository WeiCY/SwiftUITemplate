import XCTest
@testable import CYAppCore

// MARK: - Batch 11：Mock 全 API 可用

private struct MockTestEndpoint: CYEndpoint {
    let path: String
    var method: CYHTTPMethod { .get }
    var body: CYRequestParams? { nil }
}

private struct MockTestUser: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

final class MockNetworkClientTests: XCTestCase {

    private func makeMock() -> MockNetworkClient {
        let mock = MockNetworkClient()
        mock.defaultDelay = 0
        return mock
    }

    // MARK: - requestRaw

    func testMockRequestRawWithRegisteredEnvelope() async throws {
        let mock = makeMock()
        let envelope = CYAPIResponse(code: 0, data: MockTestUser(id: 1, name: "A"), message: "ok")
        mock.registerResponse(envelope)
        let result: CYAPIResponse<MockTestUser> = try await mock.requestRaw(MockTestEndpoint(path: "/user"))
        XCTAssertEqual(result.data, envelope.data)
        XCTAssertEqual(result.message, "ok")
    }

    func testMockRequestRawWrapsRegisteredValue() async throws {
        let mock = makeMock()
        mock.registerResponse(MockTestUser(id: 2, name: "B"))
        let result: CYAPIResponse<MockTestUser> = try await mock.requestRaw(MockTestEndpoint(path: "/user"))
        XCTAssertEqual(result.code, 0)
        XCTAssertEqual(result.data?.id, 2)
        XCTAssertEqual(result.data?.name, "B")
    }

    func testMockRequestRawThrowsRegisteredError() async {
        let mock = makeMock()
        mock.registerError(for: MockTestUser.self, CYNetworkError.businessError(code: 500, message: "boom"))
        do {
            let _: CYAPIResponse<MockTestUser> = try await mock.requestRaw(MockTestEndpoint(path: "/user"))
            XCTFail("应抛出注册的错误")
        } catch let error as CYNetworkError {
            guard case .businessError(let code, _) = error else {
                XCTFail("应抛 businessError，实际 \(error)")
                return
            }
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("应抛 CYNetworkError，实际 \(error)")
        }
    }

    // MARK: - send 策略

    func testMockSendDirectStrategy() async throws {
        let mock = makeMock()
        mock.registerResponse(MockTestUser(id: 3, name: "C"))
        let user: MockTestUser = try await mock.send(MockTestEndpoint(path: "/user"), strategy: .direct)
        XCTAssertEqual(user.id, 3)
    }

    func testMockSendEnvelopeRawStrategy() async throws {
        let mock = makeMock()
        mock.registerResponse(CYAPIResponse(code: 0, data: MockTestUser(id: 4, name: "D"), message: "ok"))
        let result: CYAPIResponse<MockTestUser> = try await mock.send(MockTestEndpoint(path: "/user"), strategy: .envelopeRaw)
        XCTAssertEqual(result.data?.id, 4)
    }

    func testMockSendEmptyStrategy() async throws {
        let mock = makeMock()
        let result: CYEmptyResponse = try await mock.send(MockTestEndpoint(path: "/empty"), strategy: .empty)
        _ = result
    }

    // MARK: - requestData / requestVoid / request(body:)

    func testMockRequestData() async throws {
        let mock = makeMock()
        let raw = Data("hello".utf8)
        mock.registerResponse(raw)
        let data = try await mock.requestData(MockTestEndpoint(path: "/file"))
        XCTAssertEqual(data, raw)
    }

    func testMockRequestVoid() async throws {
        let mock = makeMock()
        mock.registerResponse(CYEmptyResponse())
        try await mock.requestVoid(MockTestEndpoint(path: "/delete"))
    }

    func testMockRequestWithEncodableBody() async throws {
        struct LoginBody: Encodable, Sendable {
            let username: String
        }
        let mock = makeMock()
        mock.registerResponse(MockTestUser(id: 5, name: "E"))
        let user: MockTestUser = try await mock.request(MockTestEndpoint(path: "/login"), body: LoginBody(username: "john"))
        XCTAssertEqual(user.name, "E")
    }

    // MARK: - shouldFail

    func testMockShouldFail() async {
        let mock = makeMock()
        mock.shouldFail = true
        do {
            let _: MockTestUser = try await mock.request(MockTestEndpoint(path: "/user"))
            XCTFail("shouldFail 时应抛错")
        } catch {
            // 预期抛错
        }
    }
}
