import SwiftUI

// MARK: - 颜色十六进制 扩展
//
// 通过十六进制字符串创建 Color，支持 RGB/RRGGBBAA 格式。
//
// 用法：
// ```swift
// Color(hex: "#FF0000")  // 红色
// Color(hex: "FF0000")   // 红色（不带 #）
// Color(hex: "FF000080") // 半透明红色（RRGGBBAA，与 CSS 惯例一致）
// ```

extension Color {
    /// 通过十六进制字符串创建颜色
    /// - Parameter hex: 十六进制字符串（支持 "#FF0000"、"FF0000"、"FF000080" 格式）
    /// - Note: 8 位格式按 **RRGGBBAA** 解析（与 CSS / Android 惯例一致），
    ///   而非 ARGB。如需不透明红色：`"FF0000FF"`。
    ///   非法输入（空串、非十六进制字符、长度非 3/6/8）时返回透明色（.clear），
    ///   而非产生「近透明黑黄」等误导性颜色。
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard !hex.isEmpty,
              Scanner(string: hex).scanHexInt64(&int),
              [3, 6, 8].contains(hex.count)
        else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 0)
            return
        }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // RRGGBBAA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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
