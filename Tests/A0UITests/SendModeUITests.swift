import XCTest

@MainActor final class SendModeUITests: XCTestCase {
    func testFollowUpsQueueByDefaultAndSteerPreferencePersists() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-agent-work", "--persistence-test-id", UUID().uuidString]
        app.launch()
        openChat(app)
        send(app, "Wait until ready")
        XCTAssertTrue(app.staticTexts["Queued on server"].firstMatch.waitForExistence(timeout: 8))
        openSettings(app)
        let modes = app.segmentedControls["sendModePreference"]
        XCTAssertTrue(modes.waitForExistence(timeout: 5))
        XCTAssertTrue(modes.buttons["Queue"].isSelected)
        modes.buttons["Steer"].tap()
        app.buttons["settingsDone"].tap()
        send(app, "Please change direction")
        XCTAssertTrue(app.staticTexts["Accepted by server"].firstMatch.waitForExistence(timeout: 8))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Follow-up accepted while agent works"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launch()
        openChat(app); openSettings(app)
        XCTAssertTrue(modes.waitForExistence(timeout: 5))
        XCTAssertTrue(modes.buttons["Steer"].isSelected)
    }
    func testStopFromComposerPreservesDraftAndStopsWorkingState() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-agent-work", "--persistence-test-id", UUID().uuidString]
        app.launch(); openChat(app)
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep this unsent draft")
        let stop = app.buttons["stopAgent"]
        XCTAssertTrue(stop.waitForExistence(timeout:5)); stop.tap()
        XCTAssertTrue(app.staticTexts["Agent stopped. Queued follow-ups cleared."].waitForExistence(timeout:8))
        XCTAssertEqual(draft.value as? String,"Keep this unsent draft")
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","Ready"),object:app.buttons["sendMessage"])],timeout:8),.completed)
    }
    private func openChat(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout: 10))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
    }
    private func openSettings(_ app: XCUIApplication) {
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        // Reading settings precede send mode; move only enough to expose the segment.
        if !app.segmentedControls["sendModePreference"].isHittable { app.swipeUp() }
    }
    private func send(_ app: XCUIApplication, _ message: String) {
        let draft = app.descendants(matching: .any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText(message)
        let send = app.buttons["sendMessage"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: send)], timeout: 8), .completed)
        XCTAssertEqual(send.value as? String, "Agent working")
        send.tap()
    }
}
