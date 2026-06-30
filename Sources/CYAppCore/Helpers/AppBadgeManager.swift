#if canImport(UIKit)
import UIKit
import UserNotifications

// MARK: - App 角标管理
//
// 管理 App 图标上的红点数字（角标），使用 UNUserNotificationCenter API（iOS 16+）。
// 内部维护缓存避免依赖已废弃的 UIApplication.applicationIconBadgeNumber。
//
// 用法：
// ```swift
// CYAppBadgeManager.set(5)           // 设置角标为 5
// CYAppBadgeManager.increment()      // 角标 +1
// CYAppBadgeManager.clear()          // 清除角标
// CYAppBadgeManager.current          // 获取当前角标数
// ```

public final class CYAppBadgeManager {
    
    private init() {}
    
    /// 内部缓存当前角标数量
    private static var cachedCount: Int = 0
    
    /// 获取当前角标数量
    public static var current: Int {
        return cachedCount
    }
    
    /// 设置角标数量
    public static func set(_ count: Int) {
        let safeCount = max(0, count)
        cachedCount = safeCount
        UNUserNotificationCenter.current().setBadgeCount(safeCount)
    }
    
    /// 角标 +1
    public static func increment() {
        set(cachedCount + 1)
    }
    
    /// 角标 -1
    public static func decrement() {
        set(max(0, cachedCount - 1))
    }
    
    /// 清除角标（设为 0）
    public static func clear() {
        set(0)
    }
}
#endif
