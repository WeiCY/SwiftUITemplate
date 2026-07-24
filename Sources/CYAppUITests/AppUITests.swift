import XCTest
import SwiftUI
@testable import CYAppUI
import CYAppCore

// MARK: - UI 层补充测试
//
// 覆盖 AppRouter 导航栈核心逻辑与全局反馈样式配置。

final class AppUITests: XCTestCase {

    @MainActor
    func testRouterNavigateAndPop() {
        let appState = CYAppState()
        let router = CYAppRouter(appState: appState)
        router.navigate(to: "detail")
        XCTAssertEqual(router.paths[.home]?.count, 1)

        router.pop()
        XCTAssertEqual(router.paths[.home]?.count, 0)
    }

    @MainActor
    func testRouterPopToRoot() {
        let appState = CYAppState()
        let router = CYAppRouter(appState: appState)
        router.navigate(to: "a")
        router.navigate(to: "b")
        router.navigate(to: "c")
        XCTAssertEqual(router.paths[.home]?.count, 3)

        router.popToRoot()
        XCTAssertEqual(router.paths[.home]?.count, 0)
    }

    @MainActor
    func testRouterNavigateSwitchesTab() {
        let appState = CYAppState()
        let router = CYAppRouter(appState: appState)
        router.navigate(to: "settings", on: .profile)
        XCTAssertEqual(appState.selectedTab, .profile)
        XCTAssertEqual(router.paths[.profile]?.count, 1)
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
}
