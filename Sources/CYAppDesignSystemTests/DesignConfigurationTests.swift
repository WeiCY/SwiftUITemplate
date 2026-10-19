import CYTestSupport
import SwiftUI
import XCTest
@testable import CYAppDesignSystem

final class DesignConfigurationTests: XCTestCase {
    @MainActor
    func testBrandChangesExistingTokensAndKeepsColorCompatibility() {
        let globalState = CYGlobalTestState()
        defer { globalState.restore() }
        let original = CYDesignConfiguration.current
        defer { CYDesignConfiguration.configure(original) }
        CYDesignConfiguration.configure(.alternate)
        XCTAssertEqual(CYAppDimens.marginM, 16 * 1.15)
        XCTAssertEqual(CYAppDimens.radiusM, 12)
        XCTAssertEqual(CYAppDimens.buttonHeight, 52)
        let font = CYAppFont.bodyMedium
        CYAppColor.configure(primary: .red)
        XCTAssertEqual(CYAppDimens.buttonHeight, 52)
        CYDesignConfiguration.reset()
        XCTAssertNotEqual(font, CYAppFont.bodyMedium)
    }

    @MainActor
    func testInvalidLayoutValuesAreNormalized() {
        let globalState = CYGlobalTestState()
        defer { globalState.restore() }
        let original = CYDesignConfiguration.current
        defer { CYDesignConfiguration.configure(original) }
        var tokens = CYDesignTokens()
        tokens.spacingScale = .nan
        tokens.buttonHeight = -1
        CYDesignConfiguration.configure(tokens)
        XCTAssertEqual(CYAppDimens.marginM, 16)
        XCTAssertEqual(CYAppDimens.buttonHeight, 48)
    }
}
