import Foundation
import Testing
@testable import A0Core

@Suite struct LiveViewerTests {
    @Test func captureCollectionIsOneHistoryWithNewestPerSource() throws {
        let entries = try [1,2,3].map { n in
            try JSONDecoder().decode(LogEntry.self,from:Data("{\"no\":\(n),\"type\":\"tool\",\"kvps\":{\"browser_snapshot\":{\"path\":\"/a0/usr/chats/chat/screenshots/\(n).jpg\",\"context_id\":\"chat\"}}}".utf8))
        }
        let captures = ConversationCaptures(logs:entries,context:"chat")
        #expect(captures.history.count == 3)
        #expect(captures.latest(source:"browser")?.path.hasSuffix("3.jpg") == true)
        #expect(ConversationCaptures(logs:entries,context:"other").history.isEmpty)
    }
    @Test func wrongSourceOversizedFramesAndInvalidPhasesFailClosed() throws {
        var frame: [String:JSONValue] = ["id":.string(String(repeating:"a",count:32)),"source":.string("browser"),"width":.number(100),"height":.number(50),"mime":.string("image/jpeg"),"data":.string(Data([0xff,0xd8,0xff,0xd9]).base64EncodedString()),"captured_at":.number(100),"scope":.string("tab")]
        #expect(try LiveFrame(frame).width == 100)
        frame["width"] = .number(20_000)
        #expect(throws:ClientError.incompatiblePayload) { try LiveFrame(frame) }
        frame["width"] = .number(100); frame["source"] = .string("computer_use")
        #expect(throws:ClientError.incompatiblePayload) { try LiveFrame(frame) }
        #expect(throws:ClientError.incompatiblePayload) { try LiveViewerStatus(["supported":.bool(true),"phase":.string("maybe")]) }
    }
    @Test func ownershipMustBeAcknowledgedBeforeInput() throws {
        var state: [String:JSONValue] = ["supported":.bool(true),"phase":.string("requesting"),"mine":.bool(true),"recoverable":.bool(false),"sequence":.number(0),"host_label":.string("Fixture Mac")]
        #expect(try !LiveViewerStatus(state).controlling)
        state["phase"] = .string("human")
        #expect(try LiveViewerStatus(state).controlling)
        state["mine"] = .bool(false)
        #expect(try !LiveViewerStatus(state).controlling)
    }
    @Test func mutationIsSingleRequestAndRejectsMismatchedReceipt() async throws {
        let body = Data(#"{"version":1,"context":"chat","request_id":"wrong"}"#.utf8)
        let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:body,status:200,headers:["Content-Type":"application/json"])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        await #expect(throws:ClientError.incompatiblePayload) {
            try await client.hostViewer(context:"chat",viewer:String(repeating:"v",count:32),command:"acquire",source:"browser",fields:["request_id":.string(String(repeating:"r",count:32))])
        }
        #expect(await transport.requests.count == 4)
        let request = try #require(await transport.requests.last)
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") != nil)
        #expect(request.value(forHTTPHeaderField:"Cookie") != nil)
        #expect(request.value(forHTTPHeaderField:"Origin") == "https://server.test")
    }
}


private actor RefreshDuringViewerTransport: HTTPTransport {
    var responses = loginResponses()
    var held: CheckedContinuation<HTTPResponse, Never>?
    var observers: [CheckedContinuation<Void, Never>] = []
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        if !responses.isEmpty { return responses.removeFirst() }
        if request.url?.path.hasSuffix("host_viewer") == true {
            return await withCheckedContinuation { continuation in
                held = continuation; observers.forEach { $0.resume() }; observers.removeAll()
            }
        }
        return HTTPResponse(data:Data(#"{"ok":true,"token":"synthetic-csrf","runtime_id":"test-runtime"}"#.utf8),status:200,headers:["Content-Type":"application/json","Set-Cookie":"session_test-runtime=refreshed-session; Path=/; HttpOnly"])
    }
    func wait() async { if held != nil { return }; await withCheckedContinuation { observers.append($0) } }
    func finish() { held?.resume(returning:HTTPResponse(data:Data(#"{"version":1,"context":"chat","request_id":"receipt"}"#.utf8),status:200,headers:["Content-Type":"application/json"])); held = nil }
}

extension LiveViewerTests {
    @Test func cookieRefreshPreservesViewerAcknowledgementButDisconnectFencesIt() async throws {
        for disconnect in [false,true] {
            let transport = RefreshDuringViewerTransport()
            let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
            try await client.connect(username:"fixture",password:"fixture")
            let task = Task { try await client.hostViewer(context:"chat",viewer:String(repeating:"v",count:32),command:"heartbeat",source:"browser",fields:["request_id":.string("receipt")]) }
            await transport.wait()
            if disconnect { await client.disconnect() } else { _ = try await client.refreshSocketSession() }
            await transport.finish()
            if disconnect { await #expect(throws:ClientError.disconnected) { try await task.value } }
            else { #expect(try await task.value["request_id"] == .string("receipt")) }
        }
    }
}
