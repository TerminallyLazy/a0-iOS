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
        XCTAssertFalse(app.buttons["stopAgent"].exists)
        let actions = app.buttons["composerSendActions"]
        guard actions.waitForExistence(timeout:5) else { XCTFail("Stop must share the send control while drafting"); return }
        let combined = XCTAttachment(screenshot:app.screenshot())
        combined.name = "Combined send and stop menu"; combined.lifetime = .keepAlways; add(combined)
        actions.tap()
        let stop = app.buttons["stopAgent"]
        XCTAssertTrue(stop.waitForExistence(timeout:5)); stop.tap()
        XCTAssertTrue(app.staticTexts["Agent stopped. Queued follow-ups cleared."].waitForExistence(timeout:8))
        XCTAssertEqual(draft.value as? String,"Keep this unsent draft")
        let screenshot = XCTAttachment(screenshot:app.screenshot())
        screenshot.name = "Composer Stop preserves draft"; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","Ready"),object:app.buttons["sendMessage"])],timeout:8),.completed)
    }
    func testStopFailureIsVisibleAndDoesNotSilentlyReplay() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-agent-work", "--synthetic-stop-failure", "--persistence-test-id", UUID().uuidString]
        app.launch(); openChat(app)
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:app.buttons["stopAgent"])],timeout:8),.completed)
        app.buttons["stopAgent"].tap()
        XCTAssertTrue(app.staticTexts["Stop outcome unconfirmed. Check the agent and queue in the WebUI before repeating."].waitForExistence(timeout:8), app.debugDescription)
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:app.buttons["stopAgent"])],timeout:8),.completed)
        app.buttons["stopAgent"].tap()
        XCTAssertTrue(app.staticTexts["Stop was not sent. Check saved actions in Chat tools and try again."].waitForExistence(timeout:8), app.debugDescription)
    }
    func testEmptyWorkingComposerHasOnePrimaryStopThenReturnsToSend() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-agent-work", "--persistence-test-id", UUID().uuidString]
        app.launch(); openChat(app)
        XCTAssertTrue(app.buttons["stopAgent"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["sendMessage"].exists, "Empty working composer must have a single Stop control")
        XCTAssertFalse(app.buttons["composerSendActions"].exists)
        let primary = XCTAttachment(screenshot:app.screenshot())
        primary.name = "Primary stop while working"; primary.lifetime = .keepAlways; add(primary)
        app.buttons["stopAgent"].tap()
        XCTAssertTrue(app.staticTexts["Agent stopped. Queued follow-ups cleared."].waitForExistence(timeout:8))
        XCTAssertTrue(app.buttons["sendMessage"].waitForExistence(timeout:8))
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
        XCTAssertFalse(app.buttons["stopAgent"].exists)
    }
    func testAttachmentOnlyFollowUpStillQueuesAndReturnsToStop() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-agent-work", "--synthetic-attachments", "--persistence-test-id", UUID().uuidString]
        app.launch(); openChat(app)
        app.buttons["chatTools"].tap()
        app.buttons["attachFiles"].tap()
        app.buttons.matching(identifier:"attachSyntheticFile").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["sample.txt"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        XCTAssertTrue(app.buttons["composerSendActions"].exists)
        XCTAssertFalse(app.buttons["stopAgent"].exists)
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Queued on server"].firstMatch.waitForExistence(timeout:8))
        XCTAssertTrue(app.buttons["stopAgent"].waitForExistence(timeout:8))
        XCTAssertFalse(app.buttons["sendMessage"].exists)
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
