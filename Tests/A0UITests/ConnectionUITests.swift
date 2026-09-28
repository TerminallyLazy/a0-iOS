import XCTest

@MainActor final class ConnectionUITests: XCTestCase {
    func testConnectRemainsReachableAbovePasswordKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["--profile-ui-test", "--persistence-test-id", UUID().uuidString]
        app.launch()
        let origin = app.textFields["serverOrigin"]
        XCTAssertTrue(origin.waitForExistence(timeout:8))
        let initialConnect = app.buttons["Connect securely"]
        XCTAssertLessThan(app.frame.maxY - initialConnect.frame.maxY, 100,
                          "Connect must remain in the bottom action area, independent of form scrolling.")
        origin.tap(); origin.typeText("https://fixture.agentzero.invalid")
        let username = app.textFields["Username"]
        app.revealConnectionField(username)
        username.tap(); username.typeText("fixture")
        let password = app.secureTextFields["Password"]
        app.revealConnectionField(password)
        password.tap(); password.typeText("fixture")
        let connect = app.buttons["Connect securely"]
        XCTAssertTrue(connect.isEnabled)
        XCTAssertTrue(connect.isHittable, "Connect must be reachable without dismissing the keyboard or scrolling.")
        if app.keyboards.firstMatch.exists {
            XCTAssertLessThanOrEqual(connect.frame.maxY, app.keyboards.firstMatch.frame.minY,
                                     "Connect must remain above the software keyboard.")
        }
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Connect above keyboard"; shot.lifetime = .keepAlways; add(shot)
        connect.tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
    }
}

// XCTest can report an offscreen form field even when its center is covered by
// the keyboard action area. Scroll within the visible list before targeting it.
extension XCUIApplication {
    func revealConnectionField(_ field: XCUIElement) {
        let actionTop = buttons["connectServer"].frame.minY
        guard field.frame.maxY > actionTop - 12 else { return }
        let base = coordinate(withNormalizedOffset: .zero)
        let start = base.withOffset(CGVector(dx: frame.width / 2, dy: actionTop - 20))
        let end = base.withOffset(CGVector(dx: frame.width / 2, dy: max(150, actionTop - 200)))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}

@MainActor extension XCUIApplication {
    func openComposer() {
        if buttons["resumeConversation"].exists { buttons["resumeConversation"].tap() }
        else if buttons["newChat"].exists { buttons["newChat"].tap() }
        waitForConversation()
    }
    func waitForConversation() {
        XCTAssertTrue(buttons["conversationOptions"].waitForExistence(timeout:5))
    }
    func disconnectFromChat() {
        if buttons["conversationOptions"].exists { buttons["conversationOptions"].tap() }
        buttons["Disconnect"].tap()
    }
}

@MainActor extension XCUIApplication {
    func connectionStatus(_ status: String) -> XCUIElement {
        if buttons["connectionStatus"].exists {
            return buttons.matching(identifier:"connectionStatus").matching(NSPredicate(format:"value == %@",status)).firstMatch
        }
        return staticTexts[status]
    }
}
