import Foundation
import Testing
@testable import A0Core

@Test func qrAcceptsPlainHTTPSOriginFromTunnel() throws {
    let destination = try QRDestination("  HTTPS://Agent.Example:8443/\n")
    #expect(destination.origin.header == "https://agent.example:8443")
    #expect(!destination.origin.allowsUnauthenticatedLoopback)
}

@Test(arguments: ["http://localhost:49805", "http://agent.example", "https://user:secret@agent.example", "https://agent.example/login", "https://agent.example?token=secret", "https://agent.example/#secret", "javascript:alert(1)", "{\"url\":\"https://agent.example\"}", "https://agent.example\\@other.example", "https://ag\nent.example", "https://аgent.example", "https://agent.example%2f.evil", "https://agent.example:99999", "", String(repeating:"x",count:2049)])
func qrRejectsUnsafeOrUnsupportedPayload(_ payload: String) {
    #expect(throws: QRImportIssue.invalidCode) { try QRDestination(payload) }
}

@Test func scannedDestinationRequiresExplicitConsumptionAndIgnoresDuplicates() {
    var flow = QRImportSession()
    let id = flow.beginScan()
    flow.receive("https://one.example", from:id)
    #expect(flow.destination?.origin.header == "https://one.example")
    flow.receive("https://two.example", from:id)
    #expect(flow.destination?.origin.header == "https://one.example")
    #expect(flow.confirm()?.origin.header == "https://one.example")
    #expect(flow.confirm() == nil)
}

@Test func cancelledAndReplacedScansCannotChangeDestination() {
    var flow = QRImportSession()
    let first = flow.beginScan()
    flow.cancel()
    flow.receive("https://stale.example",from:first)
    #expect(flow.destination == nil)
    let second = flow.beginScan()
    flow.receive("https://stale.example",from:first)
    #expect(flow.scanID == second)
    flow.receive("https://current.example",from:second)
    flow.cancel()
    #expect(flow.confirm() == nil)
}

@Test func invalidQRCodeDoesNotEchoSecretsOrKeepPreviousReview() {
    var flow = QRImportSession()
    flow.review("https://one.example")
    flow.review("https://one.example?token=fixture-secret")
    #expect(flow.destination == nil)
    #expect(flow.issue == .invalidCode)
    #expect(!(flow.issue?.message.contains("fixture-secret") ?? true))
    #expect(flow.confirm() == nil)
    flow.review("https://two.example")
    #expect(flow.issue == nil)
    #expect(flow.destination?.origin.header == "https://two.example")
}

@Test(arguments: [QRImportIssue.cameraDenied, .cameraUnavailable])
func cameraFailuresAllowManualReviewAndIgnoreLateCallbacks(_ issue: QRImportIssue) {
    var flow = QRImportSession()
    let id = flow.beginScan()
    flow.failCamera(issue, from:id)
    #expect(flow.scanID == nil)
    #expect(flow.issue == issue)
    flow.review("https://manual.example")
    flow.failCamera(issue,from:id)
    #expect(flow.issue == nil)
    #expect(flow.confirm()?.origin.header == "https://manual.example")
}
