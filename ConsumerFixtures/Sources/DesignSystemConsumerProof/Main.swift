import DesignSystemConsumer

@main
struct Proof {
    @MainActor static func main() async throws {
        let model = ConsumerPages(); model.failFirst = false; await model.refresh()
        precondition(model.items.count == 20); _ = DesignConsumerPage(model: model)
        print("PASS DesignSystemConsumer")
    }
}
