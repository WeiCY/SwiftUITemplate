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

    private init() { restore() }

    private let lock = OSAllocatedUnfairLock(initialState: Bundle.main as Bundle)
    private let langLock = OSAllocatedUnfairLock(
        initialState: Locale.current.language.languageCode?.identifier ?? "en"
    )

    public var currentLanguage: String { langLock.withLock { $0 } }

    public var isChinese: Bool { currentLanguage.hasPrefix("zh") }

    public var isEnglish: Bool { currentLanguage.hasPrefix("en") }

    public var currentDisplayName: String {
        displayName(for: currentLanguage)
    }

    public func availableLanguages() -> [String] {
        guard let localizations = Bundle.main.localizations as [String]? else { return ["en"] }
        return localizations.filter { $0 != "Base" }.sorted()
    }

    public func setLanguage(_ languageCode: String) {
        langLock.withLock { $0 = languageCode }

        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.set(languageCode, forKey: CYAppConstants.keyLanguagePreference)

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            lock.withLock { $0 = bundle }
        } else {
            lock.withLock { $0 = Bundle.main }
        }
    }

    @discardableResult
    public func restore() -> String {
        if let saved = UserDefaults.standard.string(forKey: CYAppConstants.keyLanguagePreference) {
            setLanguage(saved)
            return saved
        }
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        langLock.withLock { $0 = systemLang }
        lock.withLock { $0 = Bundle.main }
        return systemLang
    }

    public func resetToSystem() {
        UserDefaults.standard.removeObject(forKey: CYAppConstants.keyLanguagePreference)
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        langLock.withLock { $0 = systemLang }
        lock.withLock { $0 = Bundle.main }
    }

    public func localized(_ key: String, tableName: String? = nil) -> String {
        let bundle = lock.withLock { $0 }
        return bundle.localizedString(forKey: key, value: key, table: tableName)
    }

    public func displayName(for languageCode: String) -> String {
        Locale(identifier: languageCode).localizedString(forIdentifier: languageCode) ?? languageCode
    }
}
