import XCTest

@MainActor final class ModelPresetUITests:XCTestCase {
    func testColdLaunchChoosesPresetBeforeFirstMessage() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-launch-chat","--persistence-test-id",UUID().uuidString]
        app.launch()
        let picker = app.buttons["modelPresetPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout:12)); picker.tap()
        let focused = app.buttons["selectPreset-Focused"]
        XCTAssertTrue(focused.waitForExistence(timeout:5))
        reveal(focused,in:app.scrollViews["modelPresetList"])
        XCTAssertTrue(focused.isEnabled); focused.tap()
        XCTAssertTrue(picker.label.contains("Focused"))
        picker.tap()
        app.buttons["inheritModelPreset"].tap()
        XCTAssertTrue(picker.label.contains("Default"))
        picker.tap(); reveal(focused,in:app.scrollViews["modelPresetList"]); focused.tap()
        capture(app,"Preset chosen before the first message")
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("First message with chosen preset")
        app.buttons["sendMessage"].tap()
        XCTAssertTrue(app.staticTexts["Accepted by server"].waitForExistence(timeout:8))
        picker.tap()
        XCTAssertTrue(app.buttons["inheritModelPreset"].waitForExistence(timeout:5))
        XCTAssertTrue(picker.label.contains("Focused"))
    }
    func testChatPresetSelectionInheritanceAndSharedEditing() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8)); app.buttons["chat-alpha"].tap(); app.waitForConversation()
        let picker = app.buttons["modelPresetPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout:5)); picker.tap()
        XCTAssertTrue(app.buttons["selectPreset-Default"].waitForExistence(timeout:5))
        capture(app,"Model presets and effective models")
        reveal(app.buttons["selectPreset-Focused"],in:app.scrollViews["modelPresetList"])
        app.buttons["selectPreset-Focused"].tap()
        expectation(for:NSPredicate(format:"label CONTAINS %@","Focused"),evaluatedWith:picker)
        waitForExpectations(timeout:5)
        picker.tap()
        app.buttons["inheritModelPreset"].tap()
        expectation(for:NSPredicate(format:"label CONTAINS %@","Default"),evaluatedWith:picker)
        waitForExpectations(timeout:5)
        picker.tap(); app.buttons["editModelPresets"].tap()
        XCTAssertTrue(app.navigationBars["Edit presets"].waitForExistence(timeout:5))
        reveal(app.buttons["editPreset-Focused"],in:app.collectionViews["modelPresetEditorList"])
        app.buttons["editPreset-Focused"].tap()
        let name = app.textFields["modelPresetName"]
        XCTAssertTrue(name.waitForExistence(timeout:3)); name.tap()
        name.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:7)+"Research")
        capture(app,"Shared preset model editor")
        app.navigationBars["Research"].buttons.element(boundBy:0).tap()
        app.buttons["saveModelPresets"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout:5)); picker.tap()
        XCTAssertTrue(app.buttons["selectPreset-Research"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["selectPreset-Focused"].exists)
    }
    func testProviderCatalogChangesModelSuggestionsAndAcceptsCustomID() {
        let app = openDefaultEditor()
        let provider = app.descendants(matching:.any)["preset-chat-provider"].firstMatch
        XCTAssertTrue(provider.waitForExistence(timeout:5)); provider.tap()
        let another = app.buttons["Another Provider"]
        XCTAssertTrue(another.waitForExistence(timeout:3)); another.tap()
        let model = app.descendants(matching:.any)["preset-chat-model"].firstMatch
        XCTAssertTrue(model.waitForExistence(timeout:3))
        XCTAssertTrue(model.label.contains("main-model"),"Changing a provider preserves the explicit model ID until the user chooses another.")
        model.tap()
        XCTAssertTrue(app.buttons["modelOption-another-fast"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["modelOption-main-model"].exists)
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("reasoning")
        XCTAssertTrue(app.buttons["modelOption-another-reasoning"].exists)
        XCTAssertFalse(app.buttons["modelOption-another-fast"].exists)
        capture(app,"Provider-specific searchable models")
        XCUIDevice.shared.orientation = .landscapeLeft
        let wide = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in app.frame.width > app.frame.height },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[wide],timeout:5),.completed)
        capture(app,"Provider-specific searchable models landscape")
        XCUIDevice.shared.orientation = .portrait
        let tall = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in app.frame.height > app.frame.width },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[tall],timeout:5),.completed)
        app.buttons["modelOption-another-reasoning"].tap()
        XCTAssertTrue(model.waitForExistence(timeout:3)); XCTAssertTrue(model.label.contains("another-reasoning"))
        model.tap()
        let custom = app.textFields["customModelID"]
        app.buttons["customModelShortcut"].tap()
        XCTAssertTrue(custom.waitForExistence(timeout:3)); custom.tap()
        custom.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:"another-reasoning".count)+"private/model-id")
        reveal(app.buttons["applyCustomModelID"],in:app.collectionViews["modelNameList"])
        app.buttons["applyCustomModelID"].tap()
        XCTAssertTrue(model.waitForExistence(timeout:3)); XCTAssertTrue(model.label.contains("private/model-id"))
    }
    func testModelSearchFailureCanRetryWithoutChangingSelection() {
        let app = openDefaultEditor(extraArguments:["--synthetic-model-search-retry"])
        let model = app.descendants(matching:.any)["preset-chat-model"].firstMatch
        model.tap()
        XCTAssertTrue(app.staticTexts["modelSearchFailure"].waitForExistence(timeout:5))
        app.buttons["retryModels"].tap()
        XCTAssertTrue(app.buttons["modelOption-utility-model"].waitForExistence(timeout:5))
        app.buttons["modelOption-utility-model"].tap()
        XCTAssertTrue(model.waitForExistence(timeout:3)); XCTAssertTrue(model.label.contains("utility-model"))
    }
    private func openDefaultEditor(extraArguments:[String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--persistence-test-id",UUID().uuidString]+extraArguments
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8)); app.buttons["chat-alpha"].tap(); app.waitForConversation()
        app.buttons["modelPresetPicker"].tap()
        XCTAssertTrue(app.buttons["editModelPresets"].waitForExistence(timeout:5)); app.buttons["editModelPresets"].tap()
        XCTAssertTrue(app.buttons["editPreset-Default"].waitForExistence(timeout:5)); app.buttons["editPreset-Default"].tap()
        reveal(app.descendants(matching:.any)["preset-chat-model"].firstMatch,in:app.collectionViews["modelPresetFields"])
        XCTAssertTrue(app.descendants(matching:.any)["preset-chat-model"].firstMatch.waitForExistence(timeout:5))
        return app
    }
    private func reveal(_ element:XCUIElement,in container:XCUIElement) {
        for _ in 0..<16 {
            if element.exists && element.isHittable && element.frame.midY < container.frame.maxY - 12 && element.frame.midY > container.frame.minY + 8 { return }
            container.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.65)).press(forDuration:0.1,thenDragTo:container.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.4)))
        }
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot = XCTAttachment(screenshot:XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
