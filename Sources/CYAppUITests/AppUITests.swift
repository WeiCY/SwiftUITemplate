import XCTest
import SwiftUI
@testable import CYAppUI
import CYAppCore
import CYFeedbackStyle

// MARK: - UI 层补充测试
//
// 覆盖 AppRouter 导航栈核心逻辑与全局反馈样式配置。
// AppState 相关测试统一注入内存版管理器（见 TestSupport.swift），
// 不依赖 UserDefaults 持久化状态，保证跨用例、跨运行可复现。

final class AppUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppStateTestSupport.resetPersistedPreferences()
    }

    override func tearDown() {
        AppStateTestSupport.resetPersistedPreferences()
        super.tearDown()
    }

    /// 构造使用内存版管理器的 AppState，隔离 UserDefaults 持久化
    @MainActor
    private func makeAppState() -> CYAppState {
        CYAppState(
            themeManager: MockThemeManager(),
            localizationManager: MockLocalizationManager()
        )
    }

    @MainActor
    func testRouterNavigateAndPop() {
        let home: CYTabID = "home"
        let router = CYAppRouter(tabs: [home], selectedTab: home)
        router.navigate(to: "detail")
        XCTAssertEqual(router.paths[home]?.count, 1)

        router.pop()
        XCTAssertEqual(router.paths[home]?.count, 0)
    }

    @MainActor
    func testRouterPopToRoot() {
        let home: CYTabID = "home"
        let router = CYAppRouter(tabs: [home], selectedTab: home)
        router.navigate(to: "a")
        router.navigate(to: "b")
        router.navigate(to: "c")
        XCTAssertEqual(router.paths[home]?.count, 3)

        router.popToRoot()
        XCTAssertEqual(router.paths[home]?.count, 0)
    }

    @MainActor
    func testRouterNavigateSwitchesTab() {
        let home: CYTabID = "home"
        let profile: CYTabID = "profile"
        let router = CYAppRouter(tabs: [home, profile], selectedTab: home)
        router.navigate(to: "settings", on: profile)
        XCTAssertEqual(router.selectedTab, profile)
        XCTAssertEqual(router.paths[profile]?.count, 1)
    }

    @MainActor
    func testRouterReplaceCurrentPage() {
        let home: CYTabID = "home"
        let router = CYAppRouter(tabs: [home], selectedTab: home)
        router.navigate(to: "a")
        router.replace(with: "b")
        XCTAssertEqual(router.depth(for: home), 1)
        XCTAssertEqual(router.paths[home]?.count, 1)
    }

    @MainActor
    func testRouterPopOnEmptyStackIsNoOp() {
        let home: CYTabID = "home"
        let router = CYAppRouter(tabs: [home], selectedTab: home)
        router.pop()
        XCTAssertEqual(router.depth(for: home), 0)
    }

    @MainActor
    func testRouterPopToRootClearsAllTabs() {
        let home: CYTabID = "home"
        let profile: CYTabID = "profile"
        let router = CYAppRouter(tabs: [home, profile], selectedTab: home)
        router.navigate(to: "a")
        router.navigate(to: "b", on: profile)
        router.popToRoot()
        XCTAssertEqual(router.depth(for: home), 0)
        XCTAssertEqual(router.depth(for: profile), 0)
    }

    @MainActor
    func testRouterSelectTabCreatesPathIfMissing() {
        let home: CYTabID = "home"
        let router = CYAppRouter(tabs: [home], selectedTab: home)
        let newTab: CYTabID = "newTab"
        router.selectTab(newTab)
        XCTAssertEqual(router.selectedTab, newTab)
        XCTAssertEqual(router.depth(for: newTab), 0)
    }

    @MainActor
    func testRouterPresentAndDismissSheet() {
        let home: CYTabID = "home"
        let router = CYAppRouter(tabs: [home], selectedTab: home)
        XCTAssertNil(router.sheetItem)
        router.presentSheet(Text("sheet"))
        XCTAssertNotNil(router.sheetItem)
        router.dismissSheet()
        XCTAssertNil(router.sheetItem)
    }

    @MainActor
    func testFeedbackConfigurationDefaultsAndCustomStyles() {
        let configuration = CYFeedbackConfiguration()
        XCTAssertEqual(configuration.toastStyle.position, .center)
        XCTAssertEqual(configuration.toastStyle.horizontalMargin, 16)
        XCTAssertEqual(configuration.toastStyle.verticalOffset, 0)
        XCTAssertEqual(configuration.toastStyle.cornerRadius, 8)
        XCTAssertTrue(configuration.toastStyle.tapToDismiss)
        XCTAssertEqual(configuration.toastStyle.maxLines, 2)
        XCTAssertEqual(configuration.loadingStyle.maskOpacity, 0.2)
        XCTAssertEqual(configuration.loadingStyle.cornerRadius, 16)
        XCTAssertEqual(configuration.loadingStyle.indicatorScale, 1.2)
        XCTAssertEqual(configuration.loadingStyle.pulseScaleRange, 0.9...1.15)

        let toastStyle = CYToastStyle(
            position: .bottom,
            horizontalMargin: 24,
            verticalOffset: 32,
            cornerRadius: 20
        )
        let loadingStyle = CYLoadingStyle(
            maskOpacity: 0.4,
            cornerRadius: 24,
            indicatorScale: 1.5
        )
        CYFeedbackConfiguration.configure(
            toastStyle: toastStyle,
            loadingStyle: loadingStyle
        )
        defer {
            CYFeedbackConfiguration.configure(
                toastStyle: .default,
                loadingStyle: .default
            )
        }

        XCTAssertEqual(CYFeedbackConfiguration.shared.toastStyle.position, .bottom)
        XCTAssertEqual(CYFeedbackConfiguration.shared.toastStyle.horizontalMargin, 24)
        XCTAssertEqual(CYFeedbackConfiguration.shared.toastStyle.verticalOffset, 32)
        XCTAssertEqual(CYFeedbackConfiguration.shared.toastStyle.cornerRadius, 20)
        XCTAssertEqual(CYFeedbackConfiguration.shared.loadingStyle.maskOpacity, 0.4)
        XCTAssertEqual(CYFeedbackConfiguration.shared.loadingStyle.cornerRadius, 24)
        XCTAssertEqual(CYFeedbackConfiguration.shared.loadingStyle.indicatorScale, 1.5)
    }
    
    // MARK: - CYAppState Tests
    
    @MainActor
    func testAppStateInitialState() {
        let state = makeAppState()
        XCTAssertTrue(state.theme == .system)
    }

    @MainActor
    func testAppStateResetAllClearsPreferences() {
        let state = makeAppState()
        state.theme = .dark
        state.resetAll()
        XCTAssertTrue(state.theme == .system)
    }
}
