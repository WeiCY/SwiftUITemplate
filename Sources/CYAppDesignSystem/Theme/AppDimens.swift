import SwiftUI

// MARK: - 尺寸与间距规范
//
// 统一管理外边距、内边距、圆角半径和常见 UI 元素尺寸。
//
// 用法：
// ```swift
// .padding(CYAppDimens.marginM)          // 16pt
// .cornerRadius(CYAppDimens.radiusL)     // 12pt
// .frame(height: CYAppDimens.buttonHeight) // 48pt
// ```

public struct CYAppDimens {
    
    // MARK: - 间距 & 外边距
    
    /// 超小间距（4pt）
    public static let marginXS: CGFloat = 4.0
    /// 小间距（8pt）
    public static let marginS: CGFloat = 8.0
    /// 中间距（16pt）
    public static let marginM: CGFloat = 16.0
    /// 大间距（24pt）
    public static let marginL: CGFloat = 24.0
    /// 超大间距（32pt）
    public static let marginXL: CGFloat = 32.0
    /// 超超大间距（48pt）
    public static let marginXXL: CGFloat = 48.0
    
    // MARK: - 圆角
    
    /// 小圆角（4pt）
    public static let radiusS: CGFloat = 4.0
    /// 中圆角（8pt）
    public static let radiusM: CGFloat = 8.0
    /// 大圆角（12pt）
    public static let radiusL: CGFloat = 12.0
    /// 超大圆角（20pt）
    public static let radiusXL: CGFloat = 20.0
    /// 全圆角（胶囊形）
    public static let radiusFull: CGFloat = .infinity
    
    // MARK: - UI 元素
    
    /// 按钮高度（48pt）
    public static let buttonHeight: CGFloat = 48.0
    /// 输入框高度（44pt）
    public static let inputHeight: CGFloat = 44.0
    /// 小图标（16pt）
    public static let iconSizeS: CGFloat = 16.0
    /// 中图标（24pt）
    public static let iconSizeM: CGFloat = 24.0
    /// 大图标（32pt）
    public static let iconSizeL: CGFloat = 32.0
    
    // MARK: - 线宽
    
    /// 分隔线高度（0.5pt）
    public static let separatorHeight: CGFloat = 0.5
    /// 边框宽度（1pt）
    public static let borderWidth: CGFloat = 1.0
    
    // MARK: - 阴影
    
    /// 阴影半径（4pt）
    public static let shadowRadius: CGFloat = 4.0
    /// 阴影偏移（2pt）
    public static let shadowOffset: CGFloat = 2.0
}
