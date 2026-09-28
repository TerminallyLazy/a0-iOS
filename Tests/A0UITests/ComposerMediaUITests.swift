import XCTest

@MainActor final class ComposerMediaUITests: XCTestCase {
    func testStatusIsCompactAndExplainsConnectionOnTap() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        let indicator = app.buttons["connectionStatus"]
        XCTAssertTrue(indicator.waitForExistence(timeout:5))
        XCTAssertEqual(indicator.value as? String,"Polling")
        XCTAssertFalse(app.staticTexts["Polling"].exists)
        XCTAssertGreaterThan(indicator.frame.midX,app.frame.midX)
        XCTAssertGreaterThan(indicator.frame.midY,app.frame.midY)
        assertIndicatorInsideInput(app)
        indicator.tap()
        XCTAssertTrue(app.staticTexts["Polling"].waitForExistence(timeout:3))
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Compact connection detail"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["sendMessage"].exists)
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        let text = "Keep this draft. " + String(repeating:"A long message should wrap without touching the status dot. ",count:5)
        draft.tap(); draft.typeText(text)
        XCTAssertTrue(indicator.isHittable)
        XCTAssertLessThanOrEqual(indicator.frame.maxX,app.frame.maxX)
        assertIndicatorInsideInput(app)
        let keyboardShot = XCTAttachment(screenshot:app.screenshot()); keyboardShot.name = "Composer status with keyboard"; keyboardShot.lifetime = .keepAlways; add(keyboardShot)
        app.buttons["dismissKeyboard"].tap()
        XCTAssertEqual(draft.value as? String,text)
        assertIndicatorInsideInput(app)
    }
    private func assertIndicatorInsideInput(_ app: XCUIApplication) {
        let card = app.otherElements["messageInputCard"]
        let indicator = app.buttons["connectionStatus"]
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:3))
        XCTAssertGreaterThanOrEqual(indicator.frame.width,44)
        XCTAssertGreaterThanOrEqual(indicator.frame.height,44)
        XCTAssertGreaterThanOrEqual(indicator.frame.minY,card.frame.minY)
        XCTAssertLessThanOrEqual(indicator.frame.minY,card.frame.minY + 8)
        XCTAssertLessThanOrEqual(indicator.frame.maxX,card.frame.maxX)
        XCTAssertGreaterThanOrEqual(indicator.frame.maxX,card.frame.maxX - 12)
        XCTAssertLessThanOrEqual(draft.frame.maxX,indicator.frame.minX)
    }
}
