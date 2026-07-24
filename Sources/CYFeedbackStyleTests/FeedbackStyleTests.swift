import XCTest
import SwiftUI
@testable import CYFeedbackStyle

final class FeedbackStyleTests: XCTestCase {
    @MainActor
    func testDefaultLoadingStyleComposition() {
        let style = CYLoadingStyle.default

        XCTAssertEqual(style.maskOpacity, 0.2)
        XCTAssertEqual(style.indicator.scale, 1.2)
        XCTAssertEqual(style.indicator.size, 64)
        XCTAssertEqual(style.indicator.pulseScaleRange, 0.9...1.15)
        XCTAssertEqual(style.card.cornerRadius, 16)
        XCTAssertEqual(style.card.insets.top, 24)
        XCTAssertEqual(style.card.insets.leading, 32)
        XCTAssertTrue(style.disablesContent)
        XCTAssertEqual(style.contentBlurRadius, 0)
    }

    @MainActor
    func testCustomLoadingStyleUpdatesSharedConfiguration() {
        let custom = CYLoadingStyle(
            maskOpacity: 0.45,
            indicator: CYLoadingIndicatorStyle(color: .purple, scale: 1.6, size: 72),
            card: CYLoadingCardStyle(cornerRadius: 28),
            textFont: .headline,
            textColor: .orange,
            contentBlurRadius: 4
        )
        CYFeedbackConfiguration.configure(loadingStyle: custom)
        defer { CYFeedbackConfiguration.configure(loadingStyle: .default) }

        let shared = CYFeedbackConfiguration.shared.loadingStyle
        XCTAssertEqual(shared.maskOpacity, 0.45)
        XCTAssertEqual(shared.indicator.scale, 1.6)
        XCTAssertEqual(shared.indicator.size, 72)
        XCTAssertEqual(shared.card.cornerRadius, 28)
        XCTAssertEqual(shared.contentBlurRadius, 4)
    }
}
