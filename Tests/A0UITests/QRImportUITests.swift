import XCTest

@MainActor final class QRImportUITests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--profile-ui-test", "--persistence-test-id", UUID().uuidString] + extra
        app.launch(); return app
    }
    private func openImport(_ app: XCUIApplication) {
        let button = app.buttons["Scan server QR"]
        XCTAssertTrue(button.waitForExistence(timeout:5))
        if button.exists { button.tap() }
    }
    private func review(_ url: String, in app: XCUIApplication) {
        let field = app.textFields["qrPayload"]
        XCTAssertTrue(field.waitForExistence(timeout:5))
        if field.exists { field.tap(); field.typeText(url); app.buttons["Review address"].tap() }
    }
    func testConfirmFillsAddressAndClearsCredentialsWithoutConnecting() {
        let app = launch()
        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout:5)); username.tap(); username.typeText("old-account")
        let password = app.secureTextFields["Password"]
        password.tap(); password.typeText("fixture")
        openImport(app); review("https://new.example:8443/",in:app)
        XCTAssertTrue(app.staticTexts["https://new.example:8443"].waitForExistence(timeout:5))
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Review destination"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Use this server"].tap()
        XCTAssertTrue(app.textFields["serverOrigin"].waitForExistence(timeout:5))
        XCTAssertEqual(app.textFields["serverOrigin"].value as? String,"https://new.example:8443")
        XCTAssertTrue(app.textFields["Username"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue([nil, "", "Username"].contains(app.textFields["Username"].value as? String))
        XCTAssertTrue([nil, "", "Password"].contains(app.secureTextFields["Password"].value as? String))
        XCTAssertFalse(app.buttons["Connect securely"].isEnabled)
        XCTAssertFalse(app.buttons["savedProfile"].exists)
    }
    func testCancelReviewKeepsExistingConnectionForm() {
        let app = launch()
        let field = app.textFields["serverOrigin"]
        XCTAssertTrue(field.waitForExistence(timeout:5)); field.tap(); field.typeText("https://keep.example")
        openImport(app); review("https://different.example",in:app)
        let cancel = app.buttons["Cancel import"]
        if cancel.exists { cancel.tap() }
        XCTAssertEqual(app.textFields["serverOrigin"].value as? String,"https://keep.example")
    }
    func testDeniedCameraAndInvalidPayloadRecoverToManualReview() {
        let app = launch(["--qr-camera-denied"])
        openImport(app)
        let camera = app.buttons["Open camera"]
        XCTAssertTrue(camera.waitForExistence(timeout:5)); if camera.exists { camera.tap() }
        XCTAssertTrue(app.staticTexts["Camera access is off. Allow access in Settings, or enter the server address below."].waitForExistence(timeout:5))
        review("https://agent.example?token=fixture",in:app)
        XCTAssertFalse(app.buttons["Use this server"].exists)
        XCTAssertEqual(app.textFields["qrPayload"].value as? String,"HTTPS server address")
        review("https://safe.example",in:app)
        XCTAssertTrue(app.buttons["Use this server"].waitForExistence(timeout:5))
    }
    func testUnavailableCameraStillAllowsManualEntry() {
        let app = launch(["--qr-camera-unavailable"])
        openImport(app)
        let camera = app.buttons["Open camera"]
        XCTAssertTrue(camera.waitForExistence(timeout:5)); if camera.exists { camera.tap() }
        XCTAssertTrue(app.staticTexts["QR scanning is unavailable on this device right now. Enter the server address below."].waitForExistence(timeout:5))
        review("https://safe.example",in:app)
        XCTAssertTrue(app.buttons["Use this server"].waitForExistence(timeout:5))
    }
}
