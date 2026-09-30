import XCTest

@MainActor final class PluginUITests:XCTestCase {
    private func launch(extra:[String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-projects","--synthetic-launch-chat","--persistence-test-id",UUID().uuidString]+extra
        app.launch()
        XCTAssertTrue(app.buttons["openSidebar"].waitForExistence(timeout:15)); app.buttons["openSidebar"].tap()
        app.buttons["sidebarPlugins"].tap()
        XCTAssertTrue(app.buttons["plugin-fixture-plugin"].waitForExistence(timeout:8))
        return app
    }
    func testInstalledToggleAndProtectedPlugin() {
        let app = launch()
        capture(app,"Custom plugins with thumbnails")
        XCTAssertFalse(app.buttons["plugin-_fixture_core"].exists)
        app.segmentedControls.buttons["Built-in"].tap()
        XCTAssertFalse(app.buttons["plugin-fixture-plugin"].exists)
        capture(app,"Built-in plugins with thumbnails")
        app.buttons["plugin-_fixture_core"].tap()
        XCTAssertFalse(app.buttons["deletePlugin"].exists)
        XCTAssertFalse(app.buttons["togglePlugin"].exists)
        app.navigationBars["Core Fixture"].buttons.firstMatch.tap()
        app.segmentedControls.buttons["Custom"].tap()
        app.buttons["plugin-fixture-plugin"].tap()
        XCTAssertTrue(app.buttons["togglePlugin"].waitForExistence(timeout:5))
        XCTAssertEqual(app.buttons["togglePlugin"].label,"Deactivate")
        app.buttons["togglePlugin"].tap(); app.sheets.buttons.matching(identifier:"confirmPluginCommand").firstMatch.tap()
        let active = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Activate"),object:app.buttons["togglePlugin"])
        XCTAssertEqual(XCTWaiter.wait(for:[active],timeout:8),.completed)
        capture(app,"Native plugin details and scoped activation")
    }
    func testCardToggleAndFloatingWorkspaceEntry() {
        let app = launch()
        let toggle = app.switches["pluginToggle-fixture-plugin"]
        XCTAssertTrue(toggle.waitForExistence(timeout:5)); XCTAssertTrue(toggle.isEnabled)
        XCTAssertEqual(toggle.value as? String,"1")
        toggle.tap()
        let off = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","0"),object:toggle)
        XCTAssertEqual(XCTWaiter.wait(for:[off],timeout:8),.completed)
        XCTAssertFalse(app.buttons["togglePlugin"].exists,"The card switch must not navigate to details.")
        capture(app,"Plugin card activation switches")
        toggle.tap()
        let on = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","1"),object:toggle)
        XCTAssertEqual(XCTWaiter.wait(for:[on],timeout:8),.completed)
        app.segmentedControls.buttons["Built-in"].tap()
        let protectedToggle = app.switches["pluginToggle-_fixture_core"]
        XCTAssertTrue(protectedToggle.exists); XCTAssertFalse(protectedToggle.isEnabled)
        XCTAssertEqual(protectedToggle.value as? String,"1")
        app.buttons["Done"].tap()
        app.buttons["sidebarClose"].tap()
        let workspace = app.buttons["openWorkspace"]
        XCTAssertTrue(workspace.waitForExistence(timeout:5)); XCTAssertTrue(workspace.isHittable)
        XCTAssertFalse(app.navigationBars.buttons["openWorkspace"].exists)
        capture(app,"Floating Workspace edge tab")
    }
    func testCardToggleUnknownOutcomeBlocksRepeating() {
        let app = launch(extra:["--synthetic-plugin-uncertain"])
        app.switches["pluginToggle-fixture-plugin"].tap()
        XCTAssertTrue(app.buttons["resolvePluginCommand"].waitForExistence(timeout:8))
        let toggle = app.switches["pluginToggle-fixture-plugin"]
        XCTAssertFalse(toggle.isEnabled)
        XCTAssertEqual(toggle.value as? String,"1","Unknown outcomes must not invent an acknowledged state.")
    }
    func testHubInstallSuspensionAndDelete() {
        let app = launch()
        app.segmentedControls.buttons["Plugin Hub"].tap()
        XCTAssertTrue(app.buttons["hub-suspended-fixture"].waitForExistence(timeout:8)); app.buttons["hub-suspended-fixture"].tap()
        XCTAssertFalse(app.buttons["installPlugin"].isEnabled)
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["hub-hub-fixture"].tap()
        app.buttons["installPlugin"].tap(); app.buttons["Install"].tap()
        XCTAssertTrue(app.buttons["Manage installed plugin"].waitForExistence(timeout:8))
        capture(app,"Native Plugin Hub installed details")
        app.buttons["Manage installed plugin"].tap()
        let delete = app.buttons["deletePlugin"]
        XCTAssertTrue(delete.waitForExistence(timeout:5)); delete.tap()
        app.sheets.buttons.matching(identifier:"confirmPluginCommand").firstMatch.tap()
        XCTAssertTrue(app.buttons["installPlugin"].waitForExistence(timeout:8))
    }
    func testHubUpdateRefreshesInstalledCommit() {
        let app = launch()
        app.segmentedControls.buttons["Plugin Hub"].tap()
        XCTAssertTrue(app.buttons["hub-fixture-plugin"].waitForExistence(timeout:8)); app.buttons["hub-fixture-plugin"].tap()
        XCTAssertTrue(app.buttons["updatePlugin"].waitForExistence(timeout:5)); app.buttons["updatePlugin"].tap()
        app.buttons["Update"].tap()
        let updated = XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.buttons["updatePlugin"])
        XCTAssertEqual(XCTWaiter.wait(for:[updated],timeout:8),.completed)
        capture(app,"Plugin Hub update acknowledged and refreshed")
    }
    func testUnknownMutationStaysVisibleAndBlocksRepeating() {
        let app = launch(extra:["--synthetic-plugin-uncertain"])
        app.buttons["plugin-fixture-plugin"].tap()
        XCTAssertTrue(app.buttons["togglePlugin"].waitForExistence(timeout:5))
        app.buttons["togglePlugin"].tap(); app.sheets.buttons.matching(identifier:"confirmPluginCommand").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["pluginCommandNotice"].waitForExistence(timeout:5))
        for _ in 0..<4 where !app.buttons["togglePlugin"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["togglePlugin"].exists)
        XCTAssertFalse(app.buttons["togglePlugin"].isEnabled)
        app.navigationBars.buttons.element(boundBy:0).tap()
        XCTAssertTrue(app.buttons["resolvePluginCommand"].waitForExistence(timeout:5))
        capture(app,"Unconfirmed plugin command")
    }
    func testLargeTextHubAndDetails() {
        let app = launch(extra:["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"])
        capture(app,"Installed plugins at maximum text size")
        app.buttons["plugin-fixture-plugin"].tap()
        let settings = app.buttons["pluginSettings"]
        for _ in 0..<4 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable)
        capture(app,"Plugin details at maximum text size")
        app.navigationBars["Fixture Plugin"].buttons.firstMatch.tap()
        app.buttons["Plugin Hub"].tap()
        XCTAssertTrue(app.buttons["hub-fixture-plugin"].waitForExistence(timeout:8))
        capture(app,"Plugin Hub at maximum text size")
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
