import XCTest

@MainActor final class RecoveryUITests: XCTestCase {
    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview",mode,"--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
        app.openComposer()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep draft")
        return app
    }
    func testTransientFailureRecoversWithoutResendingDraft() {
        let app = launch("--synthetic-poll-recovery")
        XCTAssertTrue(app.connectionStatus("Reconnecting").waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
        XCTAssertEqual(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String,"Keep draft")
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Draft retained during recovery"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:30))
        app.openComposer()
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        XCTAssertEqual(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String,"Keep draft")
        XCTAssertFalse(app.staticTexts["Accepted by server"].exists)
    }
    func testExhaustedRetriesRequireExplicitReadOnlyRetry() {
        let app = launch("--synthetic-poll-exhaust")
        XCTAssertTrue(app.connectionStatus("Sync paused").waitForExistence(timeout:35))
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
        XCTAssertEqual(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String,"Keep draft")
        app.buttons["connectionStatus"].tap()
        app.buttons["Retry sync"].tap()
        app.buttons["Close"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
        app.openComposer()
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        XCTAssertEqual(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String,"Keep draft")
    }
    func testBackgroundPausesRecoveryAndResumesWithoutSigningIn() {
        let app = launch("--synthetic-poll-recovery")
        XCTAssertTrue(app.connectionStatus("Reconnecting").waitForExistence(timeout:10))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:30))
        XCTAssertFalse(app.buttons["Connect securely"].exists)
        XCTAssertEqual(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String,"Keep draft")
        XCTAssertFalse(app.staticTexts["Accepted by server"].exists)
    }
    func testRejectedSessionStopsWithoutRetryingAuthentication() {
        let app = launch("--synthetic-poll-auth-expired")
        XCTAssertTrue(app.staticTexts["Connection needs attention"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Sign in to this Agent Zero server."].exists)
        XCTAssertFalse(app.buttons["Retry sync"].exists)
        XCTAssertFalse(app.connectionStatus("Reconnecting").exists)
    }
}
