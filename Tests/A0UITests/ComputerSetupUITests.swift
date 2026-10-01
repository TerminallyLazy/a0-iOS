import XCTest

@MainActor final class ComputerSetupUITests:XCTestCase {
    func testNewChatShowsSetupResultsWithoutEnablingTargetedSend() {
        let app=XCUIApplication()
        app.launchArguments=["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-host-presence","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["newChat"].waitForExistence(timeout:10))
        app.buttons["newChat"].tap();app.waitForConversation()
        app.buttons["hostComputer"].tap()
        XCTAssertTrue(app.staticTexts["Fixture Mac"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Browser, Tested"].waitForExistence(timeout:10))
        for label in ["Computer use, Tested","Read files, Allowed","Write files, Allowed","Code execution, Allowed"] {
            XCTAssertTrue(app.staticTexts[label].exists)
        }
        XCTAssertFalse(app.staticTexts["Not verified"].exists)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="New-chat host permissions and setup results";shot.lifetime = .keepAlways;add(shot)
        app.swipeUp()
        XCTAssertTrue(app.buttons["Check my computer"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Use my browser"].isEnabled)
        XCTAssertFalse(app.buttons["Check my computer"].isEnabled)
    }
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
