import XCTest

@MainActor final class PromotionUITests: XCTestCase {
    private func launch(_ mode: String = "--synthetic-realtime-success") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", mode, "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout:8))
        app.openComposer()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep draft")
        return app
    }
    func testPollingPromotesOnlyAfterFullStateAndKeepsDraft() {
        let app = launch()
        XCTAssertTrue(app.connectionStatus("Checking realtime").waitForExistence(timeout:12))
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Polling during realtime handoff"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertFalse(app.connectionStatus("Live").exists)
        XCTAssertTrue(app.connectionStatus("Live").waitForExistence(timeout:12))
        XCTAssertEqual(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String, "Keep draft")
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        XCTAssertFalse(app.staticTexts["Accepted by server"].exists)
        XCTAssertFalse(app.connectionStatus("Polling").waitForExistence(timeout:4))
    }
    func testCreatingChatCancelsCandidateForOldSelection() {
        let app = launch()
        XCTAssertTrue(app.connectionStatus("Checking realtime").waitForExistence(timeout:12))
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Accepted by server"].waitForExistence(timeout:5))
        XCTAssertFalse(app.connectionStatus("Live").waitForExistence(timeout:8))
        XCTAssertTrue(app.descendants(matching:.any)["messageDraft"].firstMatch.exists)
        XCTAssertTrue([nil, "", "Message"].contains(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String))
        XCTAssertTrue(app.connectionStatus("Polling").exists)
    }
    func testMissingFullStateTimesOutToHealthyPolling() {
        let app = launch("--synthetic-realtime-timeout")
        XCTAssertTrue(app.connectionStatus("Checking realtime").waitForExistence(timeout:12))
        XCTAssertFalse(app.connectionStatus("Live").exists)
        app.buttons["connectionStatus"].tap()
        XCTAssertTrue(app.staticTexts["Realtime retry did not complete. Polling keeps your state current."].waitForExistence(timeout:15))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").exists)
        XCTAssertEqual(app.descendants(matching:.any)["messageDraft"].firstMatch.value as? String, "Keep draft")
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
    }
    func testRejectedRefreshRequiresSignIn() {
        let app = launch("--synthetic-realtime-auth-expired")
        XCTAssertTrue(app.staticTexts["Connection needs attention"].waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["Sign in to this Agent Zero server."].exists)
        XCTAssertFalse(app.connectionStatus("Live").exists)
        XCTAssertTrue(app.buttons["Connect securely"].exists)
    }
    func testBackgroundCancelsCandidateAndLatePush() {
        let app = launch()
        XCTAssertTrue(app.connectionStatus("Checking realtime").waitForExistence(timeout:12))
        // An explicit foreground app provides a verifiable background transition
        // on physical devices where an injected Home press can be ignored.
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        let background = NSPredicate(format: "state == %d OR state == %d",
            XCUIApplication.State.runningBackground.rawValue,
            XCUIApplication.State.runningBackgroundSuspended.rawValue)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: background, object: app)], timeout: 5), .completed)
        app.activate()
        XCTAssertTrue(app.staticTexts["Disconnected in background"].waitForExistence(timeout:5))
        XCTAssertFalse(app.connectionStatus("Live").waitForExistence(timeout:8))
        XCTAssertTrue(app.buttons["Connect securely"].exists)
    }
}
