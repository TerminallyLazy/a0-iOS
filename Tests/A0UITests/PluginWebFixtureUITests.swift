import XCTest

/// Opt-in disposable HTTPS fixture; a missing fixture is a skip, never a live-server fallback.
@MainActor final class PluginWebFixtureUITests:XCTestCase {
    func testRealWebUISettingsSaveMainActionAndCSRFRejection() async throws {
        let origin = "https://127.0.0.1:18447"
        let app = try await openDetails()
        app.buttons["pluginSettings"].tap()
        let label = app.webViews.textFields["Fixture label"]
        XCTAssertTrue(label.waitForExistence(timeout:65))
        guard label.exists else { capture(app,"Embedded settings failure"); return }
        label.tap(); label.typeText("Saved from iOS")
        let savedValue = try XCTUnwrap(label.value as? String)
        XCTAssertTrue(savedValue.contains("Saved from iOS"))
        capture(app,"Real WebUI plugin settings in native host")
        app.webViews.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["pluginSettings"].waitForExistence(timeout:8))
        app.buttons["pluginSettings"].tap()
        XCTAssertTrue(label.waitForExistence(timeout:65)); XCTAssertEqual(label.value as? String,savedValue)
        close(app)
        app.buttons["openPlugin"].tap()
        let run = app.webViews.buttons["Run fixture action"]
        guard run.waitForExistence(timeout:65) else { XCTFail("Main screen did not open"); capture(app,"Main screen bootstrap failure"); return }; run.tap()
        XCTAssertTrue(app.webViews.staticTexts["Completed actions: 1"].waitForExistence(timeout:8))
        capture(app,"Real WebUI interactive plugin main screen")
        app.webViews.buttons["Reject fixture request"].tap()
        XCTAssertTrue(app.staticTexts["Plugin screen unavailable"].waitForExistence(timeout:8))
        capture(app,"Rejected embedded request without automatic retry")
        let (counts,_) = try await URLSession.shared.data(from:URL(string:origin+"/fixture/counts")!)
        let counters = try XCTUnwrap(JSONSerialization.jsonObject(with:counts) as? [String:Int])
        XCTAssertEqual(counters["actions"],1); XCTAssertEqual(counters["rejections"],1)
        XCTAssertEqual(counters["root_documents"],0,"Embedded plugins must never bootstrap the document-replacing splash.")
        XCTAssertGreaterThanOrEqual(counters["direct_documents"] ?? 0,3)
        close(app)
        app.buttons["openPlugin"].tap()
        guard run.waitForExistence(timeout:65) else { XCTFail("Main screen did not reopen"); return }
        app.webViews.buttons["Open fixture panel"].tap()
        let handoff = app.webViews.buttons["Use Plugin Panel"].firstMatch
        XCTAssertTrue(handoff.waitForExistence(timeout:15)); handoff.tap()
        XCTAssertTrue(app.webViews.staticTexts["Completed interactions: 1"].firstMatch.waitForExistence(timeout:5))
        capture(app,"Plugin modal hands off to registered surface")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Plugin screen closed"].waitForExistence(timeout:8))
        XCTAssertFalse(run.exists)
        capture(app,"Embedded plugin cleared after background")
    }
    func testUnexpectedTunnelDocumentShowsRecoveryAndCanReopen() async throws {
        let app = try await openDetails()
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/interstitial/on")!)
        app.buttons["pluginSettings"].tap()
        XCTAssertTrue(app.staticTexts["Plugin screen unavailable"].waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","tunnel notice")).firstMatch.exists)
        capture(app,"Unexpected tunnel document shows native recovery")
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/interstitial/off")!)
        close(app)
        app.buttons["pluginSettings"].tap()
        XCTAssertTrue(app.webViews.textFields["Fixture label"].waitForExistence(timeout:65))
        close(app)
        app.buttons["openPlugin"].tap()
        let replace = app.webViews.buttons["Replace fixture document"]
        XCTAssertTrue(replace.waitForExistence(timeout:65)); replace.tap()
        XCTAssertTrue(app.staticTexts["Plugin screen unavailable"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","replaced its WebUI page")).firstMatch.exists)
    }
    func testWorkspaceRegisteredToolsAndEmbeddedFrame() async throws {
        let app = try await connectFixture()
        let greeting = app.staticTexts["What would you like to do?"]
        XCTAssertTrue(greeting.waitForExistence(timeout:10))
        XCTAssertEqual(greeting.frame.midX,app.frame.midX,accuracy:2,"The empty-chat branding must remain centered.")
        let tab = app.buttons["openWorkspace"]
        XCTAssertEqual(tab.frame.maxX,app.frame.maxX,accuracy:1)
        let initialY = tab.frame.midY
        let start = tab.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:0,dy:-100)))
        XCTAssertLessThan(tab.frame.midY,initialY - 60)
        XCTAssertFalse(app.buttons["closePluginScreen"].exists,"Dragging must not open the Workspace.")
        let movedY = tab.frame.midY
        app.buttons["openSidebar"].tap()
        XCTAssertFalse(tab.exists)
        app.buttons["sidebarClose"].tap()
        XCTAssertEqual(tab.frame.midY,movedY,accuracy:2,"Reopening the drawer must preserve the tab position.")
        capture(app,"Centered chat with draggable A0 edge tab")
        tab.tap()
        let files = app.webViews.buttons["File Browser"]
        guard files.waitForExistence(timeout:65) else { XCTFail("Workspace did not initialize"); capture(app,"Workspace initialization"); return }
        capture(app,"Registered Workspace tools")
        files.tap()
        XCTAssertTrue(app.webViews.staticTexts["workspace-note.md"].waitForExistence(timeout:20))
        capture(app,"Original File Browser in Workspace")
        app.webViews.buttons["Download file"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","Copy")).firstMatch.waitForExistence(timeout:10))
        capture(app,"Workspace file export uses iOS share sheet")
        app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","Copy")).firstMatch.tap()
        XCTAssertTrue(app.webViews.staticTexts["workspace-note.md"].waitForExistence(timeout:10))
        // All widths use the real docked panels, including plugins with no modalPath.
        let back = app.webViews.buttons["Back to tools"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout:5)); back.tap()
        for title in ["Browser","Desktop","Editor","Plugin Panel","Swarm"] {
            let choice = app.webViews.buttons.matching(NSPredicate(format:"label == %@",title)).firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout:10)); choice.tap()
            let action = app.webViews.buttons["Use " + title].firstMatch
            XCTAssertTrue(action.waitForExistence(timeout:15)); action.tap()
            XCTAssertTrue(app.webViews.staticTexts["Completed interactions: 1"].firstMatch.waitForExistence(timeout:5))
            if title == "Desktop" {
                let frameAction = app.webViews.buttons["Desktop frame action"].firstMatch
                XCTAssertTrue(frameAction.waitForExistence(timeout:10)); frameAction.tap()
                XCTAssertTrue(app.webViews.buttons["Desktop input received"].firstMatch.waitForExistence(timeout:5))
            }
            capture(app,"Workspace " + title)
            XCTAssertTrue(back.waitForExistence(timeout:5)); back.tap()
        }
        app.webViews.buttons["Chat-required tool"].tap()
        XCTAssertTrue(app.webViews.staticTexts["This tool cannot open here. Select an existing chat if the tool requires one."].waitForExistence(timeout:5))
        XCTAssertTrue(files.isHittable,"The host must preserve genuine surface eligibility restrictions.")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.staticTexts["Workspace closed"].waitForExistence(timeout:8))
    }
    func testNativeServerThemeSyncAndFallback() async throws {
        let app = try await connectFixture()
        func setTheme(_ value:String) async throws {
            _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/theme/"+value)!)
        }
        func settings() {
            let opener = app.buttons["openSidebar"]
            XCTAssertTrue(opener.waitForExistence(timeout:10))
            opener.tap()
            XCTAssertTrue(app.buttons["sidebarClose"].waitForExistence(timeout:8))
            XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout:8));app.buttons["Settings"].tap()
            XCTAssertTrue(app.switches["matchServerTheme"].waitForExistence(timeout:5))
        }
        func closeSettings() {
            app.buttons["settingsDone"].tap();app.buttons["sidebarClose"].tap()
        }
        func matches(_ text:String) {
            let status = app.staticTexts["serverThemeStatus"]
            let predicate = NSPredicate(format:"label CONTAINS %@",text)
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:predicate,object:status)],timeout:20),.completed)
        }
        func appearance(_ mode:String) {
            app.descendants(matching:.any)["appearancePreference"].firstMatch.tap()
            app.buttons[mode].tap()
        }
        try await setTheme("ocean");settings()
        app.buttons["Refresh server theme"].tap();matches("Matching Ocean")
        appearance("Dark")
        capture(app,"Native Ocean theme settings")
        closeSettings()
        assertBackground(app,expected:[7,28,40])
        capture(app,"Native Ocean dark chat and attached tab")
        settings();appearance("Light");closeSettings()
        assertBackground(app,expected:[245,252,255])
        capture(app,"Native Ocean light chat")
        settings();appearance("Dark")
        app.switches["matchServerTheme"].coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap();matches("default colors")
        closeSettings();assertBackground(app,expected:[33,33,33])
        settings();app.switches["matchServerTheme"].coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap();matches("Matching Ocean")
        closeSettings()
        // Saving a theme in an embedded screen triggers a fresh read upon dismissal.
        app.buttons["openSidebar"].tap();app.buttons["sidebarPlugins"].tap()
        app.buttons["plugin-fixture-plugin"].tap();app.buttons["pluginSettings"].tap()
        XCTAssertTrue(app.webViews.textFields["Fixture label"].waitForExistence(timeout:65))
        try await setTheme("custom")
        close(app)
        app.navigationBars["Fixture Plugin"].buttons.firstMatch.tap()
        app.buttons["Done"].tap();app.buttons["sidebarClose"].tap()
        settings();matches("Matching Fixture Violet")
        capture(app,"Custom CSS colors in native settings")
        closeSettings()
        capture(app,"Custom native gradient chat")
        let upper = backgroundPixel(app,y:0.48),lower = backgroundPixel(app,y:0.65)
        XCTAssertNotEqual(upper,lower,"The custom gradient must render natively.")
        // Foreground refresh reads external changes without reopening plugin settings.
        try await setTheme("disabled")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for:.runningBackground,timeout:5))
        app.activate()
        let restored = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true AND hittable == true"),object:app.buttons["openWorkspace"])
        XCTAssertEqual(XCTWaiter.wait(for:[restored],timeout:15),.completed)
        settings();matches("disabled")
        closeSettings();assertBackground(app,expected:[33,33,33])
        settings()
        for mode in ["invalid","missing"] {
            try await setTheme(mode);app.buttons["Refresh server theme"].tap();matches("unavailable")
        }
        capture(app,"Unavailable theme falls back to native colors")
        try await setTheme("disabled")
    }
    func testNativeThemeLightToolbarContrast() async throws {
        let app = try await connectFixture()
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/theme/ocean")!)
        app.buttons["openSidebar"].tap();app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["matchServerTheme"].waitForExistence(timeout:5))
        app.buttons["Refresh server theme"].tap()
        let matched = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","Matching Ocean"),object:app.staticTexts["serverThemeStatus"])
        XCTAssertEqual(XCTWaiter.wait(for:[matched],timeout:20),.completed)
        capture(app,"Native themed settings contrast")
        app.descendants(matching:.any)["appearancePreference"].firstMatch.tap();app.buttons["Light"].tap()
        app.buttons["settingsDone"].tap();app.buttons["sidebarClose"].tap()
        capture(app,"Light theme toolbar contrast")
        let button = app.buttons["conversationOptions"].frame
        let pixel = backgroundPixel(app,x:button.midX/app.frame.width,y:button.midY/app.frame.height)
        XCTAssertEqual(pixel.count,3)
        func luminance(_ rgb:[UInt8])->Double {
            let linear = rgb.map { value -> Double in
                let c = Double(value)/255;return c <= 0.04045 ? c/12.92:pow((c+0.055)/1.055,2.4)
            }
            return zip(linear,[0.2126,0.7152,0.0722]).reduce(0) { $0+$1.0*$1.1 }
        }
        XCTAssertGreaterThan((luminance([231,244,248])+0.05)/(luminance(pixel)+0.05),4.5,"The ellipsis must remain readable against the light navigation bar.")
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/theme/disabled")!)
    }
    func testPluginHubThemeCoverage() async throws {
        let app = try await connectFixture()
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/theme/ocean")!)
        for (mode,panel,input) in [("Dark",[11,38,53],[18,48,66]),("Light",[231,244,248],[217,237,244])] {
            app.buttons["openSidebar"].tap();app.buttons["Settings"].tap()
            XCTAssertTrue(app.switches["matchServerTheme"].waitForExistence(timeout:5))
            app.buttons["Refresh server theme"].tap()
            let matched = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","Matching Ocean"),object:app.staticTexts["serverThemeStatus"])
            XCTAssertEqual(XCTWaiter.wait(for:[matched],timeout:20),.completed)
            app.descendants(matching:.any)["appearancePreference"].firstMatch.tap();app.buttons[mode].tap()
            capture(app,mode+" themed settings controls")
            app.buttons["settingsDone"].tap()
            app.buttons["sidebarPlugins"].tap()
            XCTAssertTrue(app.buttons["plugin-fixture-plugin"].waitForExistence(timeout:10))
            app.segmentedControls.buttons["Plugin Hub"].tap()
            XCTAssertTrue(app.buttons["hub-fixture-plugin"].waitForExistence(timeout:10))
            let segments = app.segmentedControls["pluginCollection"].frame
            let rowPixel = backgroundPixel(app,x:(segments.minX-5)/app.frame.width,y:segments.midY/app.frame.height)
            for (actual,expected) in zip(rowPixel,panel) { XCTAssertEqual(Int(actual),expected,accuracy:3,"Collection row must use the panel color.") }
            let search = app.textFields["pluginSearch"]
            XCTAssertTrue(search.isHittable)
            let field = search.frame
            let searchPixel = backgroundPixel(app,x:field.midX/app.frame.width,y:(field.minY-3)/app.frame.height)
            for (actual,expected) in zip(searchPixel,input) { XCTAssertEqual(Int(actual),expected,accuracy:3,"Search field must use the input color.") }
            capture(app,mode+" themed Plugin Hub controls")
            search.tap();search.typeText("no-match")
            XCTAssertTrue(app.staticTexts["No Hub plugins to show"].waitForExistence(timeout:5))
            app.buttons["Clear search"].tap()
            XCTAssertTrue(app.buttons["hub-fixture-plugin"].waitForExistence(timeout:5))
            app.buttons["Done"].tap();app.buttons["sidebarClose"].tap()
        }
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/theme/disabled")!)
    }
    func testSettingsSheetSafeAreaUsesTheme() async throws {
        let app = try await connectFixture()
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/theme/ocean")!)
        app.buttons["openSidebar"].tap();app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["matchServerTheme"].waitForExistence(timeout:5))
        app.buttons["Refresh server theme"].tap()
        let matched = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","Matching Ocean"),object:app.staticTexts["serverThemeStatus"])
        XCTAssertEqual(XCTWaiter.wait(for:[matched],timeout:20),.completed)
        for (mode,canvas) in [("Dark",[7,28,40]),("Light",[245,252,255])] {
            let appearance = app.descendants(matching:.any)["appearancePreference"].firstMatch
            for _ in 0..<5 where !appearance.isHittable { app.swipeDown() }
            appearance.tap();app.buttons[mode].tap()
            app.swipeUp();app.swipeUp()
            XCTAssertTrue(app.buttons["Acknowledgments"].isHittable)
            // Below the Form, inside the sheet's bottom safe area and away from the home indicator.
            let pixel = backgroundPixel(app,x:0.2,y:0.98)
            XCTAssertEqual(pixel.count,3)
            for (actual,expected) in zip(pixel,canvas) { XCTAssertEqual(Int(actual),expected,accuracy:3,"Sheet safe-area background must follow the theme.") }
            capture(app,mode+" Settings bottom safe area")
        }
        _ = try await URLSession.shared.data(from:URL(string:"https://127.0.0.1:18447/fixture/theme/disabled")!)
    }
    private func backgroundPixel(_ app:XCUIApplication,x:Double = 0.5,y:Double = 0.6)->[UInt8] {
        guard let image = app.screenshot().image.cgImage,
              let pixel = image.cropping(to:CGRect(x:Double(image.width)*x,y:Double(image.height)*y,width:1,height:1)) else { XCTFail("Missing screenshot");return [] }
        var bytes = [UInt8](repeating:0,count:4)
        let context = CGContext(data:&bytes,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(pixel,in:CGRect(x:0,y:0,width:1,height:1))
        return Array(bytes.prefix(3))
    }
    private func assertBackground(_ app:XCUIApplication,expected:[UInt8],file:StaticString = #filePath,line:UInt = #line) {
        let actual = backgroundPixel(app)
        XCTAssertEqual(actual.count,3,file:file,line:line)
        for (a,b) in zip(actual,expected) { XCTAssertEqual(Int(a),Int(b),accuracy:3,file:file,line:line) }
    }
    private func openDetails() async throws -> XCUIApplication {
        let app = try await connectFixture()
        app.buttons["openSidebar"].tap(); app.buttons["sidebarPlugins"].tap()
        XCTAssertTrue(app.buttons["plugin-fixture-plugin"].waitForExistence(timeout:10)); app.buttons["plugin-fixture-plugin"].tap()
        return app
    }
    private func connectFixture() async throws -> XCUIApplication {
        let origin = "https://127.0.0.1:18447"
        let identity:Data
        do { (identity,_) = try await URLSession.shared.data(from:URL(string:origin+"/fixture/identity")!) }
        catch { throw XCTSkip("Start Tests/plugin_web_fixture.py with its disposable trusted simulator certificate to run this test.") }
        try XCTSkipUnless(String(decoding:identity,as:UTF8.self).contains("a0-plugin-web-fixture-v1"),"Only the disposable fixture is allowed.")
        let app = XCUIApplication()
        app.launchArguments = ["--loopback-probe",origin,"--persistence-test-id",UUID().uuidString]
        app.launch()
        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout:10)); app.revealConnectionField(username); username.tap(); username.typeText("fixture")
        let password = app.secureTextFields["Password"]
        app.revealConnectionField(password); password.tap(); password.typeText("fixture")
        app.buttons["connectServer"].tap()
        XCTAssertTrue(app.buttons["openSidebar"].waitForExistence(timeout:15))
        return app
    }
    private func close(_ app:XCUIApplication) {
        app.buttons["closePluginScreen"].tap(); app.buttons["Close screen"].tap()
        XCTAssertTrue(app.buttons["pluginSettings"].waitForExistence(timeout:5))
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
