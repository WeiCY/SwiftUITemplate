import XCTest
import SwiftData
import CYAppCore
import CYAppPersistence
@testable import ExampleApp

@MainActor
final class FeedbackInjectionTests: XCTestCase {
    func testFeatureAndCompositionUseInjectedToastInstance() async throws {
        let controller = try CYPersistenceController.create(for: [BookmarkItem.self, BookmarkTag.self], inMemory: true)
        let toast = MockToastManager()
        let loading = MockLoadingManager()
        let alert = CYAlertManager()
        let client = MockNetworkClient()
        client.registerResponse(Article.samples)
        let dependencies = AppDependencies(networkClient: client, modelContext: controller.container.mainContext,
                                           toast: toast, loading: loading, alert: alert)
        await dependencies.homeViewModel.load()
        dependencies.homeViewModel.toggleBookmark(Article.samples[0])
        XCTAssertTrue(dependencies.toast === toast)
        XCTAssertEqual(toast.showCallCount, 1)
        XCTAssertTrue(toast.isPresented)
        XCTAssertTrue(dependencies.loading === loading)
        XCTAssertTrue(dependencies.alert === alert)
        dependencies.toast.dismissAll()
        XCTAssertFalse(toast.isPresented)
    }

    func testStoreCanRetryAfterInjectedInitializationFailure() throws {
        var attempts = 0
        let persistence = ExamplePersistence {
            attempts += 1
            if attempts == 1 { throw NSError(domain: "FakeStore", code: 7) }
            return try CYPersistenceController.create(for: [BookmarkItem.self, BookmarkTag.self], inMemory: true)
        }
        persistence.open(networkClient: MockNetworkClient())
        XCTAssertNotNil(persistence.error)
        XCTAssertNil(persistence.dependencies)
        persistence.open(networkClient: MockNetworkClient())
        XCTAssertNil(persistence.error)
        XCTAssertNotNil(persistence.dependencies)
        XCTAssertEqual(attempts, 2)
    }
}
