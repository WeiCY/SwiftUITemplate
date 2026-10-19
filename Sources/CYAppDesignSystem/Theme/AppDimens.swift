import SwiftUI

// MARK: - 尺寸与间距规范
//
// 统一管理外边距、内边距、圆角半径和常见 UI 元素尺寸。
//
// 用法：
// ```swift
// .padding(CYAppDimens.marginM)          // 16pt
// .clipShape(.rect(cornerRadius: CYAppDimens.radiusL)) // 12pt
// .frame(height: CYAppDimens.buttonHeight) // 48pt
// ```

public struct CYAppDimens {
    
    // MARK: - 间距 & 外边距
    
    /// 超小间距（4pt）
    public static var marginXS: CGFloat { 4.0 * CYDesignConfiguration.current.spacingScale }
    /// 小间距（8pt）
    public static var marginS: CGFloat { 8.0 * CYDesignConfiguration.current.spacingScale }
    /// 中间距（16pt）
    public static var marginM: CGFloat { 16.0 * CYDesignConfiguration.current.spacingScale }
    /// 大间距（24pt）
    public static var marginL: CGFloat { 24.0 * CYDesignConfiguration.current.spacingScale }
    /// 超大间距（32pt）
    public static var marginXL: CGFloat { 32.0 * CYDesignConfiguration.current.spacingScale }
    /// 超超大间距（48pt）
    public static var marginXXL: CGFloat { 48.0 * CYDesignConfiguration.current.spacingScale }
    
    // MARK: - 圆角
    
    /// 小圆角（4pt）
    public static var radiusS: CGFloat { 4.0 * CYDesignConfiguration.current.cornerScale }
    /// 中圆角（8pt）
    public static var radiusM: CGFloat { 8.0 * CYDesignConfiguration.current.cornerScale }
    /// 大圆角（12pt）
    public static var radiusL: CGFloat { 12.0 * CYDesignConfiguration.current.cornerScale }
    /// 超大圆角（20pt）
    public static var radiusXL: CGFloat { 20.0 * CYDesignConfiguration.current.cornerScale }
    /// 卡片圆角（16pt，Loading 弹窗等）
    public static var radiusCard: CGFloat { 16.0 * CYDesignConfiguration.current.cornerScale }
    
    // MARK: - UI 元素
    
    /// 按钮高度（48pt）
    public static var buttonHeight: CGFloat { CYDesignConfiguration.current.buttonHeight }
    /// 输入框高度（44pt）
    public static var inputHeight: CGFloat { CYDesignConfiguration.current.inputHeight }
    /// 小图标（16pt）
    public static let iconSizeS: CGFloat = 16.0
    /// 中图标（24pt）
    public static let iconSizeM: CGFloat = 24.0
    /// 大图标（32pt）
    public static let iconSizeL: CGFloat = 32.0
    /// 加载指示器尺寸（64pt）
    public static let loaderSize: CGFloat = 64.0
    
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
