import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 主题管理工具
//
// 提供主题偏好的持久化存储和 UIKit 全局应用能力。
// 通常不需要直接调用，CYAppState 已自动集成：
// - 启动时：CYAppState.init() 自动调用 savedTheme() 恢复
// - 切换时：appState.theme = .dark 自动触发 didSet 保存
// - 应用时：需在 App 入口手动调用 saveAndApply()
//
// ## 完整集成示例
// ```swift
// @main
// struct MyApp: App {
//     @State private var appState = CYAppState()
//
//     var body: some Scene {
//         WindowGroup {
//             RootView()
//                 .environment(appState)
//                 .preferredColorScheme(appState.theme.colorScheme)  // SwiftUI
//                 .onAppear {
//                     CYThemeManager.saveAndApply(appState.theme)     // UIKit 层
//                 }
//         }
//     }
// }
// ```
//
// ## 设置页面示例
// ```swift
// struct ThemeSettingsView: View {
//     @Environment(CYAppState.self) private var appState
//
//     var body: some View {
//         @Bindable var state = appState
//         Picker("主题", selection: $state.theme) {
//             ForEach(CYAppTheme.allCases, id: \.self) { theme in
//                 Text(theme.displayName).tag(theme)
//             }
//         }
//         .onChange(of: appState.theme) { _, new in
//             CYThemeManager.saveAndApply(new)
//         }
//     }
// }
// ```

public struct CYThemeManager {
    
    private init() {}
    
    // MARK: - 持久化
    
    /// 从 UserDefaults 恢复上次保存的主题偏好
    ///
    /// 如果没有保存过，返回 `.system`（跟随系统）
    public static func savedTheme() -> CYAppTheme {
        let raw = UserDefaults.standard.string(forKey: CYAppConstants.keyThemePreference)
        return CYAppTheme(rawValue: raw ?? "") ?? .system
    }
    
    /// 将主题偏好持久化到 UserDefaults
    public static func save(_ theme: CYAppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: CYAppConstants.keyThemePreference)
    }
    
    // MARK: - 全局应用
    
    #if canImport(UIKit)
    /// 将主题应用到所有已连接的 UIWindowScene
    ///
    /// - `.system` → `.unspecified`（跟随系统）
    /// - `.light`  → `.light`
    /// - `.dark`   → `.dark`
    public static func apply(_ theme: CYAppTheme) {
        let style: UIUserInterfaceStyle
        switch theme {
        case .system: style = .unspecified
        case .light:  style = .light
        case .dark:   style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
    #endif
    
    // MARK: - 便捷
    
    /// 保存并立即应用主题（一步到位）
    public static func saveAndApply(_ theme: CYAppTheme) {
        save(theme)
        #if canImport(UIKit)
        apply(theme)
        #endif
    }
}
