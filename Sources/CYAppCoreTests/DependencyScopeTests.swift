import XCTest
import FactoryKit
import CYTestSupport
@testable import CYAppCore

@MainActor
final class DependencyScopeTests: XCTestCase {
    func testFactoryScopeRestoresPreviousRegistrationAndCache() {
        CYGlobalTestState.withScope {
            let previous = MockToastManager()
            Container.shared.toastManager.register { previous }
            XCTAssertTrue(CYFactoryContainer.shared.toastManager === previous)
            CYGlobalTestState.withScope {
                let replacement = MockToastManager()
                Container.shared.toastManager.register { replacement }
                XCTAssertTrue(CYFactoryContainer.shared.toastManager === replacement)
            }
            XCTAssertTrue(CYFactoryContainer.shared.toastManager === previous)
        }
    }
}
