import Foundation

// MARK: - Date 扩展
//
// 提供日期格式化、时间戳转换、日期比较、日期运算等常用操作。
//
// 用法：
// ```swift
// Date().toString(format: "yyyy-MM-dd HH:mm")  // "2025-01-15 14:30"
// Date().timeAgo()                               // "3小时前"
// Date().isToday                                 // true
// Date().startOfDay                              // 今天 00:00:00
// Date().adding(days: 7)                         // 7天后
// Date(timestamp: 1700000000)                    // 从时间戳创建
// ```

extension Date {
    
    // MARK: - 格式化
    
    /// 格式化日期为字符串
    /// - Parameter format: 日期格式（默认 "yyyy-MM-dd"）
    public func toString(format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
    
    /// 返回相对时间描述（如 "2小时前"）
    public func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// 返回简短相对时间描述（如 "2h ago"）
    public func timeAgoShort() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    // MARK: - 时间戳
    
    /// 从 Unix 时间戳（秒）创建 Date
    public init(timestamp: TimeInterval) {
        self.init(timeIntervalSince1970: timestamp)
    }
    
    /// 从 Unix 时间戳（毫秒）创建 Date
    public init(timestampMillis: TimeInterval) {
        self.init(timeIntervalSince1970: timestampMillis / 1000)
    }
    
    /// 返回 Unix 时间戳（秒）
    public var timestamp: TimeInterval {
        return timeIntervalSince1970
    }
    
    /// 返回 Unix 时间戳（毫秒）
    public var timestampMillis: TimeInterval {
        return timeIntervalSince1970 * 1000
    }
    
    // MARK: - 比较
    
    /// 是否为今天
    public var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// 是否为昨天
    public var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    /// 是否为明天
    public var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
    
    /// 是否已过去
    public var isPast: Bool {
        return self < Date()
    }
    
    /// 是否在未来
    public var isFuture: Bool {
        return self > Date()
    }
    
    /// 是否与另一个日期是同一天
    public func isSameDay(as other: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: other)
    }
    
    /// 是否与另一个日期是同一月
    public func isSameMonth(as other: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: self) == cal.component(.year, from: other)
            && cal.component(.month, from: self) == cal.component(.month, from: other)
    }
    
    /// 是否早于另一个日期
    public func isBefore(_ other: Date) -> Bool {
        return self < other
    }
    
    /// 是否晚于另一个日期
    public func isAfter(_ other: Date) -> Bool {
        return self > other
    }
    
    // MARK: - 日期组件
    
    /// 年
    public var year: Int { Calendar.current.component(.year, from: self) }
    
    /// 月（1-12）
    public var month: Int { Calendar.current.component(.month, from: self) }
    
    /// 日（1-31）
    public var day: Int { Calendar.current.component(.day, from: self) }
    
    /// 小时（0-23）
    public var hour: Int { Calendar.current.component(.hour, from: self) }
    
    /// 分钟（0-59）
    public var minute: Int { Calendar.current.component(.minute, from: self) }
    
    /// 星期几（1 = 周日，7 = 周六）
    public var weekday: Int { Calendar.current.component(.weekday, from: self) }
    
    /// 是否为周末
    public var isWeekend: Bool { Calendar.current.isDateInWeekend(self) }
    
    /// 是否为工作日
    public var isWeekday: Bool { !isWeekend }
    
    // MARK: - 日期边界
    
    /// 当天起始时间（00:00:00）
    public var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    /// 当天结束时间（23:59:59）
    public var endOfDay: Date {
        return Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) ?? self
    }
    
    /// 当月第一天
    public var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    /// 当月最后一天
    public var endOfMonth: Date {
        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? self
    }
    
    // MARK: - 日期运算
    
    /// 加/减天数
    public func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// 加/减月数
    public func adding(months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// 加/减年数
    public func adding(years: Int) -> Date {
        return Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    /// 加/减小时数
    public func adding(hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }
    
    /// 加/减分钟数
    public func adding(minutes: Int) -> Date {
        return Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }
    
    // MARK: - 日期差值
    
    /// 两个日期之间的天数差
    public func daysBetween(_ other: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: startOfDay, to: other.startOfDay)
        return abs(components.day ?? 0)
    }
    
    /// 两个日期之间的小时数差
    public func hoursBetween(_ other: Date) -> Int {
        let interval = abs(timeIntervalSince(other))
        return Int(interval / 3600)
    }
    
    /// 两个日期之间的分钟数差
    public func minutesBetween(_ other: Date) -> Int {
        let interval = abs(timeIntervalSince(other))
        return Int(interval / 60)
    }
}
