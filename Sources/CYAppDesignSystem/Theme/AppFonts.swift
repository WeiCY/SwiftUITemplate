import SwiftUI

// MARK: - 语义化字体系统
//
// 保持全局字体层级一致性和可读性，统一字体命名规范。
//
// 用法：
// ```swift
// Text("标题").font(CYAppFont.h1)
// Text("正文").font(CYAppFont.bodyMedium)
// Text("说明").font(CYAppFont.caption)
// ```

public struct CYAppFont {
    
    // MARK: - 标题
    
    /// H1 标题（32pt bold）
    public static let h1 = Font.system(size: 32, weight: .bold, design: .default)
    /// H2 标题（28pt bold）
    public static let h2 = Font.system(size: 28, weight: .bold, design: .default)
    /// H3 标题（24pt bold）
    public static let h3 = Font.system(size: 24, weight: .bold, design: .default)
    /// H4 标题（20pt semibold）
    public static let h4 = Font.system(size: 20, weight: .semibold, design: .default)
    
    // MARK: - 正文
    
    /// 大正文（18pt）
    public static let bodyLarge = Font.system(size: 18, weight: .regular, design: .default)
    /// 中正文（16pt，默认）
    public static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)
    /// 小正文（14pt）
    public static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
    
    // MARK: - 说明 & 标签
    
    /// 说明文字（12pt）
    public static let caption = Font.system(size: 12, weight: .regular, design: .default)
    /// 按钮文字（16pt bold）
    public static let button = Font.system(size: 16, weight: .bold, design: .default)
    /// 标签文字（14pt medium）
    public static let label = Font.system(size: 14, weight: .medium, design: .default)
    
    // MARK: - 等宽字体（代码或数字）
    
    /// 等宽正文（14pt）
    public static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    /// 等宽粗体（14pt bold）
    public static let monoBold = Font.system(size: 14, weight: .bold, design: .monospaced)
    /// 等宽大号（24pt bold）
    public static let monoLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
    
    // MARK: - 数字显示
    
    /// 大号数字（24pt black）
    public static let numberLarge = Font.system(size: 24, weight: .black, design: .monospaced)
    /// 中号数字（18pt bold）
    public static let numberMedium = Font.system(size: 18, weight: .bold, design: .monospaced)
    /// 小号数字（10pt bold）
    public static let numberSmall = Font.system(size: 10, weight: .bold, design: .monospaced)
}
