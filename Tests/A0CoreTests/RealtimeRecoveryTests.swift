import Foundation
import Testing
@testable import A0Core

@Test func realtimeRetriesUseBoundedCadenceWithoutCatchupBursts() {
    var schedule = RealtimeRetrySchedule()
    #expect(schedule.reserve(at: .seconds(29)) == false)
    #expect(schedule.reserve(at: .seconds(30)) == true)
    #expect(schedule.reserve(at: .seconds(89)) == false)
    #expect(schedule.reserve(at: .seconds(90)) == true)
    #expect(schedule.reserve(at: .seconds(209)) == false)
    #expect(schedule.reserve(at: .seconds(210)) == true)
    #expect(schedule.reserve(at: .seconds(1000)) == true)
    #expect(schedule.reserve(at: .seconds(1000)) == false)
    #expect(schedule.reserve(at: .seconds(1119)) == false)
    #expect(schedule.reserve(at: .seconds(1120)) == true)
}

private func recoveryPush(_ name: String = "full", epoch: String = "runtime", sequence: Int = 2) throws -> StatePush {
    let text = "{\"data\":{\"runtime_epoch\":\"\(epoch)\",\"seq\":\(sequence),\"snapshot\":\(String(decoding: try fixture(name), as: UTF8.self))}}"
    return try JSONDecoder().decode(StatePush.self, from: Data(text.utf8))
}
@Test func handoffRequiresHandshakeAndFullSnapshot() throws {
    var source = SyncReducer(); source.select(context: "synthetic-chat")
    let generation = source.generation
    var handoff = RealtimeHandoff(context: "synthetic-chat", sourceGeneration: generation)
    #expect(handoff.accept(try recoveryPush(), replacing: source) == nil)
    handoff.handshake(epoch: "runtime", sequenceBase: 1)
    #expect(handoff.accept(try recoveryPush("delta"), replacing: source) == nil)
    let promoted = try #require(handoff.accept(try recoveryPush(), replacing: source))
    #expect(!promoted.needsFullSync)
    #expect(promoted.logs == (try snapshot()).logs)
    #expect(promoted.sequence == 2)
    #expect(promoted.epoch == "runtime")
    #expect(handoff.request.logFrom == 0)
    #expect(handoff.request.notificationsFrom == 0)
}
@Test func handoffCannotCrossContextOrConnectionGeneration() throws {
    var source = SyncReducer(); source.select(context: "synthetic-chat")
    let generation = source.generation
    var handoff = RealtimeHandoff(context: "synthetic-chat", sourceGeneration: generation)
    handoff.handshake(epoch: "runtime", sequenceBase: 1)
    #expect(handoff.accept(try recoveryPush(), replacing: SyncReducer()) == nil)
    var other = RealtimeHandoff(context: "other-chat", sourceGeneration: generation)
    other.handshake(epoch: "runtime", sequenceBase: 1)
    #expect(other.accept(try recoveryPush(), replacing: source) == nil)
}
@Test(arguments: ["runtime", "other-runtime"])
func handoffRejectsWrongEpochOrSequence(epoch: String) throws {
    var source = SyncReducer(); source.select(context: "synthetic-chat")
    let generation = source.generation
    var handoff = RealtimeHandoff(context: "synthetic-chat", sourceGeneration: generation)
    handoff.handshake(epoch: "runtime", sequenceBase: 1)
    #expect(handoff.accept(try recoveryPush(epoch: epoch, sequence: 8), replacing: source) == nil)
}
@Test func freshSocketSessionRevalidatesAndRotatesSecurityContextWithoutLogin() async throws {
    let refreshed = HTTPResponse(data: Data(#"{"ok":true,"token":"new-csrf","runtime_id":"new-runtime"}"#.utf8), status: 200,
        headers: ["Content-Type":"application/json", "Set-Cookie":"session_new-runtime=new-session; Path=/; Secure; HttpOnly"])
    let transport = ScriptTransport(loginResponses() + [refreshed])
    let client = APIClient(origin: try ServerOrigin("https://server.test"), transport: transport)
    try await client.connect(username: "user", password: "fixture")
    let session = try await client.refreshSocketSession()
    #expect(session.csrfToken == "new-csrf")
    #expect(session.runtimeID == "new-runtime")
    #expect(!session.cookieHeader.contains("test-runtime"))
    #expect(session.cookieHeader.contains("session_new-runtime=new-session"))
    let requests = await transport.requests
    #expect(requests.count == 4)
    #expect(requests.last?.httpMethod == "GET")
    #expect(requests.last?.url?.path == "/api/csrf_token")
    #expect(requests.last?.httpBody == nil)
    #expect(requests.last?.value(forHTTPHeaderField: "Origin") == "https://server.test")
}
@Test(arguments: [401, 403, 302])
func rejectedRefreshClearsSessionWithoutLoginOrReplay(status: Int) async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data: Data(), status: status, headers:["Location":"/login"])])
    let client = APIClient(origin: try ServerOrigin("https://server.test"), transport: transport)
    try await client.connect(username:"user", password:"fixture")
    await #expect(throws: status == 403 ? ClientError.csrfRejected : ClientError.requiresLogin) { try await client.refreshSocketSession() }
    await #expect(throws: ClientError.requiresLogin) { try await client.socketSession() }
    await #expect(throws: ClientError.requiresLogin) { try await client.refreshSocketSession() }
    #expect(await transport.requests.count == 4)
}
@Test func invalidRefreshCannotLeaveCachedSocketCredentialsUsable() async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data: Data(#"{"ok":false}"#.utf8), status:200, headers:["Content-Type":"application/json"])])
    let client = APIClient(origin: try ServerOrigin("https://server.test"), transport: transport)
    try await client.connect(username:"user", password:"fixture")
    await #expect(throws: ClientError.csrfRejected) { try await client.refreshSocketSession() }
    await #expect(throws: ClientError.requiresLogin) { try await client.socketSession() }
}
@Test func transientRefreshKeepsPollingSessionAndDoesNotRetry() async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data: Data(), status:503)])
    let client = APIClient(origin: try ServerOrigin("https://server.test"), transport: transport)
    try await client.connect(username:"user", password:"fixture")
    await #expect(throws: ClientError.httpStatus(503)) { try await client.refreshSocketSession() }
    #expect(try await client.socketSession().runtimeID == "test-runtime")
    #expect(await transport.requests.count == 4)
}

