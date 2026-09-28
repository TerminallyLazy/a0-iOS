import XCTest

@MainActor final class WorkspaceUITests: XCTestCase {
    func testWorkspaceToolsAndAgentsKeepConversation() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-agent-work","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10)); app.buttons["chat-alpha"].tap(); app.waitForConversation()
        XCTAssertTrue(app.descendants(matching:.any)["agentWorkStatus"].firstMatch.waitForExistence(timeout:5))
        capture(app,"Working agent and composer")
        app.buttons["agentActivity"].tap()
        XCTAssertTrue(app.navigationBars["Agents"].waitForExistence(timeout:3))
        capture(app,"Subagent activity inspector")
        app.buttons["Done"].tap()
        app.buttons["conversationOptions"].tap(); app.buttons["sidebar.left"].tap()
        app.textFields["sidebarSearch"].tap(); app.textFields["sidebarSearch"].typeText("chat-beta")
        XCTAssertTrue(app.buttons["sidebar-chat-chat-beta"].waitForExistence(timeout:3))
        capture(app,"Conversation sidebar")
        app.buttons["sidebar-chat-chat-beta"].tap()
        XCTAssertTrue(app.navigationBars["chat-beta"].waitForExistence(timeout:5))
        app.buttons["contextUsage"].tap()
        XCTAssertTrue(app.staticTexts["Context window"].waitForExistence(timeout:3))
        XCTAssertTrue(app.staticTexts["Messages"].waitForExistence(timeout:5))
        capture(app,"Context window token breakdown")
        let usageScroll = app.scrollViews["contextUsageScroll"]
        for _ in 0..<8 {
            if app.staticTexts["Cache hit"].exists && app.staticTexts["Cache hit"].isHittable { break }
            usageScroll.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Cache hit"].exists)
        capture(app,"Context window provider usage")
        app.buttons["Close"].tap()
        app.buttons["chatTools"].tap()
        XCTAssertTrue(app.buttons["serverHistory"].waitForExistence(timeout:3))
        capture(app,"Compact conversation tools popover")
        app.buttons["serverHistory"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic conversation history"].waitForExistence(timeout:5))
        app.buttons["backToTools"].tap()
        app.buttons["serverContext"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic active context"].waitForExistence(timeout:5))
        capture(app,"Conversation context")
        app.buttons["backToTools"].tap()
        capture(app,"Conversation tools")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["chat-beta"].exists)
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
