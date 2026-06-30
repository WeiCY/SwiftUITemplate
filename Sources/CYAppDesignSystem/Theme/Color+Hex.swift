import SwiftUI

// MARK: - 颜色十六进制 扩展
//
// 通过十六进制字符串创建 Color，支持 RGB/ARGB 格式。
//
// 用法：
// ```swift
// Color(hex: "#FF0000")  // 红色
// Color(hex: "FF0000")   // 红色（不带 #）
// Color(hex: "80FF0000") // 半透明红色
// ```

extension Color {
    /// 通过十六进制字符串创建颜色
    /// - Parameter hex: 十六进制字符串（支持 "#FF0000"、"FF0000"、"80FF0000" 格式）
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
