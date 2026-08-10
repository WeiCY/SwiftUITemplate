import Foundation
import Observation
import CYAppCore

// MARK: - 全局应用状态

/// 全局应用状态容器 — Single Source of Truth
///
/// 存放跨页面共享的全局状态，通过 `@Environment` 注入 View 树。
/// 与 `CYBaseViewModel` 分工明确：
/// - **CYAppState**：App 生命周期内的全局状态（用户、Tab、主题、语言、引导页）
/// - **CYBaseViewModel**：单页面生命周期内的局部状态（列表数据、loading、error）
///
/// ## 主题系统
///
/// `theme` 属性赋值时自动持久化到 UserDefaults，无需手动调用 `CYThemeManager.save()`。
/// ```swift
/// appState.theme = .dark        // 自动保存
/// appState.theme.colorScheme    // 转 SwiftUI ColorScheme
/// CYThemeManager.saveAndApply(.dark)  // 如需立即应用到 UIKit 层
/// ```
///
/// ## 多语言系统
///
/// `language` 为计算属性，实际状态由 `CYLocalizationManager` 管理。
/// 切换语言后 SwiftUI 视图需配合 `.id(appState.language)` 刷新。
/// ```swift
/// appState.setLanguage("zh-Hans")
/// "welcome_title".localized     // 读取当前语言的翻译
/// ```
///
/// ## App 入口集成
/// ```swift
/// @main
/// struct MyApp: App {
///     @State private var appState = CYAppState()
///     var body: some Scene {
///         WindowGroup {
///             RootView()
///                 .environment(appState)
///                 .preferredColorScheme(appState.theme.colorScheme)
///                 .id(appState.language)  // 语言切换时重建视图
///         }
///     }
/// }
/// ```
@MainActor
@Observable
public final class CYAppState {
    
    // MARK: - 注入的依赖
    
    private let themeManager: CYThemeManaging
    private let localizationManager: CYLocalizationManaging
    
    // MARK: - 用户
    
    /// 当前登录用户（nil = 未登录）
    public var user: User?
    
    /// 是否已登录
    public var isLoggedIn: Bool { user != nil }
    
    // MARK: - 导航
    
    /// 当前选中的 Tab
    public var selectedTab: CYAppTab = .home
    
    // MARK: - 外观（主题）
    
    /// 主题偏好（赋值时自动持久化到 UserDefaults）
    ///
    /// 通过 `CYThemeManager.savedTheme()` 在 init 时自动恢复。
    /// 如需立即应用到 UIKit 层，请调用 `CYThemeManager.saveAndApply(appState.theme)`。
    public var theme: CYAppTheme {
        didSet { themeManager.save(theme) }
    }
    
    // MARK: - 多语言
    
    /// 当前语言代码（只读，实际状态由 CYLocalizationManager 管理）
    public var language: String {
        localizationManager.currentLanguage
    }
    
    /// 切换 App 语言
    public func setLanguage(_ languageCode: String) {
        localizationManager.setLanguage(languageCode)
    }
    
    // MARK: - 引导页
    
    /// 是否已完成新手引导（自动同步 UserDefaults）
    public var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: CYAppConstants.keyOnboardingShown) }
    }
    
    // MARK: - 初始化
    
    /// 创建全局状态实例
    ///
    /// - Parameters:
    ///   - themeManager: 主题管理器，默认 `CYThemeManager.shared`
    ///   - localizationManager: 多语言管理器，默认 `CYLocalizationManager.shared`
    public init(
        themeManager: CYThemeManaging = CYThemeManager.shared,
        localizationManager: CYLocalizationManaging = CYLocalizationManager.shared
    ) {
        self.themeManager = themeManager
        self.localizationManager = localizationManager
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: CYAppConstants.keyOnboardingShown)
        self.theme = themeManager.savedTheme()
        localizationManager.restore()
    }
    
    // MARK: - 用户 Management
    
    /// 设置用户信息（登录成功后调用）
    public func setUser(_ user: User) {
        self.user = user
    }
    
    /// 退出登录 — 清除用户数据并重置导航
    public func logout() {
        self.user = nil
        self.selectedTab = .home
    }
    
    /// 完全重置（换账号场景）
    public func reset() {
        self.user = nil
        self.selectedTab = .home
        self.theme = .system
        localizationManager.resetToSystem()
    }
}
