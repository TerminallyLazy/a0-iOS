import XCTest

@MainActor final class PersistenceUITests: XCTestCase {
    private func app(timeout: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--persistence-test-id", UUID().uuidString]
        if timeout { app.launchArguments += ["--synthetic-send-timeout"] }
        return app
    }
    func testDraftSurvivesTerminationAndCanBeCleared() {
        let app = app(); app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep across app termination")
        expectation(for: NSPredicate(format: "value == %@", "Saved on this device"), evaluatedWith: app.buttons["draftOptions"])
        waitForExpectations(timeout: 5)
        app.terminate(); app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        XCTAssertEqual(draft.value as? String, "Keep across app termination")
        app.buttons["draftOptions"].tap(); app.buttons["Clear draft"].tap()
        app.buttons["Clear saved draft"].tap()
        expectation(for: NSPredicate(format: "value == %@", "Saved on this device"), evaluatedWith: app.buttons["draftOptions"])
        waitForExpectations(timeout: 5)
        app.terminate(); app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        XCTAssertTrue(draft.exists)
        XCTAssertTrue([nil, "", "Message"].contains(draft.value as? String), "Cleared draft must be empty; iOS versions expose empty values differently.")
    }
    func testUncertainSendSurvivesTerminationWithoutReplay() {
        let app = app(timeout:true); app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Never resend automatically")
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Outcome unknown"].waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "value == %@", "Saved on this device"), evaluatedWith: app.buttons["draftOptions"])
        waitForExpectations(timeout: 5)
        app.terminate(); app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        XCTAssertEqual(draft.value as? String, "Never resend automatically")
        XCTAssertTrue(app.staticTexts["Outcome unknown"].exists)
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
    }
    func testStorageFailureOffersRetryAndKeepsDraft() {
        let app = app(); app.launchArguments += ["--synthetic-storage-failure"]
        app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep when disk fails")
        XCTAssertTrue(app.staticTexts["Draft not saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Retry saving"].exists)
        XCTAssertEqual(draft.value as? String, "Keep when disk fails")
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
    }
}
