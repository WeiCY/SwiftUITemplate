import Foundation

// MARK: - 数值类型扩展 (Double / Int / CGFloat)
//
// 提供货币格式化、字节大小、四舍五入、角度转换、时间格式化等。
//
// 用法：
// ```swift
// 1234.5.formattedAsCurrency(symbol: "¥")   // "¥1,234.50"
// 1536.0.formattedAsBytes()                  // "1.5 KB"
// 3.14159.rounded(to: 2)                     // 3.14
// 1000000.formattedWithSeparator()           // "1,000,000"
// 3620.timeString                            // "1:00:20"
// 90.0.degreesToRadians                      // π/2
// ```

// MARK: - Double 扩展

extension Double {
    
    /// 格式化为货币字符串
    public func formattedAsCurrency(symbol: String = "¥", decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = symbol
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// 格式化为人类可读的字节大小
    public func formattedAsBytes() -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useAll]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(self))
    }
    
    /// 四舍五入到指定小数位
    public func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
    
    /// 限制在指定范围内
    public func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
    
    /// 角度转弧度
    public var degreesToRadians: Double {
        return self * .pi / 180.0
    }
    
    /// 弧度转角度
    public var radiansToDegrees: Double {
        return self * 180.0 / .pi
    }
    
    /// 是否在指定范围内（含边界）
    public func isBetween(_ lower: Double, _ upper: Double) -> Bool {
        return self >= lower && self <= upper
    }
    
    /// 千分位格式化（如 1000000 → "1,000,000"）
    public func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// 格式化为百分比字符串
    public func formattedAsPercentage(decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self * 100))%"
    }
}

// MARK: - Int 扩展

extension Int {
    
    /// 是否为偶数
    public var isEven: Bool { self % 2 == 0 }
    
    /// 是否为奇数
    public var isOdd: Bool { self % 2 != 0 }
    
    /// 是否为正数
    public var isPositive: Bool { self > 0 }
    
    /// 是否为负数
    public var isNegative: Bool { self < 0 }
    
    /// 限制在指定范围内
    public func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
    
    /// 千分位格式化
    public func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// 秒数转为时间字符串（如 3620 → "1:00:20"）
    public var timeString: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// 重复执行指定次数的闭包
    /// 用法: 5.times { print("Hello") }
    public func times(_ closure: () -> Void) {
        guard self > 0 else { return }
        for _ in 0..<self { closure() }
    }
}

// MARK: - CGFloat 扩展

extension CGFloat {
    
    /// 角度转弧度
    public var degreesToRadians: CGFloat { self * .pi / 180.0 }
    
    /// 弧度转角度
    public var radiansToDegrees: CGFloat { self * 180.0 / .pi }
    
    /// 限制在指定范围内
    public func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
