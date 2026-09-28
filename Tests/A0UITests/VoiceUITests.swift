import XCTest

@MainActor final class VoiceUITests: XCTestCase {
    private func app(syntheticVoice: Bool = false, holdsFirstSnapshot: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--persistence-test-id", UUID().uuidString]
        if syntheticVoice { app.launchArguments.append("--synthetic-voice-input") }
        if holdsFirstSnapshot { app.launchArguments.append("--synthetic-voice-edit") }
        app.launch(); openChat(app)
        return app
    }
    private func openChat(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout: 8))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
    }
    private func expectDraft(_ text: String, in app: XCUIApplication) {
        expectation(for: NSPredicate(format: "value == %@", text), evaluatedWith: app.descendants(matching: .any)["messageDraft"].firstMatch)
        waitForExpectations(timeout: 8)
    }
    #if targetEnvironment(simulator)
    /// Run with simulator microphone permission denied; never starts audio capture.
    func testDeniedPermissionReturnsWithoutExecutorCrash() {
        let app = app()
        app.buttons["voiceControls"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if system.alerts.buttons["Don’t Allow"].waitForExistence(timeout: 3) { system.alerts.buttons["Don’t Allow"].tap() }
        else if system.alerts.buttons["Don't Allow"].exists { system.alerts.buttons["Don't Allow"].tap() }
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Settings"), evaluatedWith: app.staticTexts["voiceStatus"])
        waitForExpectations(timeout: 8)
        XCTAssertEqual(app.buttons["voiceControls"].value as? String, "Stopped")
    }
    #endif
    func testVoiceOptionsPreserveDraftAndContinuousPreferenceAcrossRelaunch() {
        let app = app()
        let draft = app.descendants(matching: .any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep this note")
        app.buttons["dismissKeyboard"].tap()
        app.buttons["voiceOptions"].tap()
        app.buttons["continuousVoice"].tap()
        XCTAssertEqual(app.buttons["voiceOptions"].value as? String, "Continuous listening on")
        XCTAssertEqual(app.buttons["voiceControls"].value as? String, "Stopped")
        XCTAssertEqual(draft.value as? String, "Keep this note")
        XCTAssertFalse(app.navigationBars["Voice"].exists)
        XCTAssertFalse(app.staticTexts["Saved on this device"].exists)
        app.terminate(); app.launch(); openChat(app)
        XCTAssertEqual(app.buttons["voiceOptions"].value as? String, "Continuous listening on")
        XCTAssertEqual(app.buttons["voiceControls"].value as? String, "Stopped")
        XCTAssertEqual(draft.value as? String, "Keep this note")
    }
    func testSyntheticDictationStreamsIntoExistingComposerWithoutSending() {
        let app = app(syntheticVoice: true)
        let draft = app.descendants(matching: .any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Please check")
        app.buttons["dismissKeyboard"].tap()
        app.buttons["voiceControls"].tap()
        expectDraft("Please check\n\nweather tomorrow", in: app)
        expectation(for: NSPredicate(format: "value == %@", "Stopped"), evaluatedWith: app.buttons["voiceControls"])
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        XCTAssertFalse(app.navigationBars["Voice"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Inline synthetic dictation in composer"; shot.lifetime = .keepAlways; add(shot)
    }
    func testBackgroundStopsSyntheticDictationWithoutResuming() {
        let app = app(syntheticVoice: true, holdsFirstSnapshot: true)
        app.buttons["voiceOptions"].tap(); app.buttons["continuousVoice"].tap()
        app.buttons["voiceControls"].tap()
        expectDraft("weather", in: app)
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        expectation(for: NSPredicate { _, _ in app.state == .runningBackground || app.state == .runningBackgroundSuspended }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        app.activate()
        XCTAssertTrue(app.buttons["voiceControls"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["voiceControls"].value as? String, "Stopped")
        XCTAssertEqual(app.buttons["voiceOptions"].value as? String, "Continuous listening on")
        expectDraft("weather", in: app)
    }
    func testTypingStopsSyntheticDictationAndKeepsManualCorrection() {
        let app = app(syntheticVoice: true, holdsFirstSnapshot: true)
        let draft = app.descendants(matching: .any)["messageDraft"].firstMatch
        app.buttons["voiceControls"].tap()
        expectDraft("weather", in: app)
        draft.tap(); draft.typeText(" edited")
        expectation(for: NSPredicate(format: "value == %@", "Stopped"), evaluatedWith: app.buttons["voiceControls"])
        waitForExpectations(timeout: 3)
        let edited = draft.value as? String
        XCTAssertEqual(edited?.replacingOccurrences(of: " edited", with: ""), "weather")
        XCTAssertTrue(edited?.contains("edited") == true)
        app.buttons["dismissKeyboard"].tap()
        let changed = expectation(for: NSPredicate(format: "value != %@", edited ?? ""), evaluatedWith: draft)
        changed.isInverted = true
        waitForExpectations(timeout: 8)
        XCTAssertEqual(draft.value as? String, edited)
    }
}
