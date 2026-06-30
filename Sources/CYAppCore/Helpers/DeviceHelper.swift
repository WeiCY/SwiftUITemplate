#if canImport(UIKit)
import UIKit

// MARK: - 设备信息辅助工具
//
// 提供设备类型、App 版本、触觉反馈等常用设备信息查询。
//
// 用法：
// ```swift
// CYDeviceHelper.isPad           // 是否为 iPad
// CYDeviceHelper.appVersion      // "1.0.0"
// CYDeviceHelper.buildNumber     // "42"
// CYDeviceHelper.vibrate()       // 触发触觉反馈
// ```

public struct CYDeviceHelper {
    
    /// 是否为 iPad
    public static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// App 版本号（如 "1.0.0"）
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// Build 号（如 "42"）
    public static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// 触发触觉反馈震动
    public static func vibrate(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
#endif
