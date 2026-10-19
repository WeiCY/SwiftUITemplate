import SwiftUI
import SwiftData
import CYAppCore
import CYAppNetwork
import CYAppImage
import CYFeedbackStyle
import CYAppDesignSystem
import CYAppUI
import CYAppPersistence

// MARK: - 可运行示例 App
//
// 这是一个“小但真实”的 App：网络请求 → loading/error/retry → 数据列表 →
// 路由跳转 → 收藏落库 → 设置主题/语言。
// 新建项目时按 Features/Models/Services/App 的目录结构复制即可。

@MainActor
@main
struct DemoApp: App {
    @State private var persistence = ExamplePersistence()

    init() {
        AppBootstrap.start(with: .default)
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            var shouldFail = ProcessInfo.processInfo.arguments.contains("--fail-store-once")
            _persistence = State(initialValue: ExamplePersistence {
                if shouldFail {
                    shouldFail = false
                    throw NSError(domain: "ExampleInjectedFailure", code: 1)
                }
                return try CYPersistenceController.create(for: [BookmarkItem.self, BookmarkTag.self], inMemory: true)
            })
        }
    }

    @State private var appState = CYAppState()
    @State private var router = CYAppRouter(
        tabs: AppTab.allCases.map(\.id),
        selectedTab: AppTab.home.id
    )

    var body: some Scene {
        WindowGroup {
            Group {
                if let controller = persistence.controller, let dependencies = persistence.dependencies {
                    RootView(dependencies: dependencies)
                        .modelContainer(controller.container)
                } else if let error = persistence.error {
                    ContentUnavailableView {
                        Label("无法打开本地数据 / Storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("重试 / Retry") { openStore() }
                            .accessibilityIdentifier("storage.retry")
                    }
                } else { ProgressView() }
            }
            .task { openStore() }
            .environment(appState)
            .environment(router)
            .preferredColorScheme(appState.theme.colorScheme)
            .environment(\.locale, Locale(identifier: appState.language))
            .id(appState.language)
        }

    }
    private func openStore() {
        persistence.open(networkClient: CYFactoryContainer.shared.networkClient)
    }
}

struct RootView: View {
    let dependencies: AppDependencies

    @Environment(CYAppState.self) private var appState
    @Environment(CYAppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { router.selectTab($0) }
        )) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.binding(for: tab.id)) {
                    tabRoot(tab)
                        .navigationDestination(for: AppRoute.self) { route in
                            routeView(route)
                        }
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab.id)
            }
        }
        .sheet(item: $router.sheetItem) { $0.content }
        .onOpenURL { url in
            guard url.scheme == "cyexample", url.host == "article",
                  let id = Int(url.lastPathComponent), let article = Article.samples.first(where: { $0.id == id }) else { return }
            router.navigate(to: AppRoute.articleDetail(article), on: AppTab.home.id)
        }
        .feedbackOverlay(toastManager: dependencies.toast, loadingManager: dependencies.loading)
        .alertManager(manager: dependencies.alert)
        .overlay {
            if dependencies.loading.isLoading {
                Button("关闭加载 / Stop loading") { dependencies.loading.hideAll() }
                    .padding().background(.regularMaterial)
            }
        }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(viewModel: dependencies.homeViewModel)
        case .bookmarks: BookmarkView(viewModel: dependencies.bookmarkViewModel)
        case .settings: SettingsView(toast: dependencies.toast)
        case .components: ComponentCatalog(dependencies: dependencies)
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .articleDetail(let article): ArticleDetailView(article: article)
        }
    }
}
