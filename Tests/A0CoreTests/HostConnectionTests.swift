import Foundation
import Testing
@testable import A0Core

private let hostToken = String(repeating:"a",count:64)
private let hostGeneration = String(repeating:"b",count:64)
private func hostData(context:String = "chat", state:String = "connected", generation:String = hostGeneration) throws -> Data {
    let caps = Dictionary(uniqueKeysWithValues:["browser","computer_use","files","file_write","code_execution"].map { ($0,JSONValue.object(["ready":.bool($0 == "browser"),"state":.string($0 == "browser" ? "ready" : "off")])) })
    return try JSONEncoder().encode(["version":JSONValue.number(1),"context_id":.string(context),"state":.string(state),
        "host_label":.string("Demo Mac"),"target_id":.string(hostToken),"generation":.string(generation),
        "bound":.bool(false),"binding_current":.bool(false),"capabilities":.object(caps)])
}
private func selection() -> HostTaskSelection { HostTaskSelection(targetID:hostToken,hostLabel:"Demo Mac",capability:.browser,generation:hostGeneration) }

@Suite struct HostConnectionTests {
    @Test func readinessIsCapabilitySpecificAndContextBound() throws {
        let status = try HostConnection(data:hostData(),context:"chat")
        #expect(status.selection(.browser) != nil)
        #expect(status.selection(.computerUse) == nil)
        #expect(throws:ClientError.incompatiblePayload) { try HostConnection(data:hostData(),context:"another") }
        #expect(try HostConnection(data:hostData(state:"ambiguous"),context:"chat").selection(.browser) == nil)
        #expect(try HostConnection(data:hostData(generation:"untrusted"),context:"chat").selection(.browser) == nil)
    }
    @Test func legacyPresenceNeverEnablesTargetedWork() throws {
        let value = try HostConnection(legacyData:Data(#"{"connected":true,"gateway":{"host_label":"Demo Mac","profile_path":"private"}}"#.utf8))
        #expect(value.state == "presence_only")
        #expect(value.selection(.browser) == nil && value.context == nil)
    }
    @Test func generationNeverPersists() throws {
        let data = try JSONEncoder().encode(selection())
        #expect(!String(decoding:data,as:UTF8.self).contains(hostGeneration))
        let restored = try JSONDecoder().decode(HostTaskSelection.self,from:data)
        #expect(restored.generation == nil && restored.hostLabel == "Demo Mac")
    }
    @Test func unsupportedServerLeavesAuthenticatedChatAvailable() async throws {
        let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:Data(),status:404,headers:[:])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        #expect(try await client.hostConnection(context:"chat").state == "unsupported")
        _ = try await client.socketSession()
    }
    @Test func hostMutationHasOneRequestAndMatchingReceipt() async throws {
        let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:Data(#"{"ok":true,"context":"chat","message_id":"message","queued":false}"#.utf8),status:200,headers:["Content-Type":"application/json"])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        try await client.sendHostTask(context:"chat",text:"Inspect demo",messageID:"message",queued:false,selection:selection())
        let request = try #require(await transport.requests.last)
        #expect(request.url?.path == "/api/plugins/_a0_connector/v1/host_task")
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") != nil)
        let body = try JSONDecoder().decode([String:String].self,from:try #require(request.httpBody))
        #expect(body["generation"] == hostGeneration && body["capability"] == "browser")
        #expect(await transport.requests.count == 4)
    }
    @Test func computerCapturesRequireExactContextAndUseBoundedImageTransport() throws {
        let data = Data(#"{"no":1,"type":"tool","kvps":{"computer_snapshot":{"path":"/a0/usr/chats/chat/screenshots/demo.png","source":"computer","context_id":"chat","host_label":"Demo Mac","captured_at":100,"capture_id":"capture"}}}"#.utf8)
        let log = try JSONDecoder().decode(LogEntry.self,from:data)
        let capture = try #require(BrowserScreenshot.extract(log,context:"chat"))
        #expect(capture.source == "computer" && capture.hostLabel == "Demo Mac")
        #expect(capture.title == "Computer capture" && capture.revision == "capture")
        #expect(BrowserScreenshot.extract(log,context:"different") == nil)
        let redacted = try JSONDecoder().decode(LogEntry.self,from:Data(String(decoding:data,as:UTF8.self).replacingOccurrences(of:"Demo Mac",with:"§§secret(AUTH_LOGIN).local").utf8))
        #expect(BrowserScreenshot.extract(redacted,context:"chat")?.hostLabel == nil)
    }
}

private actor HostChatDouble: ChatAPI {
    var hostCalls = 0
    var ordinaryCalls = 0
    let fail: Bool
    init(fail:Bool = false) { self.fail = fail }
    func createChat(id:String) async throws -> String { id }
    func sendText(context:String,text:String,messageID:String,queued:Bool) async throws { ordinaryCalls += 1 }
    func sendHostTask(context:String,text:String,messageID:String,queued:Bool,selection:HostTaskSelection) async throws {
        hostCalls += 1
        if fail { throw URLError(.timedOut) }
    }
}

@MainActor @Suite struct HostDraftTests {
    @Test func targetSurvivesAsIntentAndDoesNotSilentlyDowngrade() async throws {
        let api = HostChatDouble(), chat = ChatSession(api:api)
        chat.select("chat"); chat.draft = "Inspect the demo"; chat.selectHostTask(selection())
        chat.suspend(); chat.resume(api:api)
        #expect(chat.hostTask != nil && chat.hostTask?.generation == nil && !chat.canSend)
        await chat.send()
        #expect(await api.hostCalls == 0)
        #expect(await api.ordinaryCalls == 0)
        chat.selectHostTask(selection())
        await chat.send()
        #expect(await api.hostCalls == 1)
        #expect(await api.ordinaryCalls == 0)
        #expect(chat.deliveries.first?.hostLabel == "Demo Mac")
    }
    @Test func hostTimeoutNeverReplaysOrFallsBack() async {
        let api = HostChatDouble(fail:true), chat = ChatSession(api:api)
        chat.select("chat"); chat.draft = "Inspect demo"; chat.selectHostTask(selection())
        await chat.send(); await chat.send()
        #expect(chat.deliveries.first?.status == .uncertain)
        #expect(await api.hostCalls == 1)
        #expect(await api.ordinaryCalls == 0)
    }
    @Test func draftsAndTargetsStayChatScopedAndStaleStatusInvalidates() throws {
        let chat = ChatSession(api:HostChatDouble())
        chat.select("chat"); chat.draft = "Inspect demo"; chat.selectHostTask(selection())
        chat.select("another"); #expect(chat.hostTask == nil)
        chat.select("chat"); #expect(chat.hostTask?.generation == hostGeneration)
        chat.reconcileHost(try HostConnection(data:hostData(generation:String(repeating:"c",count:64)),context:"chat"))
        #expect(chat.hostTask?.generation == nil && !chat.canSend)
    }
}
