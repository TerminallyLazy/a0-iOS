import XCTest

@MainActor final class ModelPresetUITests:XCTestCase {
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
    private func reveal(_ element:XCUIElement,in container:XCUIElement) {
        for _ in 0..<16 {
            if element.exists && element.isHittable && element.frame.midY < container.frame.maxY - 12 && element.frame.midY > container.frame.minY + 8 { return }
            container.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.65)).press(forDuration:0.1,thenDragTo:container.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.4)))
        }
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
