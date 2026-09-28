import XCTest

@MainActor final class ChatInterfaceUITests: XCTestCase {
    func testNewChatOpensDedicatedComposerAndStaysAfterSending() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["newChat"].waitForExistence(timeout: 8))
        capture(app,"Branded chat list")
        app.buttons["newChat"].tap()
        guard app.navigationBars["New chat"].waitForExistence(timeout: 4) else {
            XCTFail("New chat must open a dedicated conversation screen."); return
        }
        capture(app,"New conversation")
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("A new synthetic conversation")
        let send = app.buttons["sendMessage"]
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:send)],timeout:8),.completed)
        send.tap()
        XCTAssertTrue(app.staticTexts["Accepted by server"].waitForExistence(timeout:8))
        XCTAssertFalse(app.buttons["newChat"].exists)
        XCTAssertTrue(draft.exists)
    }
    func testActivityDetailsAndLinkConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-activity-transcript", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap()
        XCTAssertTrue(app.buttons["expandMessage-0"].waitForExistence(timeout:8))
        let link = app.descendants(matching:.any).matching(NSPredicate(format:"label == %@", "Reference")).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout:5))
        link.tap()
        XCTAssertTrue(app.alerts["Open external link?"].waitForExistence(timeout:3))
        app.alerts.buttons["Cancel"].tap()
        app.buttons["expandMessage-0"].tap()
        app.buttons["Details"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic result detail"].waitForExistence(timeout:3))
        app.buttons["Copy code"].tap()
        XCTAssertTrue(app.buttons["Copied"].waitForExistence(timeout:3))
    }
    func testConsecutiveActivityRollsUpWithoutHidingAnswer() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-grouped-activity", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap()
        let group = app.buttons["activityGroup-0"]
        XCTAssertTrue(group.waitForExistence(timeout:8))
        XCTAssertTrue(app.staticTexts["Here is the answer."].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["expandMessage-1"].exists)
        capture(app,"Grouped agent activity")
        group.tap()
        XCTAssertTrue(app.buttons["expandMessage-1"].waitForExistence(timeout:5))
        app.buttons["expandMessage-1"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic tool result"].waitForExistence(timeout:5))
        group.tap()
        XCTAssertFalse(app.buttons["collapseMessage-1"].exists)
    }
    func testKeyboardCanDismissWithoutSendingOrLosingDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["newChat"].waitForExistence(timeout:8))
        app.buttons["newChat"].tap(); app.waitForConversation()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep this draft")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:3))
        guard app.buttons["dismissKeyboard"].waitForExistence(timeout:3) else { XCTFail("Keyboard needs an explicit dismiss action"); return }
        capture(app,"Keyboard dismissal control")
        app.buttons["dismissKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout:3))
        XCTAssertEqual(draft.value as? String,"Keep this draft")
        XCTAssertFalse(app.staticTexts["Accepted by server"].exists)
        capture(app,"Keyboard dismissed with draft retained")
    }
    func testSettingsPreferencesPersistAndKeepConversation() {
        let app = XCUIApplication()
        let namespace = UUID().uuidString
        app.launchArguments = ["--synthetic-http-preview", "--persistence-test-id", namespace]
        app.launch()
        guard app.buttons["openSettings"].waitForExistence(timeout:8) else { XCTFail("Settings must be reachable"); return }
        app.buttons["openSettings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout:3))
        let collapse = app.switches["collapseLongMessages"]
        XCTAssertEqual(collapse.value as? String,"1")
        // SwiftUI exposes the entire labelled row as Switch; target its visible thumb.
        collapse.coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@", "0"),object:collapse)],timeout:3),.completed)
        capture(app,"Settings")
        app.buttons["settingsDone"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["newChat"].waitForExistence(timeout:8))
        app.buttons["newChat"].tap(); app.waitForConversation()
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout:3))
        XCTAssertEqual(app.switches["collapseLongMessages"].value as? String,"0")
        app.buttons["settingsDone"].tap()
        XCTAssertTrue(app.buttons["conversationOptions"].waitForExistence(timeout:3))
    }
    func testToolSummariesAndNativeIconHeadings() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-polished-tools", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap()
        XCTAssertTrue(app.staticTexts["A0: Responding"].waitForExistence(timeout:8))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@", "icon://")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Search web"].exists)
        capture(app,"Tool summary")
        app.buttons["activityGroup-0"].tap()
        XCTAssertTrue(app.buttons["expandMessage-0"].waitForExistence(timeout:3))
        app.buttons["expandMessage-0"].tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@", "{\"tool_name\"")).firstMatch.exists)
        app.buttons["Details"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Query"].waitForExistence(timeout:3))
        capture(app,"Tool details")
    }
    func testReadingSettingsApplyAndChangingServerKeepsDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-rich-transcript", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        XCTAssertTrue(app.buttons["expandMessage-0"].waitForExistence(timeout:8))
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Retained while changing servers")
        app.buttons["dismissKeyboard"].tap()
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout:3))
        app.switches["collapseLongMessages"].coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        app.buttons["settingsDone"].tap()
        XCTAssertTrue(app.staticTexts["Release notes"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["expandMessage-0"].exists)
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["changeServer"].waitForExistence(timeout:3))
        app.buttons["changeServer"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        app.buttons["changeServer"].tap()
        app.buttons["Disconnect and choose server"].tap()
        XCTAssertTrue(app.buttons["Connect securely"].waitForExistence(timeout:5))
        app.revealConnectionField(app.secureTextFields["Password"])
        app.secureTextFields["Password"].tap(); app.secureTextFields["Password"].typeText("fixture")
        app.buttons["Connect securely"].tap()
        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout:8))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout:5))
        // Reconnecting retains the list offset used to reveal Password. A lazy
        // row may exist behind the navigation bar, so reveal it before tapping.
        for _ in 0..<4 {
            let resume = app.buttons["resumeConversation"]
            if resume.exists, resume.frame.minY > app.navigationBars["Chats"].frame.maxY { break }
            app.collectionViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(app.buttons["resumeConversation"].waitForExistence(timeout:8))
        app.buttons["resumeConversation"].tap(); app.waitForConversation()
        XCTAssertEqual(draft.value as? String,"Retained while changing servers")
    }
    func testAppearanceAndGroupingPreferencesApply() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-polished-tools", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        XCTAssertTrue(app.buttons["activityGroup-0"].waitForExistence(timeout:8))
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout:3))
        app.descendants(matching:.any)["appearancePreference"].firstMatch.tap()
        app.buttons["Light"].tap()
        app.switches["groupActivity"].coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        capture(app,"Settings light appearance")
        app.buttons["settingsDone"].tap()
        XCTAssertTrue(app.buttons["expandMessage-0"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["activityGroup-0"].exists)
        XCTAssertTrue(app.staticTexts["A0: Responding"].exists)
    }
    private func capture(_ app: XCUIApplication,_ name: String) {
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testRichMessageCanExpandCollapseAndCopy() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-rich-transcript", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap()
        XCTAssertTrue(app.buttons["expandMessage-0"].waitForExistence(timeout:8))
        app.buttons["expandMessage-0"].tap()
        XCTAssertTrue(app.staticTexts["Release notes"].waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["## Release notes"].exists)
        capture(app,"Expanded Markdown")
        XCTAssertTrue(app.buttons["copyMessage-0"].exists)
        app.buttons["copyMessage-0"].tap()
        XCTAssertTrue(app.buttons["Copied"].waitForExistence(timeout:3))
        app.buttons["collapseMessage-0"].tap()
        XCTAssertTrue(app.buttons["expandMessage-0"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Agent Zero conversation"; shot.lifetime = .keepAlways; add(shot)
    }
    func testReadingHistoryPausesFollowingUntilLatestIsTapped() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-scroll-transcript", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap()
        XCTAssertTrue(app.buttons["copyMessage-19"].waitForExistence(timeout:8))
        let transcript = app.scrollViews.firstMatch
        transcript.swipeDown(); transcript.swipeDown()
        XCTAssertTrue(app.buttons["jumpToLatest"].waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["Newest update"].waitForExistence(timeout:8))
        app.buttons["jumpToLatest"].tap()
        XCTAssertTrue(app.staticTexts["Newest update"].waitForExistence(timeout:5))
    }

}
