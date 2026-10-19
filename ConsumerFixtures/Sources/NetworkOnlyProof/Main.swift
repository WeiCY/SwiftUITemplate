import NetworkOnly

@main
struct Proof {
    @MainActor static func main() async throws {
        FixtureHTTPProtocol.handler.withLock { $0 = .init(start: { $0.respond(code: 200, body: #"{"value":7}"#) }) }
        let value = try await NetworkConsumer.fetch(client: NetworkConsumer.makeClient()); precondition(value == 7)
        print("PASS NetworkOnly")
    }
}
