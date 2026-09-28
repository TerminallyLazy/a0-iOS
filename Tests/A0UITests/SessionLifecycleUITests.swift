import XCTest

@MainActor final class SessionLifecycleUITests: XCTestCase {
    func testGeneratedReplySurvivesBackgroundAndSessionRestoresAfterTermination() {
        let app = XCUIApplication()
        let namespace = UUID().uuidString
        let args = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-generative-ui", "--persistence-test-id", namespace]
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout: 10))
        app.buttons["chat-alpha"].tap()
        app.waitForConversation()
        XCTAssertTrue(app.staticTexts["Plan your afternoon"].waitForExistence(timeout: 8))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Plan your afternoon"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Connect securely"].exists)
        app.terminate()
        app.launchArguments = args + ["--synthetic-session-restore", "--synthetic-launch-chat"]
        app.launch()
        // Connection restores into a fresh conversation; existing generated replies stay in the drawer.
        XCTAssertTrue(app.buttons["openSidebar"].waitForExistence(timeout:15))
        XCTAssertFalse(app.descendants(matching:.any)["conversationDrawer"].firstMatch.exists)
        app.buttons["openSidebar"].tap()
        XCTAssertTrue(app.buttons["sidebar-chat-chat-alpha"].waitForExistence(timeout:8))
        app.buttons["sidebar-chat-chat-alpha"].tap()
        XCTAssertTrue(app.staticTexts["Plan your afternoon"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Connect securely"].exists)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Generated reply after secure session relaunch"
        image.lifetime = .keepAlways
        add(image)
    }
}
