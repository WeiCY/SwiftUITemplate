import SwiftUI
import CYAppCore
import CYAppNetwork
import CYAppImage
import CYFeedbackStyle
import CYAppDesignSystem
import CYAppUI

// MARK: - 可运行 Demo

@MainActor
@main
struct DemoApp: App {
    init() {
        AppBootstrap.start(with: .default)
        CYToastManager.shared.queueMode = .replace
    }

    @State private var appState = CYAppState()
    @State private var router = CYAppRouter(
        tabs: AppTab.allCases.map(\.id),
        selectedTab: AppTab.home.id
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
                .id(appState.language)
        }
    }
}

struct RootView: View {
    @Environment(CYAppState.self) private var appState
    @Environment(CYAppRouter.self) private var router
    @State private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.binding(for: tab.id)) {
                    tabRoot(tab)
                        .navigationDestination(for: String.self) { route in
                            CYBaseView {
                                Text("Route: \(route)")
                                    .font(CYAppFont.bodyMedium)
                            }
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
        case .home: HomeDemoView()
        case .explore: ExploreDemoView()
        case .profile: ProfileDemoView()
        }
    }
}

struct HomeDemoView: View {
    @Environment(CYAppState.self) private var appState
    @Environment(CYAppRouter.self) private var router

    var body: some View {
        CYBaseView {
            VStack(spacing: 20) {
                Text("CYAppTemplate Demo")
                    .font(CYAppFont.h1)

                PrimaryButton(title: "触发 Toast") {
                    CYToastManager.shared.show("Hello Toast", type: .success)
                }

                PrimaryButton(title: "连续 Toast") {
                    CYToastManager.shared.show("第一条消息", type: .info, duration: 1)
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        CYToastManager.shared.show("最新消息已替换", type: .success)
                    }
                }

                PrimaryButton(title: "显示 Loading") {
                    CYLoadingManager.shared.show("加载中…")
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        CYLoadingManager.shared.hide()
                    }
                }

                PrimaryButton(title: "跳转详情") {
                    router.navigate(to: "detail")
                }

                PrimaryButton(title: "切换语言") {
                    let next = appState.language == "zh-Hans" ? "en" : "zh-Hans"
                    CYLocalizationManager.shared.setLanguage(next)
                }
            }
            .padding()
        }
    }
}

struct ExploreDemoView: View {
    var body: some View {
        CYBaseView {
            Text("Explore Tab")
                .font(CYAppFont.bodyMedium)
        }
    }
}

struct ProfileDemoView: View {
    var body: some View {
        CYBaseView {
            Text("Profile Tab")
                .font(CYAppFont.bodyMedium)
        }
    }
}
