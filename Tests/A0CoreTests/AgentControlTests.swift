import Foundation
import Testing
@testable import A0Core

@Suite struct AgentControlTests {
    @Test func controlPayloadsAreExplicitAndScoped() throws {
        #expect(try AgentControl.pause(true).request(context:"c").payload["paused"] == .bool(true))
        #expect(try AgentControl.nudge.request(context:"c").payload == ["ctxid":.string("c")])
        #expect(try AgentControl.history.request(context:"c").path == "/api/history_get")
        #expect(try AgentControl.context.request(context:"c").path == "/api/ctx_window_get")
        #expect(throws:ClientError.incompatiblePayload) { try AgentControl.nudge.request(context:"") }
    }
    @Test func repliesMustMatchRequestedContextAndPause() throws {
        #expect(throws:ClientError.incompatiblePayload) { try AgentControl.nudge.result(Data(#"{"ctxid":"other","message":"ok"}"#.utf8),context:"c") }
        #expect(throws:ClientError.incompatiblePayload) { try AgentControl.pause(true).result(Data(#"{"pause":false}"#.utf8),context:"c") }
        #expect(try AgentControl.history.result(Data(#"{"history":"Read only","tokens":42}"#.utf8),context:"c").text == "Read only")
        #expect(try AgentControl.context.result(Data(#"{"content":"Current context","tokens":2}"#.utf8),context:"c").tokens == 2)
    }
}

@Test func controlJournalSurvivesRelaunchAndRejectsAnotherMutation() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:dir) }
    let profile = ProfileIdentity(origin:try ServerOrigin("https://example.com"),username:"fixture")
    let receipt = ControlJournal.Receipt(title:"Nudge",context:"chat",profile:profile)
    let journal = ControlJournal(directory:dir)
    try await journal.begin(receipt)
    let restored = ControlJournal(directory:dir)
    #expect(try await restored.pending(profile) == receipt)
    await #expect(throws:PersistenceError.writeFailed) { try await restored.begin(receipt) }
    try await restored.resolve(receipt)
    #expect(try await restored.pending(profile) == nil)
}

@Test func controlCallsKeepAuthenticationAndNeverRetryFailedMutation() async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data:Data(),status:503)])
    let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
    try await client.connect(username:"fixture",password:"fixture")
    await #expect(throws:ClientError.httpStatus(503)) { try await client.perform(.nudge,context:"chat") }
    let requests = await transport.requests
    #expect(requests.count == 4)
    #expect(requests.last?.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
    #expect(requests.last?.value(forHTTPHeaderField:"Origin") == "https://server.test")
    await client.disconnect()
    await #expect(throws:ClientError.requiresLogin) { try await client.perform(.pause(true),context:"chat") }
    #expect(await transport.requests.count == 4)
}

@Test func stopClearsQueueBeforeCancellingAndValidatesAcknowledgement() async throws {
    let transport = ScriptTransport(loginResponses() + [
        HTTPResponse(data:Data(#"{"ok":true,"remaining":0}"#.utf8),status:200,headers:["Content-Type":"application/json"]),
        HTTPResponse(data:Data(#"{"context":"chat","stopped":true}"#.utf8),status:200,headers:["Content-Type":"application/json"])
    ])
    let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
    try await client.connect(username:"fixture",password:"fixture")
    _ = try await client.perform(.stop,context:"chat")
    let requests = await transport.requests
    #expect(requests.suffix(2).compactMap { $0.url?.path } == ["/api/message_queue_remove", "/api/stop"])
    for request in requests.suffix(2) {
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
        #expect(try JSONDecoder().decode([String:JSONValue].self,from:request.httpBody!) == ["context":.string("chat")])
    }
    #expect(throws:ClientError.incompatiblePayload) { try AgentControl.stop.result(Data(#"{"context":"other","stopped":true}"#.utf8),context:"chat") }
    #expect(throws:ClientError.incompatiblePayload) { try AgentControl.stop.result(Data(#"{"context":"chat"}"#.utf8),context:"chat") }
    #expect(try AgentControl.stop.result(Data(#"{"context":"chat","stopped":false}"#.utf8),context:"chat").tokens == nil)
}

@Test func stopStillCancelsWhenQueueClearFailsWithoutRetrying() async throws {
    let transport = ScriptTransport(loginResponses() + [
        HTTPResponse(data:Data(),status:503),
        HTTPResponse(data:Data(#"{"context":"chat","stopped":true}"#.utf8),status:200,headers:["Content-Type":"application/json"])
    ])
    let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
    try await client.connect(username:"fixture",password:"fixture")
    await #expect(throws:ClientError.httpStatus(503)) { try await client.perform(.stop,context:"chat") }
    #expect(await transport.requests.count == 5)
    #expect(await transport.requests.last?.url?.path == "/api/stop")
}
