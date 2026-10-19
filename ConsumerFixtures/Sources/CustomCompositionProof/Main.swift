import CustomComposition

@main
struct Proof {
    @MainActor static func main() async throws {
        let host = HostComposition(); host.toast.show("External", type: .success, duration: 1)
        precondition(host.toast.isPresented && !HostComposition().toast.isPresented)
        precondition(HostComposition.checkBrand()); _ = CustomConsumerPage(host: host)
        print("PASS CustomComposition")
    }
}
