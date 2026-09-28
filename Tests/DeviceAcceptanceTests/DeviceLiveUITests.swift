import XCTest

/// Opt-in physical-device acceptance. The owner scans and enters credentials on
/// the phone. This harness never reads credentials or invokes a chat mutation.
@MainActor final class DeviceLiveUITests: XCTestCase {
    func testOwnerSignInWithoutCamera() throws {
        let origin = try XCTUnwrap(ProcessInfo.processInfo.environment["A0_DEVICE_LIVE_ORIGIN"])
        let destination = try XCTUnwrap(URLComponents(string: origin))
        guard destination.scheme == "https", destination.host != nil,
              destination.user == nil, destination.password == nil,
              destination.query == nil, destination.fragment == nil,
              destination.path.isEmpty || destination.path == "/" else {
            XCTFail("Live acceptance requires an HTTPS origin without credentials."); return
        }
        let app = XCUIApplication(); app.launch()
        let field = app.textFields["serverOrigin"]
        XCTAssertTrue(field.waitForExistence(timeout:10))
        field.tap(); field.typeText(origin)
        print("OWNER_SIGN_IN_READY: enter credentials directly on the phone; Connect securely stays at the bottom.")
        guard app.staticTexts["Live"].waitForExistence(timeout:300) else {
            XCTFail("Authenticated full realtime state was not observed within the acceptance window."); return
        }
        guard app.staticTexts["Socket.IO state is current."].waitForExistence(timeout:5) else {
            XCTFail("Live status did not retain its full-state confirmation."); return
        }
        print("DEVICE_LIVE_ACCEPTED: authenticated HTTPS and full Socket.IO state; no chat command submitted.")
    }
    func testCameraImportAndOwnerSignIn() throws {
        let origin = try XCTUnwrap(ProcessInfo.processInfo.environment["A0_DEVICE_LIVE_ORIGIN"])
        let destination = try XCTUnwrap(URLComponents(string: origin))
        guard destination.scheme == "https", destination.host != nil,
              destination.user == nil, destination.password == nil,
              destination.query == nil, destination.fragment == nil,
              destination.path.isEmpty || destination.path == "/" else {
            XCTFail("Live acceptance requires an HTTPS origin without credentials."); return
        }
        let app = XCUIApplication()
        app.launch()
        let scan = app.buttons["Scan server QR"]
        XCTAssertTrue(scan.waitForExistence(timeout:10))
        scan.tap()
        let camera = app.buttons["Open camera"]
        XCTAssertTrue(camera.waitForExistence(timeout:10))
        camera.tap()
        print("OWNER_CAMERA_READY: allow camera access and scan the supplied server QR on the Mac.")
        let useServer = app.buttons["Use this server"]
        guard useServer.waitForExistence(timeout:180) else {
            XCTFail("Owner camera scan did not reach destination review within the acceptance window."); return
        }
        guard app.staticTexts[origin].exists else {
            XCTFail("Scanned destination does not match the owner-provided origin."); return
        }
        useServer.tap()
        XCTAssertEqual(app.textFields["serverOrigin"].value as? String, origin)
        print("OWNER_SIGN_IN_READY: enter credentials directly on the phone and tap Connect securely.")
        guard app.staticTexts["Live"].waitForExistence(timeout:180) else {
            XCTFail("Authenticated full realtime state was not observed within the acceptance window."); return
        }
        guard app.staticTexts["Socket.IO state is current."].waitForExistence(timeout:5) else {
            XCTFail("Live status did not retain its full-state confirmation."); return
        }
        print("DEVICE_LIVE_ACCEPTED: authenticated HTTPS and full Socket.IO state; no chat command submitted.")
    }
}
