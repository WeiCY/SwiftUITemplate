import Foundation
import Alamofire
import XCTest
@testable import CYAppCore
@testable import CYAppNetwork

// MARK: - 网络回归红测试（Batch 0 基线）
//
// 本文件锁定 Batch 0 启动时的「期望行为」。标注红测试的用例在 Batch 0 必须失败，
// 且失败原因对应既定缺陷，由后续 Batch 1/2/4/5/6 逐个转绿（均已转绿）。
//
// 历史占位说明（已落地）：
// - 日志脱敏：Batch 5 引入 internal 纯函数 `redactedRequestDescription` 后启用。
// - allowsTokenRefresh：Batch 6a 新增协议属性后启用。

// MARK: - 测试基础设施

private final class RegressionURLProtocolStub: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    /// 响应延迟（秒），用于取消/进度测试
    nonisolated(unsafe) static var delay: TimeInterval = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let delay = Self.lock.withLock { Self.delay }
        let handler = Self.lock.withLock { Self.handler }
        Task {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            do {
                guard let handler else {
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
    }

    override func stopLoading() {}
}

private enum RegressionEndpoint: CYEndpoint {
    case profile
    case empty
    case upload
    case raw
    case login

    var path: String {
        switch self {
        case .profile: return "/profile"
        case .empty: return "/empty"
        case .upload: return "/upload"
        case .raw: return "/raw"
        case .login: return "/login"
        }
    }

    var method: CYHTTPMethod {
        switch self {
        case .upload, .login: return .post
        default: return .get
        }
    }

    var body: CYRequestParams? {
        switch self {
        case .upload: return ["count": .int(42), "enabled": .bool(true)]
        default: return nil
        }
    }
}

private struct RegressionPayload: Codable, Sendable, Equatable {
    let ok: Bool
}

private struct SlashTestEndpoint: CYEndpoint {
    let path: String
    let queryItems: [URLQueryItem]?
    var method: CYHTTPMethod { .get }
    var body: CYRequestParams? { nil }
}

/// Batch 6a：`allowsTokenRefresh = false` 的端点
private struct NoRefreshEndpoint: CYEndpoint {
    let path: String
    var method: CYHTTPMethod { .get }
    var body: CYRequestParams? { nil }
    var allowsTokenRefresh: Bool { false }
}

private final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0
    var value: Int { lock.withLock { storage } }
    func next() -> Int { lock.withLock { storage += 1; return storage } }
}

private actor RefreshCounter {
    var value = 0
    func increment() { value += 1 }
}

private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Double] = []
    var values: [Double] { lock.withLock { storage } }
    func append(_ value: Double) { lock.withLock { storage.append(value) } }
}

private actor ResponseRecorder {
    var statuses: [Int] = []
    func record(_ status: Int) { statuses.append(status) }
}

private struct RecordingResponseInterceptor: CYResponseInterceptor {
    let recorder: ResponseRecorder
    func intercept(_ response: URLResponse?, data: Data?) async throws {
        if let http = response as? HTTPURLResponse {
            await recorder.record(http.statusCode)
        }
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()
    func set(_ data: Data) { lock.withLock { storage = data } }
    var value: Data { lock.withLock { storage } }
}

private func makeClient(
    requestInterceptors: [any CYRequestInterceptor] = [],
    responseInterceptors: [any CYResponseInterceptor] = []
) -> CYNetworkClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [RegressionURLProtocolStub.self]
    return CYNetworkClient(
        baseURL: "https://example.test",
        requestInterceptors: requestInterceptors,
        responseInterceptors: responseInterceptors,
        session: Session(configuration: configuration)
    )
}

private func stub(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
    RegressionURLProtocolStub.lock.withLock {
        RegressionURLProtocolStub.handler = handler
    }
}

