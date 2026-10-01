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

private func presenceData(connected:Bool = true, ambiguous:Bool = false, master:Bool = true, browser:Bool = true) throws -> Data {
    try JSONSerialization.data(withJSONObject:["connected":connected,"multiple_hosts":ambiguous,
        "gateway":["version":1,"kind":"launcher","id":"launcher-fixture","host_label":"Demo Mac","master_enabled":master,
            "scopes":["browser":browser,"computer_use":true,"files":true,"file_write":true,"code_execution":true]]])
}
private func setupData(host:String = "launcher-fixture", reason:String = "verified", connected:Bool = true) throws -> Data {
    try JSONSerialization.data(withJSONObject:["version":1,"server_id":String(repeating:"a",count:32),
        "observed_at":Date().timeIntervalSince1970,"host_id":host,"host_label":"Demo Mac","connected":connected,"platform":"macos",
        "steps":["browser","computer_use"].map { ["id":$0,"state":reason == "verified" ? "ready":"action_on_computer",
            "reason":reason,"title":"Setup status","detail":"Fixture check","action":"test_connection","location":"computer","help_id":$0] }])
}

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
        #expect(value.capabilities.isEmpty)
    }
    @Test func newChatShowsGrantsAndSharedSetupWithoutAuthorizingTasks() throws {
        let value = try HostConnection(legacyData:presenceData(),setup:ComputerSetupSnapshot(data:setupData()))
        #expect(value.capabilities == ["browser":"tested","computer_use":"tested","files":"allowed","file_write":"allowed","code_execution":"allowed"])
        #expect(!value.targeted && value.targetID == nil && value.generation == nil)
        #expect(value.selection(.browser) == nil && value.selection(.computerUse) == nil)
        let prepared = try HostConnection(legacyData:presenceData(),setup:ComputerSetupSnapshot(data:setupData(reason:"ready_to_test")))
        #expect(prepared.capabilities["browser"] == "prepared")
        #expect(prepared.capabilities["computer_use"] == "prepared")
    }
    @Test func setupNeverOverridesRevokedOrAmbiguousPresence() throws {
        let setup = try ComputerSetupSnapshot(data:setupData())
        for presence in [try presenceData(connected:false),try presenceData(ambiguous:true)] {
            #expect(try HostConnection(legacyData:presence,setup:setup).capabilities.isEmpty)
        }
        let off = try HostConnection(legacyData:presenceData(master:false),setup:setup)
        #expect(off.capabilities.values.allSatisfy { $0 == "off" })
        #expect(try HostConnection(legacyData:presenceData(browser:false),setup:setup).capabilities["browser"] == "off")
        for snapshot in [try setupData(host:"other-computer"),try setupData(connected:false)] {
            let value = try HostConnection(legacyData:presenceData(),setup:ComputerSetupSnapshot(data:snapshot))
            #expect(value.capabilities["browser"] == "allowed")
            #expect(value.selection(.browser) == nil)
        }
    }
    @Test func newChatFetchesSetupReadOnlyWhileOlderServersKeepExplicitGrants() async throws {
        for supportsSetup in [true,false] {
            let features = ["launcher_gateway","host_tasks_v1"] + (supportsSetup ? ["host_setup_v1"]:[])
            let discovery = try JSONSerialization.data(withJSONObject:["protocol":"a0-connector.v1","features":features])
            let headers = ["Content-Type":"application/json"]
            var replies = [HTTPResponse(data:discovery,status:200,headers:headers),HTTPResponse(data:try presenceData(),status:200,headers:headers)]
            if supportsSetup { replies.append(HTTPResponse(data:try setupData(),status:200,headers:headers)) }
            let transport = ScriptTransport(loginResponses()+replies)
            let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
            try await client.connect(username:"fixture",password:"fixture")
            let value = try await client.hostConnection(context:nil)
            #expect(value.capabilities["browser"] == (supportsSetup ? "tested":"allowed"))
            #expect(value.selection(.browser) == nil)
            let requests = await transport.requests
            #expect(!requests.contains { ["host_status","host_task","chat_create"].contains($0.url?.lastPathComponent ?? "") })
            if supportsSetup {
                let request = try #require(requests.last)
                #expect(request.url?.lastPathComponent == "host_setup")
                #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") != nil)
                #expect(try JSONDecoder().decode([String:String].self,from:#require(request.httpBody)) == ["action":"status"])
            }
        }
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
