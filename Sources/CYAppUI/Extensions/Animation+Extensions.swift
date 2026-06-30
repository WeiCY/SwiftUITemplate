import SwiftUI

// MARK: - Animation 弹簧动画预设
//
// 提供常用的弹簧动画预设，适配不同 UI 交互场景。
//
// 用法：
// ```swift
// .animation(.snappy, value: isPressed)  // 按钮快速反馈
// .animation(.bouncy, value: showPopup) // 弹窗弹出
// .animation(.smooth, value: page)      // 页面切换
// ```

extension Animation {
    
    // MARK: - 弹簧预设
    
    /// 快速弹簧（响应快，弹性小）
    /// 适用于按钮、开关、小 UI 交互
    public static var snappy: Animation {
        return .spring(response: 0.3, dampingFraction: 0.75)
    }
    
    /// 弹性弹簧（响应适中，弹性大）
    /// 适用于弹窗、提醒、吸引注意力的动画
    public static var bouncy: Animation {
        return .spring(response: 0.5, dampingFraction: 0.55)
    }
    
    /// 平滑弹簧（无弹性，柔和）
    /// 适用于页面切换、内容展示
    public static var smooth: Animation {
        return .spring(response: 0.4, dampingFraction: 0.9)
    }
    
    /// 柔和弹簧（响应慢，微妙）
    /// 适用于背景元素、微妙的状态变化
    public static var gentle: Animation {
        return .spring(response: 0.6, dampingFraction: 0.85)
    }
    
    /// 极速弹簧（非常快）
    public static var quick: Animation {
        return .spring(response: 0.2, dampingFraction: 0.7)
    }
}
