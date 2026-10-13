import XCTest
@testable import CYAppCore

final class LocalizationRegressionTests: XCTestCase {
    func testPackageResourcesFollowSelectedLanguageAndRestorePreference() {
        let suite = "CYLocalizationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = CYLocalizationManager(bundle: .module, defaults: defaults, systemLanguages: ["en"])
        XCTAssertEqual(manager.localized("action_retry"), "Retry")
        manager.setLanguage("zh-Hans")
        XCTAssertEqual(manager.localized("action_retry"), "重试")
        let restored = CYLocalizationManager(bundle: .module, defaults: defaults, systemLanguages: ["en"])
        XCTAssertEqual(restored.currentLanguage, "zh-Hans")
        XCTAssertEqual(restored.localized("action_retry"), "重试")
        restored.resetToSystem()
        XCTAssertEqual(restored.currentLanguage, "en")
        XCTAssertEqual(restored.localized("action_retry"), "Retry")
        XCTAssertNil(defaults.object(forKey: CYAppConstants.keyLanguagePreference))
    }

    func testRegionalChineseAndUnsupportedLanguageFallback() {
        let suite = "CYLocalizationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = CYLocalizationManager(bundle: .module, defaults: defaults, systemLanguages: ["zh-Hans-CN"])
        XCTAssertEqual(manager.localized("action_retry"), "重试")
        manager.setLanguage("fr")
        XCTAssertEqual(manager.localized("action_retry"), "Retry")
        XCTAssertEqual(manager.localized("missing_translation"), "missing_translation")
    }
}
