import XCTest

@MainActor final class AttachmentUITests: XCTestCase {
    func testExplicitAttachmentSelectionRemovalAndUncertainRelaunch() {
        let app = XCUIApplication()
        let arguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-attachments", "--synthetic-send-timeout", "--persistence-test-id", UUID().uuidString]
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout: 10)); app.buttons["chat-alpha"].tap()
        app.waitForConversation()
        attachSample(app)
        XCTAssertTrue(app.staticTexts["sample.txt"].waitForExistence(timeout: 5))
        let remove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "removeAttachment-")).firstMatch
        XCTAssertTrue(remove.exists); remove.tap()
        XCTAssertFalse(app.staticTexts["sample.txt"].exists)
        attachSample(app)
        XCTAssertTrue(app.staticTexts["sample.txt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Locally staged file in composer"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Outcome unknown"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
        app.terminate()
        app.launchArguments = arguments + ["--synthetic-session-restore", "--synthetic-launch-chat"]
        app.launch()
        XCTAssertTrue(app.buttons["openSidebar"].waitForExistence(timeout: 15)); app.buttons["openSidebar"].tap()
        XCTAssertTrue(app.buttons["sidebar-chat-chat-alpha"].waitForExistence(timeout: 8)); app.buttons["sidebar-chat-chat-alpha"].tap()
        XCTAssertTrue(app.staticTexts["sample.txt"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
    }
    func testSlowImportBlocksSendUntilSelectedFileIsReady() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-attachments","--synthetic-attachment-delay","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10)); app.buttons["chat-alpha"].tap(); app.waitForConversation()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Send together"); app.buttons["dismissKeyboard"].tap()
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        attachSample(app)
        XCTAssertTrue(app.descendants(matching:.any)["attachmentImportStatus"].firstMatch.waitForExistence(timeout:3))
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
        XCTAssertTrue(app.staticTexts["sample.txt"].waitForExistence(timeout:12))
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
        XCTAssertEqual(draft.value as? String,"Send together")
    }
    #if targetEnvironment(simulator)
    func testNativeFilesPickerCanCancelWithoutChangingDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout: 10)); app.buttons["chat-alpha"].tap()
        app.waitForConversation()
        app.buttons["chatTools"].tap()
        XCTAssertTrue(app.buttons["attachFiles"].waitForExistence(timeout: 5)); app.buttons["attachFiles"].tap()
        XCTAssertTrue(app.buttons["attachDocuments"].firstMatch.waitForExistence(timeout: 5)); app.buttons["attachDocuments"].firstMatch.tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8)); cancel.tap()
        XCTAssertTrue(app.buttons["chatTools"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.scrollViews["attachmentTray"].exists)
    }
    #endif
    private func attachSample(_ app: XCUIApplication) {
        app.buttons["chatTools"].tap()
        XCTAssertTrue(app.buttons["attachFiles"].waitForExistence(timeout: 5)); app.buttons["attachFiles"].tap()
        XCTAssertTrue(app.buttons.matching(identifier:"attachSyntheticFile").firstMatch.waitForExistence(timeout: 5)); app.buttons.matching(identifier:"attachSyntheticFile").firstMatch.tap()
    }
}
