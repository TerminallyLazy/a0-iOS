import XCTest

@MainActor final class JevUITests: XCTestCase {
    func testSecureSettingsSaveEnableReplaceRemove() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        let setup = app.buttons["generativeUISetup"]
        if !setup.isHittable { app.swipeUp() }
        setup.tap()
        let field = app.secureTextFields["jevAPIKey"]
        for _ in 0..<5 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout:3))
        field.tap(); field.typeText("synthetic-ui-key")
        app.buttons["jevSaveKey"].tap()
        XCTAssertTrue(app.staticTexts["Key saved on this device"].waitForExistence(timeout:3))
        XCTAssertEqual(app.switches["jevEnabled"].value as? String,"0")
        app.switches["jevEnabled"].tap()
        XCTAssertEqual(app.switches["jevEnabled"].value as? String,"1")
        field.tap(); field.typeText("replacement")
        app.buttons["jevSaveKey"].tap()
        XCTAssertEqual(app.switches["jevEnabled"].value as? String,"0")
        app.buttons["jevRemoveKey"].tap()
        XCTAssertTrue(app.staticTexts["No key saved"].waitForExistence(timeout:3))
        XCTAssertFalse(app.switches["jevEnabled"].isEnabled)
        let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "Jev settings without credentials"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}

extension JevUITests {
    private func configured(_ extra:[String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-jev","--persistence-test-id",UUID().uuidString] + extra
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10)); app.buttons["chat-alpha"].tap(); app.waitForConversation()
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        let setup = app.buttons["generativeUISetup"]; if !setup.isHittable { app.swipeUp() }; setup.tap()
        let key = app.secureTextFields["jevAPIKey"]; XCTAssertTrue(key.waitForExistence(timeout:5))
        key.tap(); key.typeText("synthetic-ui-key"); app.buttons["jevSaveKey"].tap()
        XCTAssertTrue(app.staticTexts["Key saved on this device"].waitForExistence(timeout:3))
        app.switches["jevEnabled"].tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["settingsDone"].tap()
        return app
    }
    func testNewReplyChoosesExpandedSurfaceAndChecklistReviewKeepsDraft() {
        let app = configured()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Show a helpful overview")
        app.buttons["sendMessage"].tap()
        guard app.staticTexts["Open tasks"].waitForExistence(timeout:15) else { XCTFail("New Jev candidate reply was not rendered"); return }
        reveal(app.staticTexts["Afternoon options"],app)
        XCTAssertTrue(app.staticTexts["Afternoon options"].exists)
        let catalog = XCTAttachment(screenshot:app.screenshot()); catalog.name = "Expanded native catalog"; catalog.lifetime = .keepAlways; add(catalog)
        reveal(app.staticTexts["Your afternoon"],app)
        XCTAssertTrue(app.staticTexts["Your afternoon"].exists)
        reveal(app.switches["Pack your bag"],app)
        app.switches["Pack your bag"].tap()
        reveal(app.buttons["Review checklist"],app)
        app.buttons["Review checklist"].tap()
        XCTAssertTrue(app.navigationBars["Review response"].waitForExistence(timeout:3))
        app.buttons["addGeneratedAction"].tap()
        XCTAssertTrue((draft.value as? String)?.contains("packed") == true)
        XCTAssertTrue((draft.value as? String)?.contains("true") == true)
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Native checklist reviewed into draft"; shot.lifetime = .keepAlways; add(shot)
    }
    func testUnavailableJevRetainsReadableProse() {
        let app = configured(["--synthetic-jev-failure"])
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Show a helpful overview"); app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Your readable overview is ready."].waitForExistence(timeout:15))
        XCTAssertFalse(app.staticTexts["Open tasks"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","a2ui-candidates")).firstMatch.exists)
    }
    func testExpandedCatalogAtAccessibilitySizeWithServerTheme() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-expanded-ui","--persistence-test-id",UUID().uuidString,"-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10)); app.buttons["chat-alpha"].tap(); app.waitForConversation()
        XCTAssertTrue(app.staticTexts["Open tasks"].waitForExistence(timeout:10))
        reveal(app.staticTexts["Row 1"],app)
        XCTAssertTrue(app.staticTexts["Row 1"].exists)
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Expanded catalog accessibility server theme"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        let status = app.staticTexts["serverThemeStatus"]
        let matching = NSPredicate(format:"label CONTAINS %@","Matching Catalog Ocean")
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:matching,object:status)],timeout:15),.completed)
    }
    private func reveal(_ element:XCUIElement,_ app:XCUIApplication) {
        for _ in 0..<12 {
            let bottom = app.buttons["draftOptions"].frame.minY - 20
            let top = app.navigationBars.firstMatch.frame.maxY + 60
            let frame = element.exists ? element.frame : .zero
            if frame.minY > top && frame.maxY < bottom { return }
            let up = frame == .zero || frame.minY >= top
            app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.67 : 0.32)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.32 : 0.67)))
        }
    }
}
