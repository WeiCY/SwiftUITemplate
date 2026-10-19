import XCTest

@MainActor
final class ConsumerUITests: XCTestCase {
    func testLocalEditingUsesDraftAndExplicitSave() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Offline"].tap()
        app.buttons["offline.add"].tap()
        app.buttons["Original"].tap()
        let draft = app.textFields["offline.draft"]
        XCTAssertTrue(draft.waitForExistence(timeout: 3))
        draft.tap()
        draft.typeText(" cancelled")
        app.buttons["offline.cancel"].tap()
        XCTAssertTrue(app.buttons["Original"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Original cancelled"].exists)
        app.buttons["Original"].tap()
        draft.tap()
        draft.typeText(" saved")
        app.buttons["offline.save"].tap()
        XCTAssertTrue(app.buttons["Original saved"].waitForExistence(timeout: 3))
    }

    func testExternalPagingRetryAndIndependentFeedback() {
        let app = XCUIApplication()
        app.launch()
        let retry = app.buttons["pagination.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        app.switches["consumer.first"].switches.firstMatch.tap()
        retry.tap()
        XCTAssertTrue(app.staticTexts["Consumer row 0"].waitForExistence(timeout: 5))
        app.buttons["Refresh host state"].tap()
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        app.switches["consumer.append"].switches.firstMatch.tap()
        retry.tap()
        let count = app.staticTexts["consumer.count"]
        let recovered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@ OR label == %@", "Loaded: 40", "Loaded: 60"), object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [recovered], timeout: 5), .completed)
        app.tabBars.buttons["Custom A"].tap()
        app.buttons["Host toast"].tap()
        XCTAssertTrue(app.staticTexts["Independent toast"].waitForExistence(timeout: 3))
        app.buttons["Host route"].tap()
        XCTAssertTrue(app.staticTexts["Independent route"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Host loading"].tap()
        XCTAssertTrue(app.staticTexts["Independent loading"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Custom B"].tap()
        XCTAssertFalse(app.staticTexts["Independent toast"].exists)
        XCTAssertFalse(app.staticTexts["Independent loading"].exists)
        app.buttons["Host alert"].tap()
        XCTAssertTrue(app.alerts["Independent alert"].waitForExistence(timeout: 3))
    }

    func testImageCancellationWhenLeavingAndLargeTypeControl() {
        let app = XCUIApplication()
        app.launchArguments = ["--large-type"]
        app.launch()
        app.tabBars.buttons["Custom A"].tap()
        app.switches["Slow image"].switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Started: 2 Cancelled: 0"].waitForExistence(timeout: 5))
        app.buttons["Leave page"].tap()
        XCTAssertTrue(app.staticTexts["Started: 2 Cancelled: 1"].waitForExistence(timeout: 5))
    }

    func testLargeListScrollAndRepeatedPageMemory() {
        let app = XCUIApplication()
        app.launchArguments = ["--large-list"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Consumer row 0"].waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(application: app)], options: options) {
            app.swipeUp()
            app.swipeDown()
            app.tabBars.buttons["Custom A"].tap()
            app.buttons["Leave page"].tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
            app.tabBars.buttons["Paging"].tap()
        }
    }
}
