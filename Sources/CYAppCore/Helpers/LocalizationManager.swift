import Foundation

// MARK: - 多语言管理工具
//
// 支持运行时切换 App 语言，无需重启应用。
// 通过替换 Bundle 引用实现即时生效，CYAppState 已自动集成。
//
// ## 前置准备
//
// 在 Xcode 项目中创建本地化资源文件：
// ```
// YourApp/
// ├── en.lproj/
// │   └── Localizable.strings    // 英文翻译
// └── zh-Hans.lproj/
//     └── Localizable.strings    // 中文翻译
// ```
//
// Localizable.strings 示例：
// ```
// "welcome_title" = "欢迎";
// "greeting" = "你好，%@！";
// ```
//
// ## App 入口集成
// ```swift
// @main
// struct MyApp: App {
//     @State private var appState = CYAppState()  // init 时自动恢复语言
//
//     var body: some Scene {
//         WindowGroup {
//             RootView()
//                 .environment(appState)
//                 .id(appState.language)  // ← 语言切换时重建视图树
//         }
//     }
// }
// ```
//
// ## 日常使用
// ```swift
// // 获取翻译
// "welcome_title".localized               // "欢迎"
// "greeting".localized(with: "张三")      // "你好，张三！"
//
// // 切换语言
// appState.setLanguage("en")
//
// // 查看可用语言
// CYLocalizationManager.availableLanguages()  // ["en", "zh-Hans"]
//
// // 始终跟随系统语言（忽略运行时切换）
// "system_only_key".systemLocalized
// ```

public struct CYLocalizationManager {
    
    private init() {}
    
    // MARK: - 内部状态
    
    /// 当前使用的 Bundle（用于加载 .strings 文件）
    private static var _bundle: Bundle = .main
    
    /// 当前语言代码（如 "zh-Hans", "en"）
    private static var _currentLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    // MARK: - 公开 API
    
    /// 当前生效的语言代码
    public static var currentLanguage: String { _currentLanguage }
    
    /// 是否为中文环境
    public static var isChinese: Bool { _currentLanguage.hasPrefix("zh") }
    
    /// 是否为英文环境
    public static var isEnglish: Bool { _currentLanguage.hasPrefix("en") }
    
    // MARK: - 语言管理
    
    /// 扫描 App Bundle 中所有可用的 .lproj 语言
    ///
    /// 返回语言代码数组，如 `["en", "zh-Hans", "ja"]`
    public static func availableLanguages() -> [String] {
        guard let localizations = Bundle.main.localizations as [String]? else { return ["en"] }
        return localizations.filter { $0 != "Base" }.sorted()
    }
    
    /// 切换 App 语言
    ///
    /// 会持久化到 UserDefaults，并更新内部 Bundle 引用。
    /// SwiftUI 界面需要配合 `.id(CYLocalizationManager.currentLanguage)` 刷新。
    ///
    /// - Parameter languageCode: 语言代码，如 "zh-Hans", "en", "ja"
    public static func setLanguage(_ languageCode: String) {
        _currentLanguage = languageCode
        
        // 持久化
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.set(languageCode, forKey: CYAppConstants.keyLanguagePreference)
        
        // 更新 Bundle
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            _bundle = bundle
        } else {
            // 回退到 main bundle
            _bundle = .main
        }
    }
    
    /// 从 UserDefaults 恢复上次保存的语言
    ///
    /// 建议在 App 启动时调用（如 CYAppState.init 中）。
    /// 如果没有保存过，使用系统当前语言。
    @discardableResult
    public static func restore() -> String {
        if let saved = UserDefaults.standard.string(forKey: CYAppConstants.keyLanguagePreference) {
            setLanguage(saved)
            return saved
        }
        // 没有保存过，使用系统语言
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        _currentLanguage = systemLang
        return systemLang
    }
    
    /// 重置为跟随系统语言
    public static func resetToSystem() {
        UserDefaults.standard.removeObject(forKey: CYAppConstants.keyLanguagePreference)
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        _currentLanguage = systemLang
        _bundle = .main
    }
    
    // MARK: - 获取本地化字符串
    
    /// 获取本地化字符串
    ///
    /// - Parameters:
    ///   - key: Localizable.strings 中的 key
    ///   - tableName: strings 文件名（默认 "Localizable"）
    /// - Returns: 本地化后的字符串
    public static func localized(_ key: String, tableName: String? = nil) -> String {
        return _bundle.localizedString(forKey: key, value: nil, table: tableName)
    }
    
    /// 获取带参数的本地化字符串
    ///
    /// - Parameters:
    ///   - key: Localizable.strings 中的 key
    ///   - arguments: 格式化参数
    ///   - tableName: strings 文件名（默认 "Localizable"）
    /// - Returns: 格式化后的本地化字符串
    public static func localized(_ key: String, arguments: CVarArg..., tableName: String? = nil) -> String {
        let format = _bundle.localizedString(forKey: key, value: nil, table: tableName)
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - 当前语言显示名
    
    /// 获取指定语言代码的显示名称
    ///
    /// - Parameter languageCode: 语言代码
    /// - Returns: 本地化的语言名称，如 "简体中文"、"English"
    public static func displayName(for languageCode: String) -> String {
        let locale = Locale(identifier: languageCode)
        return locale.localizedString(forIdentifier: languageCode) ?? languageCode
    }
    
    /// 当前语言的显示名称
    public static var currentDisplayName: String {
        displayName(for: _currentLanguage)
    }
}
