import XCTest

@MainActor final class JevUITests: XCTestCase {
    func testSecureSettingsSaveEnableReplaceRemove() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        let setup = app.buttons["generativeUISetup"]
        if !setup.isHittable { app.swipeUp() }
        setup.tap()
        let field = app.secureTextFields["jevAPIKey"]
        for _ in 0..<5 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout:3))
        field.tap(); field.typeText("synthetic-ui-key")
        app.buttons["jevSaveKey"].tap()
        XCTAssertTrue(app.staticTexts["Key saved on this device"].waitForExistence(timeout:3))
        XCTAssertEqual(app.switches["jevEnabled"].value as? String,"0")
        app.switches["jevEnabled"].tap()
        XCTAssertEqual(app.switches["jevEnabled"].value as? String,"1")
        field.tap(); field.typeText("replacement")
        app.buttons["jevSaveKey"].tap()
        XCTAssertEqual(app.switches["jevEnabled"].value as? String,"0")
        app.buttons["jevRemoveKey"].tap()
        XCTAssertTrue(app.staticTexts["No key saved"].waitForExistence(timeout:3))
        XCTAssertFalse(app.switches["jevEnabled"].isEnabled)
        let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "Jev settings without credentials"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