@Test(arguments: ["log_version", "notifications_version"])
func handoffCannotRollBackNewerPollingState(field: String) throws {
    var current = SyncReducer()
    current.select(context: "synthetic-chat")
    var object = try #require(JSONSerialization.jsonObject(with: fixture("full")) as? [String: Any])
    object[field] = 999
    let latest = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: object))
    _ = current.apply(snapshot: latest, generation: current.generation, full: true)
    var handoff = RealtimeHandoff(context: current.context, sourceGeneration: current.generation)
    handoff.handshake(epoch: "runtime", sequenceBase: 1)
    #expect(handoff.accept(try recoveryPush(), replacing: current) == nil)
}

@Test(arguments: ["log_guid", "notifications_guid"])
func handoffCannotCrossCollectionResetObservedByPolling(field: String) throws {
    var current = SyncReducer(); current.select(context: "synthetic-chat")
    var object = try #require(JSONSerialization.jsonObject(with: fixture("full")) as? [String: Any])
    object[field] = "rotated-collection"
    let latest = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: object))
    _ = current.apply(snapshot: latest, generation: current.generation, full: true)
    var handoff = RealtimeHandoff(context: current.context, sourceGeneration: current.generation)
    handoff.handshake(epoch: "runtime", sequenceBase: 1)
    #expect(handoff.accept(try recoveryPush(), replacing: current) == nil)
}
