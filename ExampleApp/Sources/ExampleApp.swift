import SwiftUI
import CYAppCore
import CYAppDesignSystem
import CYAppUI

// MARK: - 可运行 Demo
//
// 业务方接入口参考：演示三层封装的装配方式（AppState / AppRouter / BaseView /
// PrimaryButton / Toast + Loading 全局挂载 / 本地化切换）。
// 仅使用跨平台（iOS / macOS）安全的组件；MediaPicker、RemoteImageView、
// OnboardingView 等 UIKit 专属组件请直接在 iOS Target 中引用。

@MainActor
@main
struct DemoApp: App {
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
        .toastView()
        .loadingOverlay()
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

                PrimaryButton(title: "显示 Loading") {
                    CYLoadingManager.shared.show("加载中…")
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        CYLoadingManager.shared.hide()
                    }
                }

                PrimaryButton(title: "跳转详情") {
                    router.navigate(to: "detail")
                }

                PrimaryButton(title: "切换语言") {
                    let next = appState.language == "zh-Hans" ? "en" : "zh-Hans"
                    CYLocalizationManager.setLanguage(next)
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
