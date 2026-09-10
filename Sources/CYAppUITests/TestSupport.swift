import Foundation
import CYAppCore

// MARK: - AppState 测试替身
//
// CYAppState 默认通过 CYThemeManager / CYLocalizationManager 单例持久化到 UserDefaults.standard，
// 会导致测试状态跨用例、跨运行泄漏（例如 theme = .dark 残留使 testAppStateInitialState 失败）。
// 测试中统一注入以下内存实现，保证测试套件完全封闭、可重复执行。

/// 内存版主题管理器 — 实现 `CYThemeManaging`，不触碰 UserDefaults
final class MockThemeManager: CYThemeManaging, @unchecked Sendable {

    /// 当前已保存的主题（初始值 .system，与生产默认一致）
    var saved: CYAppTheme = .system

    func savedTheme() -> CYAppTheme { saved }

    func save(_ theme: CYAppTheme) { saved = theme }

    func apply(_ theme: CYAppTheme) {}
}

/// 内存版多语言管理器 — 实现 `CYLocalizationManaging`，不触碰 UserDefaults
final class MockLocalizationManager: CYLocalizationManaging, @unchecked Sendable {

    var currentLanguage: String = "en"

    var isChinese: Bool { currentLanguage.hasPrefix("zh") }

    var isEnglish: Bool { currentLanguage.hasPrefix("en") }

    var currentDisplayName: String { currentLanguage }

    func availableLanguages() -> [String] { ["en", "zh-Hans"] }

    func setLanguage(_ languageCode: String) { currentLanguage = languageCode }

    @discardableResult
    func restore() -> String { currentLanguage }

    func resetToSystem() { currentLanguage = "en" }

    func localized(_ key: String, tableName: String?) -> String { key }

    func displayName(for languageCode: String) -> String { languageCode }
}

// MARK: - UserDefaults 持久化清理

enum AppStateTestSupport {

    /// 清理 CYAppState 及默认管理器写入 UserDefaults.standard 的全部键。
    ///
    /// 在 setUp / tearDown 中调用：
    /// - 清除本机历史运行遗留的持久化状态（跨运行隔离）
    /// - 防御未来新增测试直接使用默认单例构造 CYAppState（跨用例隔离）
    static func resetPersistedPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: CYAppConstants.keyThemePreference)
        defaults.removeObject(forKey: CYAppConstants.keyOnboardingShown)
        defaults.removeObject(forKey: CYAppConstants.keyLanguagePreference)
        defaults.removeObject(forKey: "AppleLanguages")
    }
}
