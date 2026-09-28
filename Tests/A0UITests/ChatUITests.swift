import XCTest

@MainActor final class ChatUITests: XCTestCase {
    func testNewChatSendsAndClearsDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-preview"]
        app.launch()
        let newChat = app.buttons["newChat"]
        XCTAssertTrue(newChat.waitForExistence(timeout: 5))
        guard newChat.exists else { return }
        newChat.tap(); app.waitForConversation()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 3))
        draft.tap(); draft.typeText("Synthetic UI message")
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Accepted by server"].waitForExistence(timeout: 5))
        XCTAssertTrue(draft.exists)
        XCTAssertTrue([nil, "", "Message"].contains(draft.value as? String))
    }
    func testTimeoutKeepsDraftAndBlocksResend() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-preview", "--synthetic-send-timeout"]
        app.launch()
        let newChat = app.buttons["newChat"]
        XCTAssertTrue(newChat.waitForExistence(timeout: 5))
        guard newChat.exists else { return }
        newChat.tap(); app.waitForConversation()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep this draft")
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Outcome unknown"].waitForExistence(timeout: 5))
        XCTAssertEqual(draft.value as? String, "Keep this draft")
        XCTAssertFalse(app.buttons["sendMessage"].isEnabled)
    }
    func testHTTPConnectionSendAndReconnectKeepsDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview"]
        app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("HTTP fixture message")
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:app.buttons["sendMessage"])
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:5),.completed)
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Accepted by server"].waitForExistence(timeout: 5))
        draft.tap(); draft.typeText("Keep for reconnect")
        app.swipeUp()
        app.disconnectFromChat()
        let password = app.secureTextFields["Password"]
        app.revealConnectionField(password)
        password.tap(); password.typeText("fixture")
        app.buttons["Connect securely"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        XCTAssertEqual(draft.value as? String, "Keep for reconnect")
    }

    func testDifferentAccountDoesNotInheritDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview"]
        app.launch()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Private draft for first account")
        app.swipeUp(); app.disconnectFromChat()
        let username = app.textFields["Username"]
        username.tap()
        let old = username.value as? String ?? ""
        username.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "another")
        let password = app.secureTextFields["Password"]
        app.revealConnectionField(password)
        password.tap(); password.typeText("fixture")
        app.buttons["Connect securely"].tap()
        XCTAssertTrue(app.connectionStatus("Polling").waitForExistence(timeout: 8))
        app.openComposer()
        XCTAssertTrue(draft.exists)
        XCTAssertTrue([nil, "", "Message"].contains(draft.value as? String))
    }

}
