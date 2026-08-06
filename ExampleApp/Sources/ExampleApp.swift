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
        CYAppConfiguration.configure(
            environment: .development,
            baseURL: "https://dev-api.example.com",
            defaultHeaders: ["X-App-Platform": "iOS"],
            timeoutInterval: 30
        )

        CYAppImageConfig.configure()

        CYFeedbackConfiguration.configure(
            toastStyle: CYToastStyle(position: .center),
            loadingStyle: .default
        )
        CYToastManager.shared.queueMode = .replace
    }

    @State private var appState = CYAppState()
    @State private var router = CYAppRouter.shared

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

    var body: some View {
        @Bindable var appState = self.appState
        TabView(selection: $appState.selectedTab) {
            ForEach(CYAppTab.allCases, id: \.self) { tab in
                NavigationStack(path: router.binding(for: tab)) {
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
        .onAppear { router.bind(to: appState) }
        .feedbackOverlay()
    }

    @ViewBuilder
    private func tabRoot(_ tab: CYAppTab) -> some View {
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
