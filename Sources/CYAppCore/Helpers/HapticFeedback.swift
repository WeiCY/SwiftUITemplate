#if canImport(UIKit)
import UIKit

// MARK: - 触觉反馈管理器
//
// 统一封装触觉反馈调用，提供一致的震动体验。
//
// 用法：
// ```swift
// CYHapticFeedback.success()       // 成功反馈
// CYHapticFeedback.impact(.medium) // 中等力度
// CYHapticFeedback.selection()     // 选择变化（如滚轮）
// ```

public final class CYHapticFeedback {
    
    private init() {}
    
    // MARK: - 通知反馈
    
    /// 触发成功反馈
    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// 触发警告反馈
    public static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    /// 触发错误反馈
    public static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - 力度反馈
    
    /// 触发指定力度的反馈
    /// - Parameter style: 力度样式（默认 .medium）
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// 轻触反馈
    public static func light() {
        impact(.light)
    }
    
    /// 中等力度反馈
    public static func medium() {
        impact(.medium)
    }
    
    /// 重触反馈
    public static func heavy() {
        impact(.heavy)
    }
    
    /// 柔软反馈（iOS 13+）
    public static func soft() {
        impact(.soft)
    }
    
    /// 刚性反馈（iOS 13+）
    public static func rigid() {
        impact(.rigid)
    }
    
    // MARK: - 选择反馈
    
    /// 触发选择变化反馈（如滚轮选择）
    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
#endif
