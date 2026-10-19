import CoreOnly

@main
struct Proof {
    @MainActor static func main() async throws {
        let valid = try CoreConsumer.check(); precondition(valid)
        print("PASS CoreOnly")
    }
}
