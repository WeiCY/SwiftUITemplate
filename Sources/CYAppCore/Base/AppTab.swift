import Foundation

// MARK: - 底部标签枚举
//
// 定义 App 底部 TabBar 的标签项。业务项目可根据实际需求扩展或替换。
//
// 用法：
// ```swift
// // TabBar 构建
// TabView(selection: $appState.selectedTab) {
//     ForEach(CYAppTab.allCases, id: \.self) { tab in
//         tab.rootView
//             .tabItem { Label(tab.title, systemImage: tab.icon) }
//             .tag(tab)
//     }
// }
//
// // 编程式切换
// appState.selectedTab = .profile
// ```

/// 底部 Tab 枚举
///
/// | Case     | 图标       | 标题     |
/// |----------|-----------|---------|
/// | home     | house     | 首页     |
/// | explore  | safari    | 发现     |
/// | profile  | person    | 我的     |
public enum CYAppTab: String, CaseIterable, Sendable {
    case home
    case explore
    case profile
    
    /// Tab 图标（SF Symbol 名称）
    public var icon: String {
        switch self {
        case .home: return "house"
        case .explore: return "safari"
        case .profile: return "person"
        }
    }
    
    /// Tab 标题（本地化场景请使用 "tab_home".localized 等替代）
    public var title: String {
        switch self {
        case .home: return "Home"
        case .explore: return "Explore"
        case .profile: return "Profile"
        }
    }
}
