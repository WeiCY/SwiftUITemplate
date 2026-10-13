import Foundation
import os

// MARK: - 多语言管理协议

public protocol CYLocalizationManaging: AnyObject, Sendable {
    var currentLanguage: String { get }
    var isChinese: Bool { get }
    var isEnglish: Bool { get }
    var currentDisplayName: String { get }
    func availableLanguages() -> [String]
    func setLanguage(_ languageCode: String)
    func restore() -> String
    func resetToSystem()
    func localized(_ key: String, tableName: String?) -> String
    func displayName(for languageCode: String) -> String
}

// MARK: - 多语言管理实现

/// 默认多语言管理器，基于 .lproj Bundle + UserDefaults 持久化。
///
/// 支持运行时切换 App 语言，无需重启。
/// 如需自定义语言策略（如服务端下发、远程资源包），实现 `CYLocalizationManaging` 并注册到 DI。
///
/// ## 项目特异化示例
/// ```swift
/// // 自定义实现：服务端下发翻译
/// final class RemoteLocalizationManager: CYLocalizationManaging {
///     private var translations: [String: String] = [:]
///     private(set) var currentLanguage = "en"
///     // ...
/// }
///
/// // 注册到 DI
/// Container.shared.localizationManager.register { RemoteLocalizationManager() }
/// ```
public final class CYLocalizationManager: CYLocalizationManaging, @unchecked Sendable {
    public static let shared = CYLocalizationManager()

    private let bundle: Bundle
    private let defaults: UserDefaults
    private let systemLanguages: [String]
    private let langLock = OSAllocatedUnfairLock(initialState: "en")

    /// 可注入资源包与偏好存储，便于宿主和测试隔离。
    public init(bundle: Bundle = .main, defaults: UserDefaults = .standard, systemLanguages: [String] = Locale.preferredLanguages) {
        self.bundle = bundle
        self.defaults = defaults
        self.systemLanguages = systemLanguages
        restore()
    }

    public var currentLanguage: String { langLock.withLock { $0 } }

    public var isChinese: Bool { currentLanguage.hasPrefix("zh") }

    public var isEnglish: Bool { currentLanguage.hasPrefix("en") }

    public var currentDisplayName: String {
        displayName(for: currentLanguage)
    }

    public func availableLanguages() -> [String] {
        bundle.localizations.filter { $0 != "Base" }.sorted()
    }

    public func setLanguage(_ languageCode: String) {
        langLock.withLock {
            $0 = languageCode
            defaults.set(languageCode, forKey: CYAppConstants.keyLanguagePreference)
        }
    }

    @discardableResult
    public func restore() -> String {
        if let saved = defaults.string(forKey: CYAppConstants.keyLanguagePreference) {
            setLanguage(saved)
            return saved
        }
        let systemLang = systemLanguages.first ?? "en"
        langLock.withLock { $0 = systemLang }
        return systemLang
    }

    public func resetToSystem() {
        defaults.removeObject(forKey: CYAppConstants.keyLanguagePreference)
        // 兼容清理旧版本写入的 override；新版本按资源包显式选语言。
        defaults.removeObject(forKey: "AppleLanguages")
        let systemLang = systemLanguages.first ?? "en"
        langLock.withLock { $0 = systemLang }
    }

    public func localized(_ key: String, tableName: String? = nil) -> String {
        localized(key, tableName: tableName, bundle: bundle)
    }

    /// 为指定资源包选择当前语言；宿主包和模板包保持各自的资源边界。
    public func localized(_ key: String, tableName: String? = nil, bundle: Bundle) -> String {
        let languages = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [currentLanguage, "en"])
        for language in languages + ["en"] {
            if let path = bundle.path(forResource: language, ofType: "lproj"), let localizedBundle = Bundle(path: path) {
                let value = localizedBundle.localizedString(forKey: key, value: key, table: tableName)
                if value != key { return value }
            }
        }
        return bundle.localizedString(forKey: key, value: key, table: tableName)
    }

    public func displayName(for languageCode: String) -> String {
        Locale(identifier: languageCode).localizedString(forIdentifier: languageCode) ?? languageCode
    }
}
