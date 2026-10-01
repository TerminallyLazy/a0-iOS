import XCTest
import UIKit

@MainActor final class LiveViewerUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    func testOneViewerExpandsForAcknowledgedTakeoverAndReturns() {
        let app = XCUIApplication()
        app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-browser-screenshot","--synthetic-live-viewer","--persistence-test-id",UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
        app.buttons["chat-alpha"].tap(); app.waitForConversation()
        let takeover = app.buttons["takeOverHost"]
        XCTAssertTrue(takeover.waitForExistence(timeout:10))
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:takeover)
        waitForExpectations(timeout:10)
        XCTAssertLessThanOrEqual(app.buttons.matching(identifier:"browserScreenshot").count,1)
        app.segmentedControls.buttons["Computer"].tap()
        XCTAssertEqual(takeover.label,"Take over computer")
        app.segmentedControls.buttons["Browser"].tap()
        XCTAssertEqual(takeover.label,"Take over browser")
        takeover.tap()
        let handback = app.buttons["returnToA0"]
        XCTAssertTrue(handback.waitForExistence(timeout:10))
        XCTAssertFalse(app.secureTextFields["Text to type on the host"].exists)
        app.buttons["viewerKeyboard"].tap()
        XCTAssertTrue(app.secureTextFields["Text to type on the host"].isHittable)
        XCTAssertTrue(handback.isHittable)
        app.buttons["viewerKeyboard"].tap()
        XCTAssertEqual(app.webViews.matching(identifier:"hostCaptureWebView").count,1)
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Single expanded live viewer"; shot.lifetime = .keepAlways; add(shot)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(handback.waitForExistence(timeout:5))
        XCTAssertEqual(app.webViews.matching(identifier:"hostCaptureWebView").count,1)
        XCUIDevice.shared.orientation = .portrait
        handback.tap()
        XCTAssertTrue(takeover.waitForExistence(timeout:10))
        app.buttons["Minimize live view"].tap()
        XCTAssertEqual(app.webViews.matching(identifier:"hostCaptureWebView").count,1)
        XCTAssertTrue(app.buttons["Expand live view"].exists)
    }
    func testViewerChromeAndLetterboxingMatchThemeInBothAppearances() {
        let app = XCUIApplication()
        for (mode,canvas,panel) in [("Dark",[7,28,40],[16,39,55]),("Light",[217,237,249],[237,248,255])] {
            app.launchArguments = ["--synthetic-http-preview","--synthetic-chat-selection","--synthetic-browser-screenshot","--synthetic-live-viewer","--synthetic-expanded-theme","--persistence-test-id",UUID().uuidString,"-appearance",mode.lowercased()]
            app.launch()
            XCTAssertTrue(app.buttons["chat-alpha"].waitForExistence(timeout:10))
            app.buttons["chat-alpha"].tap(); app.waitForConversation()
            app.buttons["conversationOptions"].tap(); app.buttons["Settings"].tap()
            let matched = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","Matching Catalog Ocean"),object:app.staticTexts["serverThemeStatus"])
            XCTAssertEqual(XCTWaiter.wait(for:[matched],timeout:15),.completed)
            app.buttons["settingsDone"].tap()
            let dismissed = XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.buttons["settingsDone"])
            XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:5),.completed)
            app.buttons["hostComputer"].tap()
            let computerNavigation = app.navigationBars["Computer"]
            XCTAssertTrue(computerNavigation.waitForExistence(timeout:5))
            assertPixel(app,point:CGPoint(x:computerNavigation.frame.minX+15,y:computerNavigation.frame.midY),expected:panel)
            let refresh = app.buttons["Refresh status"]
            XCTAssertTrue(refresh.waitForExistence(timeout:5))
            assertPixel(app,point:CGPoint(x:app.frame.width-48,y:refresh.frame.midY),expected:panel)
            // Sample the empty outer gutter; scrolling rows can put text under
            // a fixed bottom-center point when the setup entry is present.
            assertPixel(app,point:CGPoint(x:8,y:refresh.frame.midY),expected:canvas,alternate:panel)
            let computerShot = XCTAttachment(screenshot:app.screenshot()); computerShot.name = mode+" themed Computer sheet"; computerShot.lifetime = .keepAlways; add(computerShot)
            app.buttons["Done"].tap()
            let takeover = app.buttons["takeOverHost"]
            XCTAssertTrue(takeover.waitForExistence(timeout:10))
            let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:takeover)
            XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:10),.completed)
            let web = app.webViews["hostCaptureWebView"]
            XCTAssertTrue(web.waitForExistence(timeout:10))
            assertPixel(app,point:CGPoint(x:web.frame.minX+20,y:web.frame.minY+4),expected:canvas)
            let source = app.segmentedControls["captureSource"]
            assertPixel(app,point:CGPoint(x:source.frame.minX-5,y:source.frame.midY),expected:panel)
            takeover.tap()
            let handback = app.buttons["returnToA0"]
            XCTAssertTrue(handback.waitForExistence(timeout:10))
            assertPixel(app,point:CGPoint(x:web.frame.minX+20,y:web.frame.minY+4),expected:canvas)
            assertPixel(app,point:CGPoint(x:app.frame.width*0.2,y:app.frame.maxY-8),expected:canvas)
            let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = mode+" themed live viewer"; shot.lifetime = .keepAlways; add(shot)
            handback.tap()
            XCTAssertTrue(takeover.waitForExistence(timeout:10))
            app.buttons["Minimize live view"].tap()
        }
    }
    private func assertPixel(_ app:XCUIApplication,point:CGPoint,expected:[Int],alternate:[Int]? = nil,file:StaticString = #filePath,line:UInt = #line) {
        guard let image = app.screenshot().image.cgImage,
              let pixel = image.cropping(to:CGRect(x:point.x/app.frame.width*CGFloat(image.width),y:point.y/app.frame.height*CGFloat(image.height),width:1,height:1)) else { XCTFail("Missing screenshot",file:file,line:line);return }
        var bytes = [UInt8](repeating:0,count:4)
        let context = CGContext(data:&bytes,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(pixel,in:CGRect(x:0,y:0,width:1,height:1))
        if let alternate, zip(bytes,alternate).allSatisfy({ abs(Int($0)-$1) <= 3 }) { return }
        for (actual,wanted) in zip(bytes,expected) { XCTAssertEqual(Int(actual),wanted,accuracy:3,file:file,line:line) }
    }

}
