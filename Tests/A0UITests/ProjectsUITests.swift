import XCTest

@MainActor final class ProjectsUITests:XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-projects","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
        return app
    }
    func testCompactHeadersProjectFilterAndAssignment() {
        let app = launch()
        XCTAssertLessThan(app.navigationBars["Chats"].frame.height,100)
        capture(app,"Compact chats with project colors")
        app.buttons["projectChatFilter"].tap(); app.buttons["Research"].tap()
        XCTAssertTrue(app.buttons["chat-alpha"].exists)
        XCTAssertFalse(app.buttons["chat-beta"].exists)
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        XCTAssertTrue(app.buttons["conversationProject"].label.contains("Research"))
        app.buttons["conversationProject"].tap()
        XCTAssertTrue(app.buttons["project-workshop"].waitForExistence(timeout:5))
        capture(app,"Projects")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["project-workshop"].waitForExistence(timeout:8))
        app.buttons["project-workshop"].tap()
        app.buttons["activateProject"].tap()
        XCTAssertTrue(app.buttons["deactivateProject"].waitForExistence(timeout:5))
        capture(app,"Assigned project")
        app.buttons["deactivateProject"].tap()
        let removed = NSPredicate(format:"exists == false")
        expectation(for:removed,evaluatedWith:app.buttons["deactivateProject"])
        waitForExpectations(timeout:5)
        app.navigationBars["Project"].buttons.element(boundBy:0).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["conversationProject"].label.contains("No project"))
        app.navigationBars["chat-alpha"].buttons.element(boundBy:0).tap()
        XCTAssertTrue(app.buttons["chat-beta"].waitForExistence(timeout:5))
    }
    func testCreateEditAndDeleteProject() {
        let app = launch()
        app.buttons["openProjects"].tap()
        XCTAssertTrue(app.buttons["addProject"].waitForExistence(timeout:5))
        app.buttons["addProject"].tap(); app.buttons["New project"].tap()
        let title = app.textFields["projectTitle"]
        XCTAssertTrue(title.waitForExistence(timeout:3)); title.tap(); title.typeText("Field Notes")
        let name = app.textFields["projectName"]; name.tap(); name.typeText("field-notes")
        app.buttons["saveProject"].tap()
        XCTAssertTrue(app.buttons["project-field-notes"].waitForExistence(timeout:5))
        app.buttons["project-field-notes"].tap()
        reveal(app.buttons["editProject"],in:app)
        XCTAssertTrue(app.buttons["editProject"].waitForExistence(timeout:3)); app.buttons["editProject"].tap()
        XCTAssertTrue(app.textFields["projectTitle"].waitForExistence(timeout:3))
        reveal(app.buttons["Project color #7b2cbf"],in:app)
        capture(app,"Before choosing project color")
        app.buttons["Project color #7b2cbf"].tap()
        capture(app,"Project editor and native palette")
        app.buttons["saveProject"].tap()
        XCTAssertTrue(app.buttons["editProject"].waitForExistence(timeout:5))
        // Empty server MCP settings must not prevent an unrelated color edit.
        reveal(app.buttons["deleteProject"],in:app)
        app.buttons["deleteProject"].tap()
        XCTAssertTrue(app.buttons["confirmDeleteProject"].waitForExistence(timeout:3))
        XCTAssertFalse(app.buttons["confirmDeleteProject"].isEnabled)
        reveal(app.textFields["deleteProjectName"],in:app)
        capture(app,"Delete project confirmation and pinned action")
        app.textFields["deleteProjectName"].tap(); app.textFields["deleteProjectName"].typeText("field-notes")
        app.buttons["confirmDeleteProject"].tap()
        XCTAssertTrue(app.buttons["addProject"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["project-field-notes"].exists)
    }
    func testNewChatRetainsProjectBeforeFirstMessage() {
        let app = launch()
        app.buttons["openProjects"].tap()
        XCTAssertTrue(app.buttons["project-research"].waitForExistence(timeout:5)); app.buttons["project-research"].tap()
        app.buttons["newProjectChat"].tap()
        app.waitForConversation()
        let assigned = NSPredicate(format:"label CONTAINS %@", "Research")
        expectation(for:assigned,evaluatedWith:app.buttons["conversationProject"])
        waitForExpectations(timeout:8)
        capture(app,"New chat inside Research")
    }
    private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        let container = app.collectionViews.element(boundBy:max(0,app.collectionViews.count-1))
        for _ in 0..<16 {
            if element.exists {
                let save = app.buttons["saveProject"]
                let confirm = app.buttons["confirmDeleteProject"]
                let bottom = save.exists ? save.frame.minY : confirm.exists ? confirm.frame.minY : container.frame.maxY
                if element.isHittable && element.frame.midY > container.frame.minY + 8 && element.frame.midY < bottom - 8 { return }
            }
            container.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.65)).press(forDuration:0.1,thenDragTo:container.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.4)))
        }
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let screenshot = app.screenshot()
        #if targetEnvironment(simulator)
        let output = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent(name+".png")
        try? screenshot.pngRepresentation.write(to:output)
        #endif
        let shot = XCTAttachment(screenshot:screenshot); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
