import SwiftUI
import SwiftData
import CYAppCore
import CYAppNetwork
import CYAppImage
import CYFeedbackStyle
import CYAppDesignSystem
import CYAppUI

// MARK: - 可运行示例 App
//
// 这是一个“小但真实”的 App：网络请求 → loading/error/retry → 数据列表 →
// 路由跳转 → 收藏落库 → 设置主题/语言。
// 新建项目时按 Features/Models/Services/App 的目录结构复制即可。

@MainActor
@main
struct DemoApp: App {
    private let persistence = ExamplePersistence.controller
    private let dependencies: AppDependencies

    init() {
        AppBootstrap.start(with: .default)
        CYToastManager.shared.queueMode = .replace

        dependencies = AppDependencies(
            networkClient: CYFactoryContainer.shared.networkClient,
            modelContext: ExamplePersistence.controller.container.mainContext
        )
    }

    @State private var appState = CYAppState()
    @State private var router = CYAppRouter(
        tabs: AppTab.allCases.map(\.id),
        selectedTab: AppTab.home.id
    )

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(appState)
                .environment(router)
                .preferredColorScheme(appState.theme.colorScheme)
                .id(appState.language)
        }
        .modelContainer(persistence.container)
    }
}

struct RootView: View {
    let dependencies: AppDependencies

    @Environment(CYAppState.self) private var appState
    @Environment(CYAppRouter.self) private var router
    @State private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.binding(for: tab.id)) {
                    tabRoot(tab)
                        .navigationDestination(for: AppRoute.self) { route in
                            routeView(route)
                        }
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab)
            }
        }
        .onAppear { router.selectTab(selectedTab.id) }
        .onChange(of: selectedTab) { _, tab in router.selectTab(tab.id) }
        .feedbackOverlay()
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(viewModel: dependencies.homeViewModel)
        case .bookmarks: BookmarkView(viewModel: dependencies.bookmarkViewModel)
        case .settings: SettingsView()
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .articleDetail(let article): ArticleDetailView(article: article)
        }
    }
}
