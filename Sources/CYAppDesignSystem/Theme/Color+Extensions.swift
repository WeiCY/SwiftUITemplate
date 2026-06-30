import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Color 扩展
//
// 提供随机颜色、亮度判断、颜色混合、对比色等功能。
//
// 用法：
// ```swift
// Color.random           // 随机颜色
// Color.randomPastel     // 随机浅色（适合背景）
// someColor.isLight      // 判断是否为浅色
// someColor.contrastingTextColor // 自动返回黑/白文字色
// color.lighter(by: 0.3) // 变浅
// color.darker(by: 0.2)  // 变深
// color.mix(with: .blue, amount: 0.5) // 混色
// ```

extension Color {
    
    // MARK: - 随机颜色
    
    /// 返回一个随机颜色
    public static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
    
    /// 返回一个随机浅色（适合用作背景）
    public static var randomPastel: Color {
        return Color(
            red: .random(in: 0.6...1),
            green: .random(in: 0.6...1),
            blue: .random(in: 0.6...1)
        )
    }
    
    // MARK: - 亮度判断
    
    /// 是否为浅色（基于感知亮度公式: 0.299R + 0.587G + 0.114B）
    public var isLight: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        #if canImport(UIKit)
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: nil)
        #elseif canImport(AppKit)
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        #endif
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5
    }
    
    /// 是否为深色
    public var isDark: Bool {
        return !isLight
    }
    
    /// 返回与当前颜色形成对比的文字色（浅色背景返回黑色，深色背景返回白色）
    public var contrastingTextColor: Color {
        return isLight ? .black : .white
    }
    
    // MARK: - 颜色调整
    
    /// 返回更浅的颜色
    /// - Parameter amount: 0.0（不变）到 1.0（纯白），默认 0.2
    public func lighter(by amount: CGFloat = 0.2) -> Color {
        return mix(with: .white, amount: amount)
    }
    
    /// 返回更深的颜色
    /// - Parameter amount: 0.0（不变）到 1.0（纯黑），默认 0.2
    public func darker(by amount: CGFloat = 0.2) -> Color {
        return mix(with: .black, amount: amount)
    }
    
    /// 与另一种颜色混合
    /// - 参数：
    ///   - color: 混合的目标颜色
    ///   - amount: 0.0（原色）到 1.0（目标色）
    public func mix(with color: Color, amount: CGFloat) -> Color {
        #if canImport(UIKit)
        let c1 = UIColor(self)
        let c2 = UIColor(color)
        #elseif canImport(AppKit)
        let c1 = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        let c2 = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.black
        #endif
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let t = min(max(amount, 0), 1)
        
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t),
            opacity: Double(a1 + (a2 - a1) * t)
        )
    }
}
