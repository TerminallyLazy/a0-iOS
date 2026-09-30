import XCTest

/// Captures actual views with fictional, local-only content; no live server or account.
@MainActor final class AppStoreScreenshotUITests:XCTestCase {
    func testCaptureChatAndBrandOption() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-app-store","--synthetic-launch-chat","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["openSidebar"].waitForExistence(timeout:15)); app.buttons["openSidebar"].tap()
        let chat = app.buttons["sidebar-chat-chat-alpha"]
        XCTAssertTrue(chat.waitForExistence(timeout:15)); chat.tap()
        let answer = app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Your afternoon, simplified")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout:10))
        let expand = app.buttons["expandMessage-1"]
        if expand.exists { expand.tap() }
        capture(app,"01-chat")
        app.terminate()
        app.launchArguments = ["--synthetic-brand-screenshot","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.staticTexts["Restoring your session"].waitForExistence(timeout:10))
        capture(app,"optional-brand-launch")
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
