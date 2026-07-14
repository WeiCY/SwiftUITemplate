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
    
    // MARK: - 标题
    
    /// H1 标题（largeTitle + bold）
    public static let h1 = Font.system(.largeTitle, design: .default).weight(.bold)
    /// H2 标题（title + bold）
    public static let h2 = Font.system(.title, design: .default).weight(.bold)
    /// H3 标题（title2 + bold）
    public static let h3 = Font.system(.title2, design: .default).weight(.bold)
    /// H4 标题（title3 + semibold）
    public static let h4 = Font.system(.title3, design: .default).weight(.semibold)
    
    // MARK: - 正文
    
    /// 大正文（headline）
    public static let bodyLarge = Font.system(.headline, design: .default).weight(.regular)
    /// 中正文（body，默认）
    public static let bodyMedium = Font.system(.body, design: .default).weight(.regular)
    /// 小正文（callout）
    public static let bodySmall = Font.system(.callout, design: .default).weight(.regular)
    
    // MARK: - 说明 & 标签
    
    /// 说明文字（caption）
    public static let caption = Font.system(.caption, design: .default).weight(.regular)
    /// 按钮文字（body + bold）
    public static let button = Font.system(.body, design: .default).weight(.bold)
    /// 标签文字（callout + medium）
    public static let label = Font.system(.callout, design: .default).weight(.medium)
    
    // MARK: - 等宽字体（代码或数字）
    
    /// 等宽正文（body）
    public static let mono = Font.system(.body, design: .monospaced).weight(.regular)
    /// 等宽粗体（body bold）
    public static let monoBold = Font.system(.body, design: .monospaced).weight(.bold)
    /// 等宽大号（title bold）
    public static let monoLarge = Font.system(.title, design: .monospaced).weight(.bold)
    
    // MARK: - 数字显示
    
    /// 大号数字（title black）
    public static let numberLarge = Font.system(.title, design: .monospaced).weight(.black)
    /// 中号数字（headline bold）
    public static let numberMedium = Font.system(.headline, design: .monospaced).weight(.bold)
    /// 小号数字（caption bold）
    public static let numberSmall = Font.system(.caption, design: .monospaced).weight(.bold)
}
