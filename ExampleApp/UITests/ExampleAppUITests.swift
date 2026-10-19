import XCTest

@MainActor
final class ExampleAppUITests: XCTestCase {
    func testSnackBarReplacementAndLocalTagWithLargeLongContent() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["bookmark.1"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.switches["catalog.large"].switches.firstMatch.tap()
        app.switches["catalog.long"].switches.firstMatch.tap()
        let tag = app.buttons["tag.localColor"]
        for _ in 0..<20 {
            if tag.exists && tag.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(tag.exists && tag.isHittable)
        let tagShot = XCTAttachment(screenshot: app.screenshot())
        tagShot.name = "Local tag - accessibility2 long content"
        tagShot.lifetime = .keepAlways
        add(tagShot)
        let replace = app.buttons["snackbar.replace"]
        for _ in 0..<15 {
            if replace.exists && replace.isHittable { break }
            app.swipeUp()
        }
        replace.tap()
        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Replacement survives:")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 3))
        let snackShot = XCTAttachment(screenshot: app.screenshot())
        snackShot.name = "Snackbar replacement - accessibility2 long content"
        snackShot.lifetime = .keepAlways
        add(snackShot)
        app.buttons["Dismiss"].tap()
        XCTAssertTrue(message.waitForNonExistence(timeout: 3))
    }

    func testListBookmarkSettingsAndFeedback() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-testing"]
        app.launch()
        let bookmark = app.buttons["bookmark.1"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
        app.buttons["article.1"].tap()
        XCTAssertTrue(app.staticTexts["Article #1"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        bookmark.tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["Swift 6 并发：从 @unchecked 到 Sendable"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        app.segmentedControls.buttons.element(boundBy: 2).tap()
        app.tabBars.buttons.element(boundBy: 3).tap()
        let alert = app.buttons["feedback.alert"]
        for _ in 0..<12 {
            if alert.exists && alert.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(alert.exists && alert.isHittable)
        alert.tap()
        XCTAssertTrue(app.alerts["Example Alert"].waitForExistence(timeout: 5))
    }

    func testCustomFeedbackManagersDriveVisibleUI() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--custom-feedback"]
        app.launch()
        XCTAssertTrue(app.buttons["bookmark.1"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let toast = app.buttons["feedback.toast"]
        for _ in 0..<12 {
            if toast.exists && toast.isHittable { break }
            app.swipeUp()
        }
        toast.tap()
        XCTAssertTrue(app.staticTexts["Catalog Toast"].waitForExistence(timeout: 3))
        app.buttons["feedback.loading"].tap()
        let stop = app.buttons["关闭加载 / Stop loading"]
        XCTAssertTrue(stop.waitForExistence(timeout: 3))
        stop.tap()
        app.buttons["feedback.alert"].tap()
        XCTAssertTrue(app.alerts["Example Alert"].waitForExistence(timeout: 3))
    }

    func testInitialPaginationFailureAndRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["bookmark.1"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.buttons["搜索与分页 / Search & pagination"].tap()
        let failure = app.switches["paging.failFirst"]
        failure.switches.firstMatch.tap()
        XCTAssertEqual(failure.value as? String, "1")
        app.buttons["paging.restart"].tap()
        let retry = app.buttons["pagination.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        failure.switches.firstMatch.tap()
        retry.tap()
        XCTAssertTrue(app.staticTexts["Result #0"].waitForExistence(timeout: 5))
    }

    func testFormKeyboardSubmissionMovesFocus() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["bookmark.1"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.buttons["表单 / Form"].tap()
        let email = app.textFields["name@example.com"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("fake@example.test\n")
        app.typeText("password-example\npassword-example\n")
        XCTAssertTrue(app.staticTexts["提交成功 / Submitted"].waitForExistence(timeout: 5))
    }

    func testStorageFailureCanRecover() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fail-store-once"]
        app.launch()
        let retry = app.buttons["storage.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        retry.tap()
        XCTAssertTrue(app.buttons["bookmark.1"].waitForExistence(timeout: 10))
    }
}
