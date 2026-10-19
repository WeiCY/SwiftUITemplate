import XCTest
import CYAppCore
@testable import ExampleApp

@MainActor
final class RecipeTests: XCTestCase {
    func testFormCrossFieldValidationAndFailureRecovery() async {
        let model = FormExampleModel(submit: {})
        model.email = "fake@example.test"
        model.password = "password-example"
        model.confirmation = "different"
        await model.submit()
        XCTAssertFalse(model.submitted)
        XCTAssertNotNil(model.confirmationError)
        model.confirmation = model.password
        model.simulateFailure = true
        await model.submit()
        XCTAssertNotNil(model.error)
        model.simulateFailure = false
        await model.submit()
        XCTAssertTrue(model.submitted)
        XCTAssertNil(model.error)
    }

    func testSearchChangeImmediatelyInvalidatesOldPage() async {
        var requests: [(String, CheckedContinuation<[SearchResult], Error>)] = []
        let model = SearchExampleModel { query, _, _ in
            try await withCheckedThrowingContinuation { requests.append((query, $0)) }
        }
        model.changeQuery("old")
        let old = Task { await model.load() }
        while requests.count < 1 { await Task.yield() }
        model.changeQuery("new")
        let new = Task { await model.load() }
        while requests.count < 2 { await Task.yield() }
        requests[1].1.resume(returning: [SearchResult(id: 2, title: "new")])
        await new.value
        requests[0].1.resume(returning: [SearchResult(id: 1, title: "old")])
        await old.value
        XCTAssertEqual(model.items.map(\.title), ["new"])
        XCTAssertEqual(model.currentPage, 1)
    }
}
