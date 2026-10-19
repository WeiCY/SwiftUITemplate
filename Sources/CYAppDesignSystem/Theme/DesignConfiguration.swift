import SwiftUI
import os

/// 高频品牌配置。仅支持启动时配置：在创建界面前调用，不保证运行时替换触发刷新。
/// 自定义字体名称应由宿主注册；使用 relativeTo 保持 Dynamic Type。
public struct CYDesignTokens: Sendable {
    public var primary: Color = .indigo
    public var accent: Color = .accentColor
    public var onPrimary: Color = .white
    public var fontDesign: Font.Design = .default
    public var fontName: String?
    public var spacingScale: CGFloat = 1
    public var cornerScale: CGFloat = 1
    public var buttonHeight: CGFloat = 48
    public var inputHeight: CGFloat = 44

    public init() {}

    public static var alternate: Self {
        var tokens = Self()
        tokens.primary = .teal
        tokens.accent = .orange
        tokens.onPrimary = .white
        tokens.fontDesign = .rounded
        tokens.spacingScale = 1.15
        tokens.cornerScale = 1.5
        tokens.buttonHeight = 52
        return tokens
    }
}

public enum CYDesignConfiguration {
    private static let storage = OSAllocatedUnfairLock(initialState: CYDesignTokens())
    public static var current: CYDesignTokens { storage.withLock { $0 } }

    /// 启动时调用；无效尺寸恢复默认值，避免 NaN/负值进入布局。
    public static func configure(_ tokens: CYDesignTokens) {
        var tokens = tokens
        if !tokens.spacingScale.isFinite || tokens.spacingScale <= 0 { tokens.spacingScale = 1 }
        if !tokens.cornerScale.isFinite || tokens.cornerScale < 0 { tokens.cornerScale = 1 }
        if !tokens.buttonHeight.isFinite || tokens.buttonHeight <= 0 { tokens.buttonHeight = 48 }
        if !tokens.inputHeight.isFinite || tokens.inputHeight <= 0 { tokens.inputHeight = 44 }
        let normalized = tokens
        storage.withLock { $0 = normalized }
    }

    public static func reset() { configure(CYDesignTokens()) }

    static func updateColors(primary: Color?, accent: Color?) {
        storage.withLock {
            if let primary { $0.primary = primary }
            if let accent { $0.accent = accent }
        }
    }
}
