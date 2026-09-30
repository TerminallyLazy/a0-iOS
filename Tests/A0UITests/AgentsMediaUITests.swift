import XCTest
import UIKit

@MainActor final class AgentsMediaUITests:XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func launch(_ flags:[String],large:Bool = false)->XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-expanded-theme","--persistence-test-id",UUID().uuidString] + flags
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        return app
    }
    func testPlainReplyOffersExplicitAudioAndVideoLoading() {
        let app = launch(["--synthetic-charts-media","audio","--synthetic-direct-media"])
        let audio = app.buttons["Load audio"], video = app.buttons["Load video"]
        XCTAssertTrue(audio.waitForExistence(timeout:8)); XCTAssertTrue(video.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","Both source links remain readable")).firstMatch.exists)
        XCTAssertFalse(app.buttons["closeGeneratedMedia"].exists)
        XCTAssertFalse(app.staticTexts["Ready to play"].exists)
        capture(app,"Plain response direct media cards")
        reveal(audio,in:app); audio.tap()
        XCTAssertTrue(app.buttons["unloadGeneratedAudio"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Ready to play"].waitForExistence(timeout:8))
        reveal(app.buttons["unloadGeneratedAudio"],in:app); app.buttons["unloadGeneratedAudio"].tap()
        reveal(video,in:app); video.tap()
        XCTAssertTrue(app.buttons["unloadGeneratedVideo"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Ready to play"].waitForExistence(timeout:8))
        capture(app,"Plain response native video")
    }
    func testReadOnlyAgentsStillAllowsExplicitMediaLoading() {
        let app = launch(["--synthetic-charts-media","audio","--synthetic-readonly-media"])
        app.buttons["agentActivity"].tap()
        let disclosure = app.buttons["agentDetails-1"]
        XCTAssertTrue(disclosure.waitForExistence(timeout:5)); disclosure.tap()
        let loads = app.buttons.matching(identifier:"Load audio")
        XCTAssertTrue(loads.firstMatch.waitForExistence(timeout:5))
        let load = loads.element(boundBy:loads.count-1)
        XCTAssertTrue(load.isEnabled)
        let actions = app.buttons.matching(identifier:"Review fixture action")
        XCTAssertTrue(actions.firstMatch.waitForExistence(timeout:5))
        XCTAssertFalse(actions.element(boundBy:actions.count-1).isEnabled)
        load.tap()
        XCTAssertTrue(app.buttons["unloadGeneratedAudio"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Ready to play"].waitForExistence(timeout:8))
        capture(app,"Read-only Agents native audio")
    }
    func testInlinePlaybackHandsOffWithoutUnloadingOtherCards() {
        let app = launch(["--synthetic-charts-media","audio","--synthetic-direct-media","--synthetic-media-handoff"])
        let audio = app.buttons["Load audio"], video = app.buttons["Load video"]
        XCTAssertTrue(audio.waitForExistence(timeout:8)); reveal(audio,in:app); audio.tap()
        let playAudio = app.buttons["playGeneratedAudio"], playVideo = app.buttons["playGeneratedVideo"]
        XCTAssertTrue(playAudio.waitForExistence(timeout:10))
        reveal(video,in:app); video.tap()
        XCTAssertTrue(playVideo.waitForExistence(timeout:10))
        reveal(playAudio,in:app); playAudio.tap()
        XCTAssertEqual(playAudio.label,"Pause media")
        reveal(playVideo,in:app); playVideo.tap()
        let transferred = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Pause media"),object:playVideo)
        XCTAssertEqual(XCTWaiter.wait(for:[transferred],timeout:5),.completed)
        XCTAssertEqual(playAudio.label,"Play media","Starting video must pause the previous inline audio.")
        let unloadAudio = app.buttons["unloadGeneratedAudio"]
        reveal(unloadAudio,in:app); unloadAudio.tap()
        XCTAssertEqual(playVideo.label,"Pause media","Unloading an older card must not stop the active player.")
        XCTAssertTrue(app.descendants(matching:.any)["messageDraft"].firstMatch.isHittable)
        capture(app,"Inline media playback handoff")
    }
    func testInlinePlaybackAndDictationShareAudioOwnership() {
        let app = launch(["--synthetic-charts-media","audio","--synthetic-voice-input","--synthetic-voice-edit","--synthetic-media-handoff"])
        let load = app.buttons["Load audio"]
        XCTAssertTrue(load.waitForExistence(timeout:8)); reveal(load,in:app); load.tap()
        let play = app.buttons["playGeneratedAudio"]
        XCTAssertTrue(play.waitForExistence(timeout:10)); reveal(play,in:app); play.tap()
        XCTAssertEqual(play.label,"Pause media")
        app.buttons["voiceControls"].tap()
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        let dictated = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","weather"),object:draft)
        XCTAssertEqual(XCTWaiter.wait(for:[dictated],timeout:5),.completed)
        XCTAssertEqual(play.label,"Play media","Starting dictation must pause the inline player.")
        reveal(play,in:app); play.tap()
        XCTAssertEqual(play.label,"Pause media")
        XCTAssertEqual(app.buttons["voiceControls"].value as? String,"Stopped","Explicit playback must stop prior dictation.")
        XCTAssertEqual(draft.value as? String,"weather","Audio handoff preserves the existing draft.")
    }
    func testAgentsSheetChromeUsesServerTheme() {
        let app = launch(["--synthetic-agent-work"])
        app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
        let matched = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","Matching Catalog Ocean"),object:app.staticTexts["serverThemeStatus"])
        XCTAssertEqual(XCTWaiter.wait(for:[matched],timeout:15),.completed)
        app.buttons["Done"].tap()
        app.buttons["agentActivity"].tap()
        let nav = app.navigationBars["Agents"]
        XCTAssertTrue(nav.waitForExistence(timeout:5))
        let header = sample(app,point:CGPoint(x:nav.frame.minX+15,y:nav.frame.midY))
        let dark = [16,39,55], light = [237,248,255]
        XCTAssertTrue(matches(header,dark) || matches(header,light),"Agents header must use a server panel color: \(header)")
        if UIDevice.current.userInterfaceIdiom == .phone {
            let bottom = sample(app,point:CGPoint(x:app.frame.width*0.2,y:app.frame.maxY-8))
            XCTAssertTrue(matches(bottom,[7,28,40]) || matches(bottom,[217,237,249]),"Agents bottom safe area must use server background: \(bottom)")
        }
        capture(app,"Agents themed header and safe area")
    }
    func testNewSubagentDiscoveryPreservesParentDraftAndAttachment() {
        let app = launch(["--synthetic-agent-team","--synthetic-attachments"])
        let team = app.buttons["agentTeam"]
        XCTAssertTrue(team.waitForExistence(timeout:5))
        let draft = app.descendants(matching:.any)["messageDraft"].firstMatch
        draft.tap(); draft.typeText("Keep my parent draft"); app.buttons["dismissKeyboard"].tap()
        app.buttons["chatTools"].tap(); app.buttons["attachFiles"].tap()
        let sampleFile = app.buttons["attachSyntheticFile"].firstMatch
        XCTAssertTrue(sampleFile.waitForExistence(timeout:5)); sampleFile.tap()
        XCTAssertTrue(app.staticTexts["sample.txt"].waitForExistence(timeout:5))
        XCTAssertTrue(app.descendants(matching:.any)["agentTeamNew"].firstMatch.waitForExistence(timeout:20))
        XCTAssertEqual(draft.value as? String,"Keep my parent draft")
        team.tap()
        let child = app.buttons["agentConversation-chat-new"]
        XCTAssertTrue(child.waitForExistence(timeout:5))
        capture(app,"Related conversations with new child")
        child.tap()
        XCTAssertTrue(app.buttons["parentConversation"].waitForExistence(timeout:8))
        let parentReady = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:app.buttons["parentConversation"])
        XCTAssertEqual(XCTWaiter.wait(for:[parentReady],timeout:8),.completed)
        XCTAssertFalse(app.staticTexts["sample.txt"].exists)
        app.buttons["parentConversation"].tap()
        XCTAssertTrue(team.waitForExistence(timeout:8))
        XCTAssertEqual(draft.value as? String,"Keep my parent draft")
        XCTAssertTrue(app.staticTexts["sample.txt"].exists)
        XCTAssertFalse(app.descendants(matching:.any)["agentTeamNew"].firstMatch.exists)
        capture(app,"Returned parent with draft and attachment")
    }
    func testSubagentNavigationAtAccessibilitySize() {
        let app = launch(["--synthetic-agent-team"],large:true)
        let team = app.buttons["agentTeam"]
        XCTAssertTrue(team.waitForExistence(timeout:5)); XCTAssertTrue(team.isHittable); team.tap()
        let child = app.buttons["agentConversation-chat-existing"]
        XCTAssertTrue(child.waitForExistence(timeout:5)); XCTAssertTrue(child.isHittable); child.tap()
        XCTAssertTrue(app.buttons["parentConversation"].waitForExistence(timeout:8))
        let parentReady = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:app.buttons["parentConversation"])
        XCTAssertEqual(XCTWaiter.wait(for:[parentReady],timeout:8),.completed)
        XCTAssertTrue(app.buttons["parentConversation"].isHittable)
        capture(app,"Subagent return at accessibility size")
        app.buttons["parentConversation"].tap()
        XCTAssertTrue(team.waitForExistence(timeout:8))
    }
    func testNewSubagentBadgeSurvivesForegroundRefresh() {
        let app = launch(["--synthetic-agent-team"])
        let badge = app.descendants(matching:.any)["agentTeamNew"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout:20))
        XCUIDevice.shared.press(.home); app.activate()
        let team = app.buttons["agentTeam"]
        XCTAssertTrue(team.waitForExistence(timeout:10))
        let refreshed = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:team)
        XCTAssertEqual(XCTWaiter.wait(for:[refreshed],timeout:10),.completed)
        XCTAssertTrue(badge.waitForExistence(timeout:5),"Foreground refresh must not mark an unopened child seen.")
        team.tap()
        XCTAssertTrue(app.buttons["agentConversation-chat-new"].waitForExistence(timeout:5))
    }
    func testReadOnlyMediaStopsWhenResponseSourceChanges() {
        let app = launch(["--synthetic-charts-media","audio","--synthetic-readonly-media","--synthetic-media-replacement"])
        app.buttons["agentActivity"].tap()
        let disclosure = app.buttons["agentDetails-1"]
        XCTAssertTrue(disclosure.waitForExistence(timeout:5)); disclosure.tap()
        let loads = app.buttons.matching(identifier:"Load audio")
        XCTAssertTrue(loads.firstMatch.waitForExistence(timeout:5))
        loads.element(boundBy:loads.count-1).tap()
        let close = app.buttons["unloadGeneratedAudio"]
        XCTAssertTrue(close.waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Ready to play"].waitForExistence(timeout:8))
        let released = XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:close)
        XCTAssertEqual(XCTWaiter.wait(for:[released],timeout:35),.completed,"Changed response content must release the old player even when URL and node ID match.")
        XCTAssertTrue(app.staticTexts["Revised synthetic audio"].firstMatch.waitForExistence(timeout:5))
    }
    private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        for _ in 0..<8 {
            let top = app.navigationBars.firstMatch.frame.maxY+80
            let bottom = min(app.buttons["draftOptions"].frame.minY,app.buttons["modelPresetPicker"].frame.minY)-25
            if element.exists, element.frame.minY > top, element.frame.maxY < bottom { return }
            let up = !element.exists || element.frame.minY >= top
            let origin = app.coordinate(withNormalizedOffset:.zero)
            origin.withOffset(CGVector(dx:10,dy:up ? bottom-12:top+12)).press(forDuration:0.05,thenDragTo:origin.withOffset(CGVector(dx:10,dy:up ? top+12:bottom-12)))
        }
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func matches(_ value:[UInt8],_ expected:[Int])->Bool { value.count == 3 && zip(value,expected).allSatisfy { abs(Int($0.0)-$0.1) <= 4 } }
    private func sample(_ app:XCUIApplication,point:CGPoint)->[UInt8] {
        guard let image = app.screenshot().image.cgImage,
              let pixel = image.cropping(to:CGRect(x:point.x/app.frame.width*CGFloat(image.width),y:point.y/app.frame.height*CGFloat(image.height),width:1,height:1)) else { return [] }
        var bytes = [UInt8](repeating:0,count:4)
        let context = CGContext(data:&bytes,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(pixel,in:CGRect(x:0,y:0,width:1,height:1)); return Array(bytes.prefix(3))
    }
}
