import XCTest

@MainActor final class ConversationUITests: XCTestCase {
    func testExistingChatOpensTranscriptAndBackAllowsSwitchingWithoutLosingDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout: 8))
        app.buttons["chat-alpha"].tap()
        guard app.navigationBars["chat-alpha"].waitForExistence(timeout: 5) else {
            XCTFail("Selecting a chat must open its conversation, not leave the chat list on screen."); return
        }
        XCTAssertTrue(app.staticTexts["Conversation content for chat-alpha"].waitForExistence(timeout: 8))
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Unsent alpha draft")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["chat-beta"].tap()
        XCTAssertTrue(app.navigationBars["chat-beta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Conversation content for chat-beta"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Conversation content for chat-alpha"].exists)
        XCTAssertNotEqual(draft.value as? String, "Unsent alpha draft")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["chat-alpha"].tap()
        XCTAssertTrue(app.staticTexts["Conversation content for chat-alpha"].waitForExistence(timeout: 8))
        XCTAssertEqual(draft.value as? String, "Unsent alpha draft")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Selected conversation"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["chat-empty"].tap()
        XCTAssertTrue(app.navigationBars["chat-empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No messages yet"].waitForExistence(timeout: 8))
        app.disconnectFromChat()
        XCTAssertTrue(app.buttons["Connect securely"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["chat-empty"].exists)
    }
    func testRealtimeSelectionKeepsConversationOpenThroughHandshake() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-realtime-selection", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.connectionStatus("Live").waitForExistence(timeout: 25))
        app.buttons["chat-alpha"].tap()
        XCTAssertTrue(app.navigationBars["chat-alpha"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Conversation content for chat-alpha"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.connectionStatus("Live").waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["chat-alpha"].exists)
        XCTAssertTrue(app.descendants(matching:.any)["messageDraft"].firstMatch.exists)
    }

}
