import XCTest

@MainActor
final class ExampleAppUITests: XCTestCase {
    func testOTPInitialPasteExternalUpdateDeletionAndHostFocus() {
        let app = launchCode(arguments: ["--otp-prefill", "--otp-paste"])
        let field = app.textFields["OTP"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "123456")
        XCTAssertEqual(app.staticTexts["otp.callbacks"].label, "Callbacks: 0")
        XCTAssertEqual(app.staticTexts["otp.focus"].label, "Focus: code")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        XCTAssertEqual(app.staticTexts["otp.value"].label, "Code: ")
        field.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        if paste.waitForExistence(timeout: 2) { paste.tap() } else { app.buttons["Paste"].tap() }
        XCTAssertEqual(field.value as? String, "123456")
        XCTAssertEqual(app.staticTexts["otp.callbacks"].label, "Callbacks: 1")
        XCTAssertEqual(app.staticTexts["otp.focus"].label, "Focus: next")
        app.typeText("next")
        XCTAssertEqual(app.textFields["Next field"].value as? String, "next")
        app.buttons["otp.keyboardDone"].tap()
        app.buttons["otp.external"].tap()
        XCTAssertEqual(field.value as? String, "987654")
        XCTAssertEqual(app.staticTexts["otp.callbacks"].label, "Callbacks: 1")
        app.buttons["otp.clear"].tap()
        app.buttons["otp.focusCode"].tap()
        field.typeText("12345" + XCUIKeyboardKey.delete.rawValue + "56")
        XCTAssertEqual(field.value as? String, "123456")
        XCTAssertEqual(app.staticTexts["otp.callbacks"].label, "Callbacks: 2")
        app.buttons["otp.keyboardDone"].tap()
        app.switches["otp.disabled"].switches.firstMatch.tap()
        XCTAssertFalse(field.isEnabled)
    }

    func testOTPAtNarrowWidthLargestTypeAndLongLength() {
        let app = launchCode(arguments: ["--otp-layout", "--otp-long"])
        let field = app.textFields["OTP"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "123456781234567812345678")
        XCTAssertGreaterThan(field.frame.height, 40)
        XCTAssertGreaterThanOrEqual(field.frame.minX, 0)
        XCTAssertLessThanOrEqual(field.frame.maxX, app.frame.maxX)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "OTP - 240pt width accessibility5 24 digits"
        shot.lifetime = .keepAlways
        add(shot)
        // A normal tap can place the caret at the beginning; select the complete numeric word before replacing it.
        field.doubleTap()
        field.typeText("123456781234567812345679")
        XCTAssertEqual(field.value as? String, "123456781234567812345679")
        XCTAssertEqual(app.staticTexts["otp.callbacks"].label, "Callbacks: 1")
    }

    private func launchCode(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["bookmark.1"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.buttons["验证码 / Verification code"].tap()
        return app
    }

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
        let submit = app.buttons["form.submit"]
        XCTAssertTrue(submit.isHittable)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let gap = keyboard.frame.minY - submit.frame.maxY
        XCTAssertGreaterThanOrEqual(gap, -2)
        XCTAssertLessThan(gap, 100, "No second keyboard-height-sized blank region")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Form bottom action with keyboard"
        shot.lifetime = .keepAlways
        add(shot)
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
