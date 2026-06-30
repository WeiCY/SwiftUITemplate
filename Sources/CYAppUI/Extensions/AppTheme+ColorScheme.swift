import SwiftUI
import CYAppCore

// MARK: - CYAppTheme → SwiftUI ColorScheme 桥接
//
// 将纯数据层的 CYAppTheme 转换为 SwiftUI 的 ColorScheme，
// 用于 `.preferredColorScheme()` 修饰符。
//
// 用法：
// ```swift
// // App 入口
// RootView()
//     .preferredColorScheme(appState.theme.colorScheme)
//
// // .system 返回 nil → 跟随系统
// // .light  返回 .light → 强制浅色
// // .dark   返回 .dark  → 强制深色
// ```

/// CYAppTheme 到 SwiftUI ColorScheme 的转换
public extension CYAppTheme {
    /// 转换为 SwiftUI ColorScheme
    ///
    /// - `.system` → `nil`（跟随系统设置）
    /// - `.light`  → `.light`
    /// - `.dark`   → `.dark`
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
