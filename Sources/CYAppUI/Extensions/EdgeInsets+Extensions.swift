import SwiftUI

// MARK: - EdgeInsets 扩展
//
// 提供 EdgeInsets 的快捷构造和工厂方法。
//
// 用法：
// ```swift
// EdgeInsets(uniform: 16)           // 四边相同
// EdgeInsets(horizontal: 16, vertical: 8) // 水平/垂直
// .top(16)                          // 仅顶部
// .horizontal(16)                   // 左右各 16
// ```

extension EdgeInsets {
    
    /// 四边相同间距
    /// 用法: EdgeInsets(uniform: 16)
    public init(uniform: CGFloat) {
        self.init(top: uniform, leading: uniform, bottom: uniform, trailing: uniform)
    }
    
    /// 水平 + 垂直间距
    /// 用法: EdgeInsets(horizontal: 16, vertical: 8)
    public init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
    
    /// 零间距
    public static let zero = EdgeInsets(uniform: 0)
    
    /// 仅顶部间距
    public static func top(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(top: value, leading: 0, bottom: 0, trailing: 0)
    }
    
    /// 仅底部间距
    public static func bottom(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(top: 0, leading: 0, bottom: value, trailing: 0)
    }
    
    /// 仅左侧间距
    public static func leading(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(top: 0, leading: value, bottom: 0, trailing: 0)
    }
    
    /// 仅右侧间距
    public static func trailing(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: value)
    }
    
    /// 水平间距（左右相同）
    public static func horizontal(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(horizontal: value)
    }
    
    /// 垂直间距（上下相同）
    public static func vertical(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(vertical: value)
    }
}
