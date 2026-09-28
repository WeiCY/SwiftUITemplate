import SwiftUI
import os

// MARK: - 语义化颜色系统
//
// 跨平台颜色定义，自动适配浅色/深色模式。
// 所有颜色通过语义化命名，避免硬编码颜色值。
//
// 与主题系统的关系：
// - CYAppTheme 控制 .preferredColorScheme() 切换浅色/深色
// - CYAppColor 基于系统语义色，自动响应 ColorScheme 变化
// - 无需手动处理深色模式下的颜色切换
//
// 用法：
// ```swift
// Text("标题").foregroundStyle(CYAppColor.textPrimary)
// Rectangle().fill(CYAppColor.background)
// CYAppColor.accent  // 强调色（跟随系统 tintColor）
// ```
//
// 扩展建议：
// 如需品牌色（如 App 主色、副色），在业务项目中扩展：
// ```swift
// extension CYAppColor {
//     static let brand = Color("BrandColor")       // Asset Catalog 中定义
//     static let brandLight = Color("BrandLight")  // 支持深色模式变体
// }
// ```

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct CYAppColor {

    // MARK: - 可覆盖的品牌色

    /// 可覆盖的品牌色主题。
    public struct Theme: Sendable {
        /// 主色调（品牌色）
        public var primary: Color
        /// 强调色
        public var accent: Color

        public init(primary: Color = .indigo, accent: Color = .accentColor) {
            self.primary = primary
            self.accent = accent
        }
    }

    /// 线程安全的全局品牌色覆盖（默认 `.indigo` / 系统 AccentColor）。
    private static let theme = OSAllocatedUnfairLock(initialState: Theme())

    /// 覆盖品牌色，无需修改模板源码。
    ///
    /// 在 App 启动时调用一次即可（通常在 `AppBootstrap` 中）：
    /// ```swift
    /// CYAppColor.configure(primary: Color(hex: "#FF6B00"), accent: Color(hex: "#00A3FF"))
    /// ```
    /// 未传入的参数保持当前值。
    public static func configure(primary: Color? = nil, accent: Color? = nil) {
        theme.withLock {
            if let primary { $0.primary = primary }
            if let accent { $0.accent = accent }
        }
    }

    /// 恢复默认品牌色（测试隔离或重置配置时使用）。
    public static func reset() {
        theme.withLock { $0 = Theme() }
    }

    // MARK: - 品牌色

    /// 主色调（品牌色）。默认 `.indigo`，可通过 `configure(primary:)` 覆盖。
    /// 使用固定色而非 `Color.primary`，避免在深色模式下与白色文字混用导致不可见。
    public static var primary: Color { theme.withLock { $0.primary } }
    /// 副色调（系统自适应辅助色，用于次要文字/边框）
    public static let secondary = Color.secondary
    /// 强调色（默认跟随 App 全局 AccentColor，可覆盖）
    public static var accent: Color { theme.withLock { $0.accent } }
    
    // MARK: - 背景色
    
    /// 主背景
    public static var background: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    /// 副背景
    public static var secondaryBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #else
        return Color(nsColor: .underPageBackgroundColor)
        #endif
    }
    
    /// 三级背景
    public static var tertiaryBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .tertiarySystemBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    // MARK: - 文字色
    
    /// 主文字色
    public static let textPrimary = Color.primary
    /// 副文字色
    public static let textSecondary = Color.secondary
    /// 三级文字色
    public static let textTertiary = Color.secondary.opacity(0.6)
    
    // MARK: - 状态色
    
    /// 成功（绿色）
    public static let success = Color.green
    /// 警告（橙色）
    public static let warning = Color.orange
    /// 错误（红色）
    public static let error = Color.red
    /// 信息（蓝色）
    public static let info = Color.blue
    
    // MARK: - UI 元素
    
    /// 分隔线
    public static var separator: Color {
        #if canImport(UIKit)
        return Color(uiColor: .separator)
        #else
        return Color(nsColor: .separatorColor)
        #endif
    }
    
    /// 边框
    public static var border: Color {
        #if canImport(UIKit)
        return Color(uiColor: .opaqueSeparator)
        #else
        return Color(nsColor: .separatorColor)
        #endif
    }
    
    /// 占位符
    public static var placeholder: Color {
        #if canImport(UIKit)
        return Color(uiColor: .placeholderText)
        #else
        return Color(nsColor: .placeholderTextColor)
        #endif
    }
    
    // MARK: - 阴影
    
    /// 阴影色
    public static let shadow = Color.black.opacity(0.08)
}
