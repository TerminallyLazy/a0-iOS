import XCTest

@MainActor final class DrawerUITests:XCTestCase {
    func testFreshLaunchDrawerSearchSelectionAndNewConversation() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-projects","--synthetic-launch-chat","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["openSidebar"].waitForExistence(timeout:12))
        XCTAssertFalse(app.buttons["sidebarClose"].exists)
        XCTAssertTrue(app.navigationBars["New chat"].exists)
        capture(app,"Fresh conversation after startup")
        app.buttons["openSidebar"].tap()
        XCTAssertTrue(app.buttons["sidebarClose"].waitForExistence(timeout:3))
        capture(app,"Leading conversation drawer with projects")
        app.textFields["sidebarSearch"].tap(); app.textFields["sidebarSearch"].typeText("chat-beta")
        XCTAssertTrue(app.buttons["sidebar-chat-chat-beta"].waitForExistence(timeout:3))
        app.buttons["sidebar-chat-chat-beta"].tap()
        XCTAssertTrue(app.navigationBars["chat-beta"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["sidebarClose"].exists)
        app.buttons["openSidebar"].tap(); app.buttons["sidebarClose"].tap()
        XCTAssertTrue(app.navigationBars["chat-beta"].exists)
        app.buttons["openSidebar"].tap(); app.buttons["sidebarNewChat"].tap()
        XCTAssertTrue(app.navigationBars["New chat"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["sidebarClose"].exists)
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
