import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 主题管理协议

public protocol CYThemeManaging: AnyObject, Sendable {
    func savedTheme() -> CYAppTheme
    func save(_ theme: CYAppTheme)
    func apply(_ theme: CYAppTheme)
}

// MARK: - 主题管理实现

/// 默认主题管理器，基于 UserDefaults 持久化。
///
/// 通常不需要直接调用，CYAppState 已自动集成。
/// 如需自定义主题策略（如云端同步），实现 `CYThemeManaging` 并注册到 DI。
///
/// ## 项目特异化示例
/// ```swift
/// // 自定义实现：云端同步主题
/// final class CloudThemeManager: CYThemeManaging {
///     func savedTheme() -> CYAppTheme { ... }
///     func save(_ theme: CYAppTheme) { ... }
///     func apply(_ theme: CYAppTheme) { ... }
/// }
///
/// // 注册到 DI（App 启动时）
/// Container.shared.themeManager.register { CloudThemeManager() }
/// ```
public final class CYThemeManager: CYThemeManaging, Sendable {
    public static let shared = CYThemeManager()

    private init() {}

    /// 从 UserDefaults 恢复上次保存的主题偏好
    public func savedTheme() -> CYAppTheme {
        let raw = UserDefaults.standard.string(forKey: CYAppConstants.keyThemePreference)
        return CYAppTheme(rawValue: raw ?? "") ?? .system
    }

    /// 将主题偏好持久化到 UserDefaults
    public func save(_ theme: CYAppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: CYAppConstants.keyThemePreference)
    }

    #if canImport(UIKit)
    /// 将主题应用到所有已连接的 UIWindowScene
    public func apply(_ theme: CYAppTheme) {
        let style: UIUserInterfaceStyle
        switch theme {
        case .system: style = .unspecified
        case .light:  style = .light
        case .dark:   style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
    #else
    public func apply(_ theme: CYAppTheme) {}
    #endif

    /// 保存并立即应用主题
    public func saveAndApply(_ theme: CYAppTheme) {
        save(theme)
        apply(theme)
    }
}
