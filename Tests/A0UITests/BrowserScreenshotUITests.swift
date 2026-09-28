import XCTest

@MainActor final class BrowserScreenshotUITests: XCTestCase {
    func testCaptureIsVisibleInCollapsedActivityAndOpensContainedPreview() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-browser-screenshot","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        let screenshot = app.buttons["browserScreenshot"]
        XCTAssertTrue(screenshot.waitForExistence(timeout:10))
        let enabled = NSPredicate(format:"enabled == true")
        expectation(for:enabled,evaluatedWith:screenshot)
        waitForExpectations(timeout:10)
        capture(app,"Browser capture in collapsed activity")
        screenshot.tap()
        let close = app.buttons["Close screenshot preview"]
        XCTAssertTrue(close.waitForExistence(timeout:3))
        let preview = app.descendants(matching:.any)["browserScreenshotPreview"].firstMatch
        XCTAssertTrue(preview.exists)
        XCTAssertLessThan(preview.frame.height,app.frame.height * 0.9)
        capture(app,"Contained browser capture preview")
        close.tap()
        XCTAssertTrue(app.navigationBars["chat-alpha"].exists)
        XCTAssertFalse(close.exists)
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
