import XCTest
import Observation
import Synchronization
import CYAppCore
@testable import CYAppUI

final class TemplateReviewUIRegressionTests: XCTestCase {
    @MainActor
    func testLanguageChangeNotifiesObservation() {
        let state = CYAppState(themeManager: MockThemeManager(), localizationManager: MockLocalizationManager())
        let observed = Mutex(false)
        withObservationTracking { _ = state.language } onChange: {
            observed.withLock { $0 = true }
        }
        state.setLanguage("zh-Hans")
        XCTAssertEqual(state.language, "zh-Hans")
        XCTAssertTrue(observed.withLock { $0 })
    }

    @MainActor
    func testResetLanguageNotifiesObservation() {
        let state = CYAppState(themeManager: MockThemeManager(), localizationManager: MockLocalizationManager())
        state.setLanguage("zh-Hans")
        let observed = Mutex(false)
        withObservationTracking { _ = state.language } onChange: {
            observed.withLock { $0 = true }
        }
        state.resetAll()
        XCTAssertEqual(state.language, "en")
        XCTAssertTrue(observed.withLock { $0 })
    }
}
