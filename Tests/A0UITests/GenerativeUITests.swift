import XCTest

@MainActor final class GenerativeUITests: XCTestCase {
    func app() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview", "--synthetic-chat-selection", "--synthetic-generative-ui", "--persistence-test-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        return app
    }
    func testForecastChartCarouselAndSourceConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-rich-ui","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8)); app.buttons["chat-alpha"].tap()
        XCTAssertTrue(app.staticTexts["Bloomington, Indiana"].waitForExistence(timeout:8))
        reveal(app.staticTexts["Bloomington, Indiana"],in:app,up:false)
        let weather = XCTAttachment(screenshot:app.screenshot()); weather.name = "Generated forecast"; weather.lifetime = .keepAlways; add(weather)
        reveal(app.staticTexts["Afternoon temperature"],in:app)
        XCTAssertTrue(app.staticTexts["Afternoon temperature"].exists)
        reveal(app.buttons["View values"],in:app)
        app.buttons["View values"].tap()
        XCTAssertTrue(app.staticTexts["12 PM"].waitForExistence(timeout:3))
        let chart = XCTAttachment(screenshot:app.screenshot()); chart.name = "Generated chart"; chart.lifetime = .keepAlways; add(chart)
        reveal(app.buttons["Next image"],in:app)
        XCTAssertTrue(app.staticTexts["A lakeside trail"].exists)
        app.buttons["Next image"].tap()
        XCTAssertTrue(app.staticTexts["A tree-lined park"].waitForExistence(timeout:3))
        let carousel = XCTAttachment(screenshot:app.screenshot()); carousel.name = "Generated carousel"; carousel.lifetime = .keepAlways; add(carousel)
        let source = app.descendants(matching:.any)["generatedSource-example.com"].firstMatch
        reveal(source,in:app); source.tap()
        XCTAssertTrue(app.alerts["Open external link?"].waitForExistence(timeout:3))
        app.alerts.buttons["Cancel"].tap()
    }
    private func reveal(_ element:XCUIElement,in app:XCUIApplication,up:Bool = true) {
        for _ in 0..<10 {
            let bottom = app.buttons["draftOptions"].frame.minY - 30
            let top = app.navigationBars.firstMatch.frame.maxY + 90
            if element.exists, element.frame.minY > top, element.frame.maxY < bottom { return }
            let start = app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.65 : 0.32))
            let end = app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.32 : 0.65))
            start.press(forDuration:0.05,thenDragTo:end)
        }
    }
    func testNativeFormReviewCancelAndAppendRetainsDraft() {
        let app = app()
        XCTAssertTrue(app.staticTexts["Plan your afternoon"].waitForExistence(timeout:8))
        let surface = XCTAttachment(screenshot:app.screenshot()); surface.name = "Generated form before editing"; surface.lifetime = .keepAlways; add(surface)
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep my note")
        app.buttons["dismissKeyboard"].tap()
        let field = app.textFields["Destination"]
        XCTAssertTrue(field.waitForExistence(timeout:3))
        field.tap(); field.typeText("Paris")
        app.buttons["hideGeneratedKeyboard"].tap()
        app.buttons["Review choice"].tap()
        XCTAssertTrue(app.navigationBars["Review response"].waitForExistence(timeout:3))
        XCTAssertTrue(app.staticTexts["Paris"].exists)
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Generated action review"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["cancelGeneratedAction"].tap()
        XCTAssertEqual(draft.value as? String,"Keep my note")
        app.buttons["Review choice"].tap()
        app.buttons["addGeneratedAction"].tap()
        XCTAssertTrue((draft.value as? String)?.contains("Keep my note") == true)
        XCTAssertTrue((draft.value as? String)?.contains("Paris") == true)
        XCTAssertTrue((draft.value as? String)?.contains("a2ui-action") == true)
        // No send occurs when choosing or reviewing. The draft remains editable.
        XCTAssertTrue(app.buttons["sendMessage"].isEnabled)
    }
    func testNativeSurfaceAndInstructionsAreReachable() {
        let app = app()
        XCTAssertTrue(app.staticTexts["Plan your afternoon"].waitForExistence(timeout:8))
        XCTAssertTrue(app.textFields["Destination"].exists)
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Native generated form"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        let setup = app.buttons["generativeUISetup"]
        if !setup.isHittable { app.swipeUp() }
        XCTAssertTrue(setup.waitForExistence(timeout:3)); setup.tap()
        XCTAssertTrue(app.buttons["copyGenerativeInstructions"].waitForExistence(timeout:3))
    }
}
