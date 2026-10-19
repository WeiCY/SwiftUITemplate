import SwiftUI

// MARK: - 语义化字体系统
//
// 保持全局字体层级一致性和可读性，统一字体命名规范。
// 所有字号基于 `Font.TextStyle`，自动响应系统「动态字体（Dynamic Type）」，
// 在无障碍「更大字体」设置下会自适应放大。
//
// 用法：
// ```swift
// Text("标题").font(CYAppFont.h1)
// Text("正文").font(CYAppFont.bodyMedium)
// Text("说明").font(CYAppFont.caption)
// ```

public struct CYAppFont {
    private static func font(_ style: Font.TextStyle, weight: Font.Weight, monospaced: Bool) -> Font {
        let tokens = CYDesignConfiguration.current
        if let name = tokens.fontName, !monospaced {
            let size: CGFloat
            switch style {
            case .largeTitle: size = 34
            case .title: size = 28
            case .title2: size = 22
            case .title3: size = 20
            case .headline, .body: size = 17
            case .callout: size = 16
            default: size = 12
            }
            return .custom(name, size: size, relativeTo: style).weight(weight)
        }
        return .system(style, design: monospaced ? .monospaced : tokens.fontDesign).weight(weight)
    }
    
    // MARK: - 标题
    
    /// H1 标题（largeTitle + bold）
    public static var h1: Font { font(.largeTitle, weight: .bold, monospaced: false) }
    /// H2 标题（title + bold）
    public static var h2: Font { font(.title, weight: .bold, monospaced: false) }
    /// H3 标题（title2 + bold）
    public static var h3: Font { font(.title2, weight: .bold, monospaced: false) }
    /// H4 标题（title3 + semibold）
    public static var h4: Font { font(.title3, weight: .semibold, monospaced: false) }
    
    // MARK: - 正文
    
    /// 大正文（headline）
    public static var bodyLarge: Font { font(.headline, weight: .regular, monospaced: false) }
    /// 中正文（body，默认）
    public static var bodyMedium: Font { font(.body, weight: .regular, monospaced: false) }
    /// 小正文（callout）
    public static var bodySmall: Font { font(.callout, weight: .regular, monospaced: false) }
    
    // MARK: - 说明 & 标签
    
    /// 说明文字（caption）
    public static var caption: Font { font(.caption, weight: .regular, monospaced: false) }
    /// 按钮文字（body + bold）
    public static var button: Font { font(.body, weight: .bold, monospaced: false) }
    /// 标签文字（callout + medium）
    public static var label: Font { font(.callout, weight: .medium, monospaced: false) }
    
    // MARK: - 等宽字体（代码或数字）
    
    /// 等宽正文（body）
    public static var mono: Font { font(.body, weight: .regular, monospaced: true) }
    /// 等宽粗体（body bold）
    public static var monoBold: Font { font(.body, weight: .bold, monospaced: true) }
    /// 等宽大号（title bold）
    public static var monoLarge: Font { font(.title, weight: .bold, monospaced: true) }
    
    // MARK: - 数字显示
    
    /// 大号数字（title black）
    public static var numberLarge: Font { font(.title, weight: .black, monospaced: true) }
    /// 中号数字（headline bold）
    public static var numberMedium: Font { font(.headline, weight: .bold, monospaced: true) }
    /// 小号数字（caption bold）
    public static var numberSmall: Font { font(.caption, weight: .bold, monospaced: true) }
}
