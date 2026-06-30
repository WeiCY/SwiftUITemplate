import Foundation

// MARK: - 主题偏好枚举
//
// 纯数据层定义，不依赖 SwiftUI。在 View 层通过扩展转换为 ColorScheme。
//
// 架构关系：
// ```
// CYAppTheme（枚举）
//   ↓ didSet 自动持久化
// CYAppState.theme（全局状态）
//   ↓ 持久化 + UIKit 应用
// CYThemeManager（管理工具）
//   ↓ SwiftUI 桥接
// CYAppTheme.colorScheme（CYAppUI 扩展）
// ```
//
// 用法：
// ```swift
// // 读取主题状态
// appState.theme.isDarkMode   // nil = 跟随系统, true/false = 强制
//
// // 切换主题（自动持久化）
// appState.theme = .dark
//
// // SwiftUI 绑定
// .preferredColorScheme(appState.theme.colorScheme)
//
// // UIKit 全局应用（混合 UIKit 页面时使用）
// CYThemeManager.saveAndApply(.dark)
// ```

/// 主题偏好枚举
///
/// | 值       | 行为                     |
/// |----------|--------------------------|
/// | .system  | 跟随系统设置（默认）       |
/// | .light   | 强制浅色模式              |
/// | .dark    | 强制深色模式                |
public enum CYAppTheme: String, CaseIterable, Sendable {
    /// 跟随系统设置
    case system
    /// 强制浅色模式
    case light
    /// 强制深色模式
    case dark
    
    /// 是否为深色模式
    ///
    /// - Returns: `.system` 返回 nil（跟随系统），`.light` 返回 false，`.dark` 返回 true
    public var isDarkMode: Bool? {
        switch self {
        case .system: return nil
        case .light: return false
        case .dark: return true
        }
    }
    
    /// 显示名称（用于设置页面 UI）
    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}
