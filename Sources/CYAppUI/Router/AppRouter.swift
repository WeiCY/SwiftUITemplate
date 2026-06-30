import SwiftUI
import Observation
import CYAppCore

// MARK: - App 路由管理
//
// 增强版导航路由器，支持：
// - 每个 Tab 独立的导航栈（互不干扰）
// - Sheet 弹出管理
// - Deep Link 集成
//
// ## 基本用法
// ```swift
// // 1. 业务项目定义自己的 Route 枚举
// enum Route: Hashable {
//     case detail(id: String)
//     case settings
//     case profile(userId: Int)
// }
//
// // 2. App 入口使用
// struct RootView: View {
//     @State private var router = CYAppRouter.shared
//     @Environment(CYAppState.self) private var appState
//
//     var body: some View {
//         TabView(selection: $appState.selectedTab) {
//             ForEach(CYAppTab.allCases, id: \.self) { tab in
//                 NavigationStack(path: router.binding(for: tab)) {
//                     tab.rootView
//                         .navigationDestination(for: Route.self) { route in
//                             route.view
//                         }
//                 }
//                 .tabItem { Label(tab.title, systemImage: tab.icon) }
//                 .tag(tab)
//             }
//         }
//         .onAppear { router.bind(to: appState) }
//         .sheet(item: $router.sheetItem) { item in
//             item.content
//         }
//     }
// }
//
// // 3. 编程式导航
// CYAppRouter.shared.navigate(to: Route.detail(id: "123"))
// CYAppRouter.shared.navigate(to: Route.settings, on: .profile)  // 指定 Tab
// CYAppRouter.shared.pop()
// CYAppRouter.shared.popToRoot()
// CYAppRouter.shared.presentSheet(MySheetItem.settings)
// CYAppRouter.shared.dismissSheet()
// ```

// MARK: - Sheet 包装器

/// 通用 Sheet 包装器，支持任意 View 的 Sheet 弹出
public struct CYSheetItem: Identifiable {
    public let id = UUID()
    public let content: AnyView
    
    public init<V: View>(_ view: V) {
        self.content = AnyView(view)
    }
}

// MARK: - Router

@Observable
@MainActor
public final class CYAppRouter {
    public static let shared = CYAppRouter()
    
    /// 每个 Tab 独立的导航路径栈
    public var paths: [CYAppTab: NavigationPath]
    
    /// 当前 Sheet 弹出项
    public var sheetItem: CYSheetItem?
    
    /// 关联的 AppState（用于获取/切换当前 Tab）
    @ObservationIgnored
    private weak var appState: CYAppState?
    
    public init() {
        var p: [CYAppTab: NavigationPath] = [:]
        for tab in CYAppTab.allCases {
            p[tab] = NavigationPath()
        }
        self.paths = p
    }
    
    /// 绑定 AppState（在 App 入口的 .onAppear 中调用）
    ///
    /// ```swift
    /// .onAppear { router.bind(to: appState) }
    /// ```
    public func bind(to appState: CYAppState) {
        self.appState = appState
    }
    
    // MARK: - 获取指定 Tab 的 Binding
    
    /// 获取指定 Tab 的 NavigationPath Binding
    ///
    /// ```swift
    /// NavigationStack(path: router.binding(for: .home)) { ... }
    /// ```
    public func binding(for tab: CYAppTab) -> Binding<NavigationPath> {
        Binding(
            get: { self.paths[tab] ?? NavigationPath() },
            set: { self.paths[tab] = $0 }
        )
    }
    
    // MARK: - 导航操作
    
    /// 导航到目标页面（当前 Tab 或指定 Tab）
    ///
    /// - Parameters:
    ///   - destination: 目标路由（必须 Hashable）
    ///   - tab: 目标 Tab，nil 表示当前 Tab
    public func navigate(to destination: some Hashable, on tab: CYAppTab? = nil) {
        let targetTab = tab ?? currentTab
        paths[targetTab, default: NavigationPath()].append(destination)
        
        // 如果指定了其他 Tab，自动切换
        if let tab, tab != currentTab {
            switchTab(tab)
        }
    }
    
    /// 返回上一页
    ///
    /// - Parameter tab: 目标 Tab，nil 表示当前 Tab
    public func pop(on tab: CYAppTab? = nil) {
        let targetTab = tab ?? currentTab
        guard var path = paths[targetTab], !path.isEmpty else { return }
        path.removeLast()
        paths[targetTab] = path
    }
    
    /// 返回首页 / 清空导航栈
    ///
    /// - Parameter tab: 目标 Tab，nil 清空所有 Tab
    public func popToRoot(on tab: CYAppTab? = nil) {
        if let tab {
            paths[tab] = NavigationPath()
        } else {
            for key in paths.keys {
                paths[key] = NavigationPath()
            }
        }
    }
    
    /// 替换当前页面（移除最后一个，添加新的）
    public func replace(with destination: some Hashable, on tab: CYAppTab? = nil) {
        let targetTab = tab ?? currentTab
        var path = paths[targetTab] ?? NavigationPath()
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(destination)
        paths[targetTab] = path
    }
    
    // MARK: - Sheet 管理
    
    /// 弹出 Sheet
    ///
    /// ```swift
    /// router.presentSheet(SettingsView())
    /// ```
    public func presentSheet<V: View>(_ view: V) {
        sheetItem = CYSheetItem(view)
    }
    
    /// 关闭 Sheet
    public func dismissSheet() {
        sheetItem = nil
    }
    
    // MARK: - 查询
    
    /// 获取指定 Tab 当前导航栈深度
    public func depth(for tab: CYAppTab) -> Int {
        paths[tab]?.count ?? 0
    }
    
    // MARK: - 私有
    
    private var currentTab: CYAppTab {
        appState?.selectedTab ?? .home
    }
    
    private func switchTab(_ tab: CYAppTab) {
        appState?.selectedTab = tab
    }
}
