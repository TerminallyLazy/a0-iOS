import XCTest

@MainActor final class ComputerSetupUITests:XCTestCase {
    func testSetupGuidanceAndContinuationWithoutSendingChat() {
        let app=XCUIApplication()
        app.launchArguments=["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-computer-setup","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
        app.buttons["chat-alpha"].tap();app.waitForConversation()
        app.buttons["hostComputer"].tap()
        app.buttons["Connect your computer"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Show me how"].firstMatch.waitForExistence(timeout:10))
        app.buttons["Show me how"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Open Launcher on your computer and connect to this same server. No phone is required."].exists)
        app.swipeUp()
        app.buttons["Create setup code"].tap()
        XCTAssertTrue(app.staticTexts["Setup code ABCD-EFGH-JKLM"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["Create setup code"].isEnabled)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Computer setup continuation";shot.lifetime = .keepAlways;add(shot)
    }
}
