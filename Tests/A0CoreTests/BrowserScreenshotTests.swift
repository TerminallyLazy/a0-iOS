import Foundation
import Testing
@testable import A0Core

@Suite struct BrowserScreenshotTests {
    func entry(_ fields: String, type: String = "tool") throws -> LogEntry {
        try JSONDecoder().decode(LogEntry.self,from:Data("{\"no\":1,\"type\":\"\(type)\",\"kvps\":\(fields)}".utf8))
    }
    @Test func structuredSnapshotWinsAndIsContextScoped() throws {
        let log = try entry(#"{"browser_snapshot":{"path":"/a0/usr/chats/chat/screenshots/one.jpg","context_id":"chat","mime":"image/jpeg"},"Screenshot":"img:///a0/tmp/old.png&t=3"}"#)
        #expect(BrowserScreenshot.extract(log,context:"chat")?.path == "/a0/usr/chats/chat/screenshots/one.jpg")
        #expect(BrowserScreenshot.extract(log,context:"other") == nil)
    }
    @Test func legacyURIIsStrictAndCacheSuffixRemoved() throws {
        let log = try entry(#"{"Screenshot":"img:///a0/tmp/browser/screen.png&t=123.45"}"#)
        #expect(BrowserScreenshot.extract(log,context:"chat")?.path == "/a0/tmp/browser/screen.png")
        #expect(BrowserScreenshot.extract(try entry(#"{"Screenshot":"img:///a0/tmp/browser/screen.png&t=1"}"#,type:"user"),context:"chat") == nil)
    }
    @Test(arguments:["https://evil.test/a.png","//evil.test/a.png","/a0/../secret.png","/a0/tmp/a.svg","/a0/tmp/a.png?secret=1","/a0/tmp/a.png#x","/a0/tmp/%2e%2e/a.png"])
    func refusesUnsafePaths(_ path:String) throws {
        let fields = try JSONEncoder().encode(["Screenshot":"img://" + path])
        #expect(BrowserScreenshot.extract(try entry(String(decoding:fields,as:UTF8.self)),context:"chat") == nil)
    }
    @Test func ephemeralAndUnsupportedSnapshotsDoNotFallback() throws {
        let log = try entry(#"{"browser_snapshot":{"ephemeral":true,"ephemeral_ref":"private","context_id":"chat"},"Screenshot":"img:///a0/tmp/old.png"}"#)
        #expect(BrowserScreenshot.extract(log,context:"chat") == nil)
    }
    @Test func requestUsesOnlyServerOriginAndImageEndpoint() throws {
        let ref = try #require(BrowserScreenshot.extract(try entry(#"{"Screenshot":"img:///a0/tmp/a b.png"}"#),context:"chat"))
        let origin = try ServerOrigin("https://server.test")
        let request = try ref.request(session:SocketSession(origin:origin,cookieHeader:"synthetic=session",csrfToken:"token",runtimeID:"runtime"))
        #expect(request.url?.host == "server.test")
        #expect(request.url?.path == "/api/image_get")
        #expect(URLComponents(url:try #require(request.url),resolvingAgainstBaseURL:false)?.queryItems == [URLQueryItem(name:"path",value:"/a0/tmp/a b.png")])
        #expect(request.value(forHTTPHeaderField:"Cookie") == "synthetic=session")
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") == "token")
    }
    @Test func authenticatedReadRejectsRedirectAndStopsAfterDisconnect() async throws {
        let transport = ScriptTransport(loginResponses() + [HTTPResponse(data:Data([1,2]),status:200,headers:["Content-Type":"image/png"]),HTTPResponse(data:Data(),status:302,headers:["Location":"https://elsewhere.test/screenshot.png"])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        let reference = try #require(BrowserScreenshot.extract(try entry(#"{"Screenshot":"img:///a0/tmp/browser.png"}"#),context:"chat"))
        await #expect(throws:ClientError.requiresLogin) { try await client.browserScreenshot(reference) }
        try await client.connect(username:"fixture",password:"fixture")
        #expect(try await client.browserScreenshot(reference) == Data([1,2]))
        await #expect(throws:ClientError.httpStatus(302)) { try await client.browserScreenshot(reference) }
        await client.disconnect()
        await #expect(throws:ClientError.requiresLogin) { try await client.browserScreenshot(reference) }
        #expect(await transport.requests.count == 5)
    }
    @Test func rejectsHTMLSVGAndOversizedResponse() throws {
        for mime in ["text/html","image/svg+xml","application/json"] {
            #expect(throws:ClientError.unexpectedResponse) { try BrowserScreenshot.validate(HTTPResponse(data:Data([1]),status:200,headers:["Content-Type":mime])) }
        }
        #expect(throws:ClientError.unexpectedResponse) { try BrowserScreenshot.validate(HTTPResponse(data:Data(count:BrowserScreenshot.maximumBytes+1),status:200,headers:["Content-Type":"image/png"])) }
        #expect(throws:ClientError.httpStatus(302)) { try BrowserScreenshot.validate(HTTPResponse(data:Data(),status:302,headers:["Location":"https://elsewhere.test"])) }
    }
}
