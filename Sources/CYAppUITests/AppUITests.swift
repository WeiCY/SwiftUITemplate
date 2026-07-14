import XCTest
@testable import CYAppUI
import CYAppCore

// MARK: - UI 层补充测试
//
// 覆盖 AppRouter 导航栈核心逻辑：push/pop/popToRoot、切 Tab 联动 appState。

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
}
