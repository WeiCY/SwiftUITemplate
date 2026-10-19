import OfflinePersistence

@main
struct Proof {
    @MainActor static func main() async throws {
        let valid = try OfflineConsumer.check(); precondition(valid)
        print("PASS OfflinePersistence")
    }
}