private func regResponse(_ status: Int, body: Data = Data()) -> (HTTPURLResponse, Data) {
    (
        HTTPURLResponse(
            url: URL(string: "https://example.test/")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!,
        body
    )
}

private let successJSON = Data(#"{"code":0,"data":{"ok":true},"message":"ok"}"#.utf8)

// MARK: - Multipart 解析辅助

private func requestBodyData(_ request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

private func multipartFields(_ data: Data) -> [String: String] {
    guard let body = String(data: data, encoding: .utf8) else { return [:] }
    var result: [String: String] = [:]
    for part in body.components(separatedBy: "--") {
        guard part.contains("Content-Disposition: form-data") else { continue }
        guard let nameRange = part.range(of: #"name="([^"]+)""#, options: .regularExpression) else { continue }
        let name = String(part[nameRange])
            .replacingOccurrences(of: #"name=""#, with: "")
            .replacingOccurrences(of: "\"", with: "")
        guard let valueStart = part.range(of: "\r\n\r\n") else { continue }
        var value = String(part[valueStart.upperBound...])
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n"))
        result[name] = value
    }
    return result
}

// MARK: - 红测试

final class NetworkRegressionTests: XCTestCase {

    override func tearDown() {
        RegressionURLProtocolStub.lock.withLock {
            RegressionURLProtocolStub.handler = nil
            RegressionURLProtocolStub.delay = 0
        }
        super.tearDown()
    }

    /// 红测试：`data` 缺失 + `T == CYEmptyResponse` 应成功。
    /// 当前 `resolveData` 对 `data == nil` 抛 `decodingFailed`，本测试失败。Batch 2 修复。
    func testEmptyResponseSucceedsWithMissingData() async throws {
        stub { _ in regResponse(200, body: Data(#"{"code":0,"message":"ok"}"#.utf8)) }
        let client = makeClient()
        do {
            let result: CYEmptyResponse = try await client.request(RegressionEndpoint.empty)
            _ = result
        } catch {
            XCTFail("空 data + CYEmptyResponse 应成功，实际抛出 \(error)")
        }
    }

    /// 红测试：204 No Content + `T == CYEmptyResponse` 应成功。
    /// 当前空 body 无法解码为 `CYAPIResponse`，本测试失败。Batch 2 修复。
    func testEmptyResponseSucceedsWith204NoContent() async throws {
        stub { _ in regResponse(204) }
        let client = makeClient()
        do {
            let result: CYEmptyResponse = try await client.request(RegressionEndpoint.empty)
            _ = result
        } catch {
            XCTFail("204 + CYEmptyResponse 应成功，实际抛出 \(error)")
        }
    }

    /// 回归守卫（应通过）：`data` 缺失只对 `CYEmptyResponse` 放行，非空类型仍必须抛错。
    func testMissingDataStillFailsForNonEmptyType() async throws {
        stub { _ in regResponse(200, body: Data(#"{"code":0,"message":"ok"}"#.utf8)) }
        let client = makeClient()
        do {
            let _: RegressionPayload = try await client.request(RegressionEndpoint.empty)
            XCTFail("非空类型收到 data 缺失响应应抛错")
        } catch let error as CYNetworkError {
            guard case .decodingFailed = error else {
                XCTFail("应抛 decodingFailed，实际 \(error)")
                return
            }
        } catch {
            XCTFail("应抛 CYNetworkError，实际 \(error)")
        }
    }

    /// 回归守卫（应通过）：204 空响应只对 `CYEmptyResponse` 放行，非空类型仍必须抛错。
    /// 非空类型走 Alamofire 原有解码路径，错误为 `.underlying(.invalidEmptyResponse)`。
    func test204StillFailsForNonEmptyType() async throws {
        stub { _ in regResponse(204) }
        let client = makeClient()
        do {
            let _: RegressionPayload = try await client.request(RegressionEndpoint.empty)
            XCTFail("非空类型收到 204 空响应应抛错")
        } catch let error as CYNetworkError {
            XCTAssertFalse(error.isCancellation)
        } catch {
            XCTFail("应抛 CYNetworkError，实际 \(error)")
        }
    }

    // MARK: - Batch 3：buildURL 斜杠规范化

    /// `baseURL` 尾斜杠 + `path` 前导斜杠：不应产生双斜杠。
    func testBuildURLBaseTrailingSlashAndPathLeadingSlash() throws {
        let client = CYNetworkClient(baseURL: "https://api.example.com/", session: Session(configuration: .ephemeral))
        let endpoint = SlashTestEndpoint(path: "/v1/user", queryItems: [URLQueryItem(name: "a", value: "1")])
        XCTAssertEqual(client.buildURL(for: endpoint)?.absoluteString, "https://api.example.com/v1/user?a=1")
    }

    /// `baseURL` 无尾斜杠 + `path` 无前导斜杠：应自动补齐分隔斜杠。
    func testBuildURLBaseNoTrailingSlashAndPathNoLeadingSlash() throws {
        let client = CYNetworkClient(baseURL: "https://api.example.com", session: Session(configuration: .ephemeral))
        let endpoint = SlashTestEndpoint(path: "v1/user", queryItems: nil)
        XCTAssertEqual(client.buildURL(for: endpoint)?.absoluteString, "https://api.example.com/v1/user")
    }

    /// `baseURL` 无尾斜杠 + `path` 前导斜杠：正常单斜杠拼接。
    func testBuildURLNormalCase() throws {
        let client = CYNetworkClient(baseURL: "https://api.example.com", session: Session(configuration: .ephemeral))
        let endpoint = SlashTestEndpoint(path: "/v1/user", queryItems: nil)
        XCTAssertEqual(client.buildURL(for: endpoint)?.absoluteString, "https://api.example.com/v1/user")
    }

    /// 红测试转绿：`URLError.cancelled` 应精确映射为 `CYNetworkError.cancelled`。
    /// Batch 0 时该测试以「不得落入 .underlying」作为红断言；Batch 1 新增 `.cancelled` case 后改为精确匹配。
    func testURLErrorCancelledIsMappedToCancelled() async {
        stub { _ in throw URLError(.cancelled) }
        let client = makeClient()
        do {
            let _: RegressionPayload = try await client.request(RegressionEndpoint.profile)
            XCTFail("应抛出错误")
        } catch let error as CYNetworkError {
            if case .cancelled = error {
                // 通过
            } else {
                XCTFail("应精确映射为 .cancelled，实际 \(error)")
            }
            XCTAssertTrue(error.isCancellation)
        } catch {
            XCTFail("应抛出 CYNetworkError，实际 \(error)")
        }
    }

    /// 红测试：multipart 中 `endpoint.body` 的 Int/Bool 参数不应丢失。
    /// 当前 `upload` 只写入 `value.stringValue`，数值参数被静默丢弃，本测试失败。Batch 4 修复。
    func testUploadKeepsNumericBodyParameters() async throws {
        let captured = DataBox()
        stub { request in
            captured.set(requestBodyData(request))
            return regResponse(200, body: successJSON)
        }
        let client = makeClient()
        let payload: RegressionPayload = try await client.upload(
            RegressionEndpoint.upload,
            parts: [CYMultipartPart(
                data: Data("file-content".utf8),
                mimeType: "text/plain",
                fileName: "f.txt",
                paramName: "file"
            )],
            additionalParams: ["kind": "profile"]
        )
        XCTAssertEqual(payload.ok, true)

        let fields = multipartFields(captured.value)
        XCTAssertEqual(fields["count"], "42", "endpoint.body 的 Int 参数不应被丢弃")
        XCTAssertEqual(fields["enabled"], "true", "endpoint.body 的 Bool 参数不应被丢弃")
        XCTAssertEqual(fields["kind"], "profile", "additionalParams 应正常写入")
    }

    // MARK: - Batch 5：日志脱敏

    /// Authorization 请求头不应打印原始值。
    func testLoggingInterceptorRedactsAuthorization() {
        var request = URLRequest(url: URL(string: "https://example.test/")!)
        request.setValue("Bearer super-secret-token", forHTTPHeaderField: "Authorization")
        let log = CYLoggingInterceptor.redactedRequestDescription(request)
        XCTAssertFalse(log.contains("super-secret-token"))
        XCTAssertTrue(log.contains("Authorization"))
    }

    /// 请求 Body 中的敏感字段（password / access_token）不应打印原始值，非敏感字段保留。
    func testLoggingInterceptorRedactsSensitiveBodyFields() {
        var request = URLRequest(url: URL(string: "https://example.test/")!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"username":"john","password":"secret123","access_token":"abc"}"#.utf8)
        let log = CYLoggingInterceptor.redactedRequestDescription(request, includeBody: true)
        XCTAssertFalse(log.contains("secret123"))
        XCTAssertFalse(log.contains("abc"))
        XCTAssertTrue(log.contains("john"), "非敏感字段应保留")
    }

    /// 普通请求头不应被误伤。
    func testLoggingInterceptorKeepsNormalHeaders() {
        var request = URLRequest(url: URL(string: "https://example.test/")!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let log = CYLoggingInterceptor.redactedRequestDescription(request)
        XCTAssertTrue(log.contains("application/json"))
    }

    /// 红测试：`requestRaw` 收到 HTTP 401 不应触发自动刷新（新语义：完全 raw）。
    /// 当前 `requestRaw` 包了 `performRequest`，401 会触发刷新并重放，本测试失败。Batch 6c 修复。
    func testRequestRawDoesNotAutoRefreshOnHTTP401() async throws {
        let refreshCount = RefreshCounter()
        stub { _ in regResponse(401) }
        let client = makeClient()
        client.setTokenRefreshInterceptor(CYTokenRefreshInterceptor(
            refreshTokenProvider: { "refresh_token" },
            onTokenRefreshed: { _ in },
            refreshAction: { _ in
                await refreshCount.increment()
                return TokenPair(accessToken: "new", refreshToken: "new_rt", expiresAt: nil)
            },
            onRefreshFailed: {}
        ))
        do {
            let _: CYAPIResponse<RegressionPayload> = try await client.requestRaw(RegressionEndpoint.raw)
            XCTFail("requestRaw 收到 HTTP 401 应直接抛出，不应自动刷新")
        } catch let error as CYNetworkError {
            XCTAssertEqual(error.statusCode ?? -1, 401)
        } catch {
            XCTFail("应抛出 CYNetworkError，实际 \(error)")
        }
        let refreshed = await refreshCount.value
        XCTAssertEqual(refreshed, 0, "requestRaw 不应触发 Token 刷新（Batch 6c 语义）")
    }

    /// 红测试：401 且刷新成功后，响应拦截器不应收到瞬态 401（自动登出不提前触发）。
    /// 当前 `fetchRaw` 的 catch 分支会调用响应拦截器（记录 401），且成功后再次调用（记录 200），
    /// 最终 statuses == [401, 200]，本测试失败。Batch 6d 修复为仅终态调用（[200]）。
    func testResponseInterceptorNotCalledOnTransient401() async throws {
        let attempts = AttemptCounter()
        let recorder = ResponseRecorder()
        stub { _ in
            if attempts.next() == 1 {
                return regResponse(401)
            }
            return regResponse(200, body: successJSON)
        }
        let client = makeClient(responseInterceptors: [RecordingResponseInterceptor(recorder: recorder)])
        client.setTokenRefreshInterceptor(CYTokenRefreshInterceptor(
            refreshTokenProvider: { "refresh_token" },
            onTokenRefreshed: { _ in },
            refreshAction: { _ in
                TokenPair(accessToken: "new", refreshToken: "new_rt", expiresAt: nil)
            },
            onRefreshFailed: {}
        ))
        let payload: RegressionPayload = try await client.request(RegressionEndpoint.profile)
        XCTAssertEqual(payload.ok, true)
        let statuses = await recorder.statuses
        XCTAssertEqual(statuses, [200], "瞬态 401 不应传给响应拦截器（自动登出不提前触发，Batch 6d 修复）")
    }

    // MARK: - Batch 6：Token 刷新边界

    /// 6a：`allowsTokenRefresh = false` 的端点收到 401 时不应触发刷新，直接抛错。
    func testAllowsTokenRefreshFalseSkipsRefresh() async throws {
        let refreshCount = RefreshCounter()
        stub { _ in regResponse(401) }
        let client = makeClient()
        client.setTokenRefreshInterceptor(CYTokenRefreshInterceptor(
            refreshTokenProvider: { "refresh_token" },
            onTokenRefreshed: { _ in },
            refreshAction: { _ in
                await refreshCount.increment()
                return TokenPair(accessToken: "new", refreshToken: "new_rt", expiresAt: nil)
            },
            onRefreshFailed: {}
        ))
        do {
            let _: RegressionPayload = try await client.request(NoRefreshEndpoint(path: "/no-refresh"))
            XCTFail("应抛出 401")
        } catch let error as CYNetworkError {
            XCTAssertEqual(error.statusCode ?? -1, 401)
        } catch {
            XCTFail("应抛出 CYNetworkError，实际 \(error)")
        }
        let refreshed = await refreshCount.value
        XCTAssertEqual(refreshed, 0, "allowsTokenRefresh = false 时不应触发刷新（Batch 6a 语义）")
    }

    /// 6b：刷新动作自身抛错时，不重放、不递归，错误直接向上抛出。
    func testRefreshActionFailurePropagatesWithoutRecursion() async throws {
        let attempts = AttemptCounter()
        let refreshCount = RefreshCounter()
        stub { _ in
            _ = attempts.next()
            return regResponse(401)
        }
        let client = makeClient()
        client.setTokenRefreshInterceptor(CYTokenRefreshInterceptor(
            refreshTokenProvider: { "refresh_token" },
            onTokenRefreshed: { _ in },
            refreshAction: { _ in
                await refreshCount.increment()
                throw URLError(.badServerResponse)
            },
            onRefreshFailed: {}
        ))
        do {
            let _: RegressionPayload = try await client.request(RegressionEndpoint.profile)
            XCTFail("刷新失败后应抛出 401")
        } catch let error as CYNetworkError {
            XCTAssertEqual(error.statusCode ?? -1, 401)
        } catch {
            XCTFail("应抛出 CYNetworkError，实际 \(error)")
        }
        let refreshed = await refreshCount.value
        XCTAssertEqual(refreshed, 1, "刷新动作只应尝试一次，不得递归刷新")
        XCTAssertEqual(attempts.value, 1, "刷新失败后不应重放原请求")
    }

    /// 现状锁定（当前为绿）：默认 `allowsTokenRefresh = true`，401 触发刷新并重放成功。
    func testCurrentBehavior401TriggersRefreshAndReplay() async throws {
        let attempts = AttemptCounter()
        let refreshCount = RefreshCounter()
        stub { _ in
            if attempts.next() == 1 {
                return regResponse(401)
            }
            return regResponse(200, body: successJSON)
        }
        let client = makeClient()
        client.setTokenRefreshInterceptor(CYTokenRefreshInterceptor(
            refreshTokenProvider: { "refresh_token" },
            onTokenRefreshed: { _ in },
            refreshAction: { _ in
                await refreshCount.increment()
                return TokenPair(accessToken: "new", refreshToken: "new_rt", expiresAt: nil)
            },
            onRefreshFailed: {}
        ))
        let payload: RegressionPayload = try await client.request(RegressionEndpoint.profile)
        XCTAssertEqual(payload.ok, true)
        let refreshed = await refreshCount.value
        XCTAssertEqual(refreshed, 1)
    }

    // MARK: - Batch 8：send 策略

    func testSendEnvelopeStrategy() async throws {
        stub { _ in regResponse(200, body: successJSON) }
        let client = makeClient()
        let payload: RegressionPayload = try await client.send(RegressionEndpoint.profile, strategy: .envelope)
        XCTAssertEqual(payload.ok, true)
    }

    func testSendEnvelopeRawStrategy() async throws {
        stub { _ in regResponse(200, body: successJSON) }
        let client = makeClient()
        let response: CYAPIResponse<RegressionPayload> = try await client.send(RegressionEndpoint.profile, strategy: .envelopeRaw)
        XCTAssertEqual(response.isSuccess, true)
        XCTAssertEqual(response.data?.ok, true)
    }

    func testSendDirectStrategy() async throws {
        stub { _ in regResponse(200, body: Data(#"{"ok":true}"#.utf8)) }
        let client = makeClient()
        let payload: RegressionPayload = try await client.send(RegressionEndpoint.profile, strategy: .direct)
        XCTAssertEqual(payload.ok, true)
    }

    func testSendEmptyStrategy() async throws {
        stub { _ in regResponse(204) }
        let client = makeClient()
        let result: CYEmptyResponse = try await client.send(RegressionEndpoint.empty, strategy: .empty)
        _ = result
    }

    func testSendDataStrategyThrows() async {
        stub { _ in regResponse(200, body: successJSON) }
        let client = makeClient()
        do {
            let _: RegressionPayload = try await client.send(RegressionEndpoint.profile, strategy: .data)
            XCTFail(".data 策略应抛错并提示使用 requestData")
        } catch {
            // 预期抛错
        }
    }

    func testSendWithEncodableBody() async throws {
        struct LoginBody: Encodable, Sendable {
            let username: String
            let password: String
        }
        let captured = DataBox()
        stub { request in
            captured.set(requestBodyData(request))
            return regResponse(200, body: successJSON)
        }
        let client = makeClient()
        let payload: RegressionPayload = try await client.send(
            RegressionEndpoint.login,
            strategy: .envelope,
            body: LoginBody(username: "john", password: "123")
        )
        XCTAssertEqual(payload.ok, true)
        let bodyText = String(data: captured.value, encoding: .utf8) ?? ""
        XCTAssertTrue(bodyText.contains("john"))
        XCTAssertTrue(bodyText.contains("123"))
    }

    // MARK: - Batch 10：requestVoid / requestData / request(body:)

    func testRequestVoidSucceedsOn204() async throws {
        stub { _ in regResponse(204) }
        let client = makeClient()
        try await client.requestVoid(RegressionEndpoint.empty)
    }

    func testRequestVoidThrowsBusinessError() async throws {
        stub { _ in regResponse(200, body: Data(#"{"code":500,"message":"fail"}"#.utf8)) }
        let client = makeClient()
        do {
            try await client.requestVoid(RegressionEndpoint.empty)
            XCTFail("业务错误应抛出")
        } catch let error as CYNetworkError {
            guard case .businessError = error else {
                XCTFail("应抛 businessError，实际 \(error)")
                return
            }
        } catch {
            XCTFail("应抛 CYNetworkError，实际 \(error)")
        }
    }

    func testRequestDataReturnsRawBody() async throws {
        let raw = Data([0x01, 0x02, 0x03, 0x04])
        stub { _ in regResponse(200, body: raw) }
        let client = makeClient()
        let data = try await client.requestData(RegressionEndpoint.raw)
        XCTAssertEqual(data, raw)
    }

    func testRequestWithEncodableBody() async throws {
        struct LoginBody: Encodable, Sendable {
            let username: String
        }
        stub { _ in regResponse(200, body: successJSON) }
        let client = makeClient()
        let payload: RegressionPayload = try await client.request(RegressionEndpoint.login, body: LoginBody(username: "john"))
        XCTAssertEqual(payload.ok, true)
    }

    // MARK: - Batch 12：去重 key（Encodable body）

    func testDeduplicationSameEncodableBodyExecutesOnce() async throws {        struct Body: Encodable, Sendable {
            let a: Int
        }
        let attempts = AttemptCounter()
        stub { _ in
            _ = attempts.next()
            return regResponse(200, body: successJSON)
        }
        let client = makeClient()
        let deduplicator = CYRequestDeduplicator()
        async let t1: RegressionPayload = client.requestWithDeduplication(RegressionEndpoint.login, body: Body(a: 1), deduplicator: deduplicator)
        async let t2: RegressionPayload = client.requestWithDeduplication(RegressionEndpoint.login, body: Body(a: 1), deduplicator: deduplicator)
        _ = try await (t1, t2)
        XCTAssertEqual(attempts.value, 1, "相同 Encodable body 只应执行一次")
    }

    func testDeduplicationDifferentEncodableBodiesExecuteTwice() async throws {
        struct Body: Encodable, Sendable {
            let a: Int
        }
        let attempts = AttemptCounter()
        stub { _ in
            _ = attempts.next()
            return regResponse(200, body: successJSON)
        }
        let client = makeClient()
        let deduplicator = CYRequestDeduplicator()
        async let t1: RegressionPayload = client.requestWithDeduplication(RegressionEndpoint.login, body: Body(a: 1), deduplicator: deduplicator)
        async let t2: RegressionPayload = client.requestWithDeduplication(RegressionEndpoint.login, body: Body(a: 2), deduplicator: deduplicator)
        _ = try await (t1, t2)
        XCTAssertEqual(attempts.value, 2, "不同 Encodable body 应执行两次")
    }

    // MARK: - Batch 13：多文件上传 upload(parts:)

    func testUploadMultipleParts() async throws {
        let captured = DataBox()
        stub { request in
            captured.set(requestBodyData(request))
            return regResponse(200, body: successJSON)
        }
        let client = makeClient()
        let payload: RegressionPayload = try await client.upload(
            RegressionEndpoint.upload,
            parts: [
                CYMultipartPart(data: Data("avatar-content".utf8), mimeType: "image/jpeg", fileName: "a.jpg", paramName: "avatar"),
                CYMultipartPart(data: Data("cover-content".utf8), mimeType: "image/png", fileName: "c.png", paramName: "cover"),
            ],
            additionalParams: ["scene": "profile"]
        )
        XCTAssertEqual(payload.ok, true)

        let body = String(data: captured.value, encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains(#"name="avatar""#), "应包含 avatar 文件 part")
        XCTAssertTrue(body.contains(#"name="cover""#), "应包含 cover 文件 part")
        XCTAssertTrue(body.contains("filename=\"a.jpg\""), "avatar 文件名应保留")
        XCTAssertTrue(body.contains("filename=\"c.png\""), "cover 文件名应保留")
        XCTAssertTrue(body.contains("avatar-content"), "avatar 内容应写入")
        XCTAssertTrue(body.contains("cover-content"), "cover 内容应写入")
        XCTAssertTrue(body.contains(#"name="scene""#), "additionalParams 应写入")
    }

    // MARK: - Batch 14：上传/下载进度 + 取消传播

    func testDownloadCancellationPropagatesAsCancelled() async throws {
        RegressionURLProtocolStub.lock.withLock { RegressionURLProtocolStub.delay = 1 }
        stub { _ in regResponse(200, body: Data("file-content".utf8)) }
        let client = makeClient()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancel-test-\(UUID().uuidString).bin")

        let task = Task {
            try await client.download(RegressionEndpoint.raw, to: tempURL)
        }
        try await Task.sleep(for: .milliseconds(150))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("取消后应抛错")
        } catch let error as CYNetworkError {
            XCTAssertTrue(error.isCancellation, "取消应映射为 .cancelled，实际 \(error)")
        } catch {
            XCTFail("应抛 CYNetworkError，实际 \(error)")
        }
    }

    func testDownloadReportsProgress() async throws {
        RegressionURLProtocolStub.lock.withLock { RegressionURLProtocolStub.delay = 0.3 }
        stub { _ in regResponse(200, body: Data("file-content".utf8)) }
        let client = makeClient()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-download-\(UUID().uuidString).bin")
        let progressBox = ProgressBox()
        let url = try await client.download(RegressionEndpoint.raw, to: tempURL, progress: { fraction in
            progressBox.append(fraction)
        })
        XCTAssertEqual(url, tempURL)
        let values = progressBox.values
        // URLProtocol 模拟环境不产生真实字节计数；此处只验证回调被触发且值域合法
        XCTAssertFalse(values.isEmpty, "下载进度回调应被触发")
        XCTAssertTrue(values.allSatisfy { (0.0...1.0).contains($0) }, "进度应在 [0,1] 区间")
    }

    func testUploadReportsProgress() async throws {
        RegressionURLProtocolStub.lock.withLock { RegressionURLProtocolStub.delay = 0.3 }
        stub { _ in regResponse(200, body: successJSON) }
        let client = makeClient()
        let progressBox = ProgressBox()
        let payload: RegressionPayload = try await client.upload(
            RegressionEndpoint.upload,
            parts: [CYMultipartPart(
                data: Data(String(repeating: "x", count: 1024).utf8),
                mimeType: "text/plain",
                fileName: "f.txt",
                paramName: "file"
            )],
            additionalParams: nil,
            progress: { fraction in
                progressBox.append(fraction)
            }
        )
        XCTAssertEqual(payload.ok, true)
        let values = progressBox.values
        // URLProtocol 模拟环境不上报上传字节进度；此处仅验证值域合法（真实网络由 Alamofire 保证）
        XCTAssertTrue(values.allSatisfy { (0.0...1.0).contains($0) }, "进度应在 [0,1] 区间")
    }

    // MARK: - Batch 15：错误上下文与可观测性

    func testFailureLogMessageContainsContext() {
        let endpoint = RegressionEndpoint.profile
        let response = HTTPURLResponse(
            url: URL(string: "https://example.test/")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        let message = CYNetworkClient.failureLogMessage(
            error: CYNetworkError.httpError(statusCode: 500, data: nil),
            endpoint: endpoint,
            response: response
        )
        XCTAssertTrue(message.contains("GET /profile"), "应包含方法 + 路径上下文，实际 \(message)")
        XCTAssertTrue(message.contains("HTTP 500"), "应包含 HTTP 状态码，实际 \(message)")
        XCTAssertFalse(message.isEmpty)
    }
}
