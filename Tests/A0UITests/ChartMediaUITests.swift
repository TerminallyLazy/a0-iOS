import XCTest

@MainActor final class ChartMediaUITests:XCTestCase {
    func launch(_ kind:String,large:Bool = false,extra:[String] = [])->XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-charts-media",kind,"--synthetic-expanded-theme","--persistence-test-id",UUID().uuidString]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchArguments += extra
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:8)); app.buttons["chat-alpha"].tap(); app.waitForConversation()
        return app
    }
    func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        for _ in 0..<12 {
            let top = app.navigationBars.firstMatch.frame.maxY + 40
            let bottom = app.buttons["draftOptions"].frame.minY - 15
            let frame = element.exists ? element.frame : .zero
            if frame.minY > top && frame.maxY < bottom { return }
            let up = frame == .zero || frame.minY >= top
            app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.70:0.30)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.30:0.70)))
        }
    }
    func checkCharts(_ kinds:[String],large:Bool = false) {
        for kind in kinds {
            let app = launch(kind,large:large)
            let values = app.buttons["View values"]
            XCTAssertTrue(values.waitForExistence(timeout:8),kind)
            reveal(values,in:app); values.tap()
            XCTAssertTrue(app.descendants(matching:.any)["chart-value-0"].firstMatch.waitForExistence(timeout:3),kind)
            let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "Chart-" + kind; screenshot.lifetime = .keepAlways; add(screenshot)
            app.terminate()
        }
    }
    func testComparisonAndTrendCharts() { checkCharts(["line","bar","area","horizontalBar","groupedBar","stackedBar","stackedArea"]) }
    func testCompositionAndNumericCharts() { checkCharts(["pie","donut","scatter","bubble","histogram","range","heatmap"]) }
    func testDenseChart() { checkCharts(["denseScatter"]) }
    func testLargeTextChart() { checkCharts(["donut"],large:true) }
    func testAudioAndVideoRequireExplicitLoadingAndStopOnBackground() {
        for kind in ["audio","video"] {
            let app = launch(kind)
            let load = app.buttons["Load " + kind]
            XCTAssertTrue(load.waitForExistence(timeout:8)); reveal(load,in:app)
            XCTAssertFalse(app.buttons["closeGeneratedMedia"].exists)
            load.tap()
            XCTAssertTrue(app.buttons["closeGeneratedMedia"].waitForExistence(timeout:15))
            XCTAssertTrue(app.staticTexts["Ready to play"].waitForExistence(timeout:10))
            let position = app.sliders["Playback position"]
            XCTAssertTrue(position.exists); position.adjust(toNormalizedSliderPosition:0.5)
            let sought = XCTNSPredicateExpectation(predicate:NSPredicate(format:"NOT value BEGINSWITH %@","0:00"),object:position)
            XCTAssertEqual(XCTWaiter.wait(for:[sought],timeout:3),.completed)
            let play = app.buttons["Play media"]
            XCTAssertTrue(play.waitForExistence(timeout:3)); play.tap()
            XCTAssertTrue(app.staticTexts["Playing"].waitForExistence(timeout:3))
            let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Native-" + kind; shot.lifetime = .keepAlways; add(shot)
            XCUIDevice.shared.press(.home); app.activate()
            XCTAssertTrue(load.waitForExistence(timeout:5))
            XCTAssertFalse(app.buttons["closeGeneratedMedia"].exists)
            app.terminate()
        }
    }
    func testMediaFailureAndCancelLeaveUserInControl() {
        var app = launch("audio",extra:["--synthetic-media-invalid"])
        let load = app.buttons["Load audio"]
        XCTAssertTrue(load.waitForExistence(timeout:8)); reveal(load,in:app); load.tap()
        XCTAssertTrue(app.staticTexts["This media couldn’t be played. Check that the link is a supported direct file, then try again."].waitForExistence(timeout:8))
        XCTAssertTrue(load.exists); XCTAssertFalse(app.buttons["closeGeneratedMedia"].exists)
        app.terminate()
        app = launch("video",extra:["--synthetic-media-slow"])
        XCTAssertTrue(app.buttons["Load video"].waitForExistence(timeout:8)); reveal(app.buttons["Load video"],in:app); app.buttons["Load video"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout:3)); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Load video"].waitForExistence(timeout:3))
        let sheet = app.buttons["closeGeneratedMedia"]
        let noSheet = XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true"),object:sheet)
        noSheet.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for:[noSheet],timeout:9),.completed)
    }

}
