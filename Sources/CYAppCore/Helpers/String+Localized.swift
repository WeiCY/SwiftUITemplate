import Foundation

// MARK: - 模板内置文案本地化

extension String {
    /// 模板内置 UI 文案本地化。
    /// 读取 `CYAppCore` 包内的 `Localizable.strings`（含 en / zh-Hans），
    /// 找不到翻译时回退为原文（即 key 本身），因此即使未做本地化也不会显示空白。
    ///
    /// ```swift
    /// Text("error_generic".cyLocalized)
    /// ```
    public var cyLocalized: String {
        Bundle.module.localizedString(forKey: self, value: self, table: "Localizable")
    }
}
