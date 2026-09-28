import XCTest

@MainActor final class ProfileUITests: XCTestCase {
    private func app() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--profile-ui-test", "--persistence-test-id", UUID().uuidString]
        return app
    }
    private func fill(_ app: XCUIApplication, password: String = "fixture") {
        let name = app.textFields["Profile name"]
        XCTAssertTrue(name.waitForExistence(timeout:5))
        guard name.exists else { return }
        name.tap(); name.typeText("My server")
        let origin = app.textFields["serverOrigin"]
        origin.tap(); origin.typeText("https://fixture.agentzero.invalid")
        let username = app.textFields["Username"]
        app.revealConnectionField(username)
        username.tap(); username.typeText("fixture")
        let secret = app.secureTextFields["Password"]
        app.revealConnectionField(secret)
        secret.tap(); secret.typeText(password)
    }
    private func remember(_ app: XCUIApplication) {
        let toggle = app.switches["rememberPassword"]
        app.swipeUp()
        if toggle.switches.firstMatch.exists { toggle.switches.firstMatch.tap() }
        else { toggle.tap() }
        XCTAssertEqual(toggle.value as? String,"1")
    }
    private func select(_ app: XCUIApplication) {
        let profile = app.buttons["savedProfile"].firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout:5))
        profile.tap(); app.swipeUp()
    }
    func testRememberedPasswordSurvivesRelaunchAndRequiresExplicitConnect() {
        let app = app(); app.launch(); fill(app)
        let toggle = app.switches["rememberPassword"]
        XCTAssertTrue(toggle.exists); guard toggle.exists else { return }
        remember(app); app.buttons["Connect securely"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
        app.terminate(); app.launch()
        select(app)
        XCTAssertTrue(app.staticTexts["Password loaded from Keychain"].waitForExistence(timeout:5))
        XCTAssertFalse(app.connectionStatus("Polling").exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved server selected; explicit connection required"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Connect securely"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
    }
    func testDefaultDoesNotStorePassword() {
        let app = app(); app.launch(); fill(app)
        guard app.textFields["Profile name"].exists else { return }
        app.buttons["Connect securely"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
        app.terminate(); app.launch(); select(app)
        XCTAssertTrue(app.textFields["Username"].waitForExistence(timeout:5))
        XCTAssertEqual(app.secureTextFields["Password"].value as? String,"Password")
        XCTAssertFalse(app.buttons["Connect securely"].isEnabled)
    }
    func testBackgroundClearsPasswordBeforeConnection() {
        let app = app(); app.launch(); fill(app)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertEqual(app.secureTextFields["Password"].value as? String,"Password")
        XCTAssertFalse(app.connectionStatus("Polling").exists)
    }
    func testChangingIdentityClearsLoadedPasswordAndForgetRemovesIt() {
        let app = app(); app.launch(); fill(app)
        guard app.switches["rememberPassword"].exists else { return }
        remember(app); app.buttons["Connect securely"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
        app.terminate(); app.launch(); select(app)
        XCTAssertTrue(app.staticTexts["Password loaded from Keychain"].waitForExistence(timeout:5))
        let username = app.textFields["Username"]
        username.tap(); username.typeText("-other")
        XCTAssertEqual(app.secureTextFields["Password"].value as? String,"Password")
        app.swipeDown(); select(app)
        XCTAssertTrue(app.staticTexts["Password loaded from Keychain"].waitForExistence(timeout:5))
        app.buttons["Forget saved password"].tap()
        XCTAssertTrue(app.staticTexts["Saved password removed"].waitForExistence(timeout:5))
        app.terminate(); app.launch(); select(app)
        XCTAssertEqual(app.secureTextFields["Password"].value as? String,"Password")
        app.swipeDown(); app.buttons["profileOptions"].firstMatch.tap(); app.buttons["Remove saved server"].tap()
        app.buttons["Remove server"].tap()
        XCTAssertTrue(app.staticTexts["Saved server removed. Its local drafts are kept."].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["savedProfile"].firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.textFields["Profile name"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["savedProfile"].firstMatch.exists)
    }
}
