import Foundation
import Synchronization
import CYAppCore
import CYAppNetwork

public struct Status: Codable, Sendable { public let value: Int }
public struct StatusEndpoint: CYEndpoint {
    public var path: String { "/status" }
    public var method: CYHTTPMethod { .get }
    public init() {}
}

public final class FixtureHTTPProtocol: URLProtocol, @unchecked Sendable {
    public struct Handler: Sendable {
        public var start: (@Sendable (FixtureHTTPProtocol) -> Void)?
        public var stop: (@Sendable () -> Void)?
        public init(start: (@Sendable (FixtureHTTPProtocol) -> Void)? = nil, stop: (@Sendable () -> Void)? = nil) {
            self.start = start
            self.stop = stop
        }
    }
    public static let handler = Mutex(Handler())
    public override static func canInit(with request: URLRequest) -> Bool { true }
    public override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    public override func startLoading() { Self.handler.withLock { $0.start }?(self) }
    public override func stopLoading() { Self.handler.withLock { $0.stop }?() }
    public func respond(code: Int, body: String) {
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

public enum NetworkConsumer {
    public static func isCancellation(_ error: Error) -> Bool { CYAppError.resolve(error).isCancellation }
    public static func fetch(client: any CYNetworkClientProtocol) async throws -> Int {
        let status: Status = try await client.send(StatusEndpoint(), strategy: .direct)
        return status.value
    }

    public static func makeClient() -> any CYNetworkClientProtocol {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureHTTPProtocol.self]
        return CYNetworkClient(baseURL: "https://consumer.invalid", sessionConfiguration: config)
    }
}
