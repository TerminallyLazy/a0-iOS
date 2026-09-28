import Foundation
import Testing
@testable import A0Core

@Suite struct SessionRestorationTests {
    @Test func restoresOnlySessionCookieAndRefreshesSecurityWithoutLogin() async throws {
        let origin = try ServerOrigin("https://server.test")
        let identity = ProfileIdentity(origin: origin, username: "alice")
        let original = APIClient(origin: origin, transport: ScriptTransport(loginResponses()))
        try await original.connect(username: "alice", password: "not-persisted")
        let saved = try await original.savedAuthentication(for: identity)
        let encoded = try JSONEncoder().encode(saved)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("not-persisted"))
        #expect(!String(decoding: encoded, as: UTF8.self).contains("synthetic-csrf"))
        let transport = ScriptTransport([loginResponses()[0], loginResponses()[2]])
        let restored = APIClient(origin: origin, transport: transport)
        try await restored.restore(saved, for: identity)
        #expect(try await restored.socketSession().cookieHeader.contains("synthetic-session"))
        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.httpMethod == "GET" && $0.url?.path == "/api/csrf_token" })
        #expect(requests[0].value(forHTTPHeaderField: "Cookie") == nil)
        #expect(requests[1].value(forHTTPHeaderField: "Cookie") == "session_test-runtime=synthetic-session")
    }
    @Test func rejectsWrongAccountAndOriginBeforeNetwork() async throws {
        let origin = try ServerOrigin("https://server.test")
        let alice = ProfileIdentity(origin: origin, username: "alice")
        let source = APIClient(origin: origin, transport: ScriptTransport(loginResponses()))
        try await source.connect(username: "alice", password: "fixture")
        await #expect(throws: ClientError.requiresLogin) {
            try await source.savedAuthentication(for: ProfileIdentity(origin: origin, username: "bob"))
        }
        let saved = try await source.savedAuthentication(for: alice)
        let transport = ScriptTransport([])
        let restored = APIClient(origin: origin, transport: transport)
        await #expect(throws: ClientError.requiresLogin) {
            try await restored.restore(saved, for: ProfileIdentity(origin: origin, username: "bob"))
        }
        let other = APIClient(origin: try ServerOrigin("https://other.test"), transport: transport)
        await #expect(throws: ClientError.requiresLogin) { try await other.restore(saved, for: alice) }
        #expect(await transport.requests.isEmpty)
    }
    @Test func rejectsExpiredCookieAndDisabledAuthentication() async throws {
        let origin = try ServerOrigin("https://server.test")
        let identity = ProfileIdentity(origin: origin, username: "alice")
        let expired = SavedAuthentication(profile: identity, name: "session_test-runtime", value: "fixture", expires: Date(timeIntervalSince1970: 0))
        let transport = ScriptTransport([loginResponses()[2]])
        let restored = APIClient(origin: origin, transport: transport)
        await #expect(throws: ClientError.requiresLogin) { try await restored.restore(expired, for: identity) }
        #expect(await transport.requests.isEmpty)
        let valid = SavedAuthentication(profile: identity, name: "session_test-runtime", value: "fixture", expires: nil)
        await #expect(throws: ClientError.unauthenticatedServer) { try await restored.restore(valid, for: identity) }
        await #expect(throws: ClientError.requiresLogin) { try await restored.socketSession() }
    }
    @Test func rejectedSessionNeverReplaysCredentialsOrCommands() async throws {
        let origin = try ServerOrigin("https://server.test")
        let identity = ProfileIdentity(origin: origin, username: "alice")
        let saved = SavedAuthentication(profile: identity, name: "session_test-runtime", value: "fixture", expires: nil)
        let transport = ScriptTransport([loginResponses()[0], HTTPResponse(data: Data(), status: 401)])
        let client = APIClient(origin: origin, transport: transport)
        await #expect(throws: ClientError.requiresLogin) { try await client.restore(saved, for: identity) }
        await #expect(throws: ClientError.requiresLogin) { try await client.socketSession() }
        #expect(await transport.requests.allSatisfy { $0.httpMethod == "GET" })
    }
    @Test func backgroundRecoveryRetainsGeneratedReplyAndRejectsStaleEvents() throws {
        var state = SyncReducer()
        state.select(context: "synthetic-chat")
        var json = try #require(JSONSerialization.jsonObject(with: fixture("full")) as? [String: Any])
        json["logs"] = [["no":0,"type":"response","content":"```a2ui\n[{\"version\":\"v0.9\"}]\n```"]]
        let initial = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: json))
        _ = state.apply(snapshot: initial, generation: state.generation, full: true)
        let oldGeneration = state.generation
        let logs = state.logs
        let logGUID = state.logGUID
        state.invalidateForRecovery()
        #expect(state.logs.map(\.content) == logs.map(\.content))
        #expect(state.logGUID == logGUID)
        #expect(state.request.logFrom == 0)
        #expect(state.apply(snapshot: initial, generation: oldGeneration, full: true) == .ignored)
        #expect(state.apply(snapshot: initial, generation: state.generation, full: true) == .applied)
    }

    @Test func explicitDisconnectInvalidatesInFlightRestorationBeforeCookieRequest() async throws {
        let origin = try ServerOrigin("https://server.test")
        let profile = ProfileIdentity(origin: origin, username: "alice")
        let saved = SavedAuthentication(profile: profile, name: "session_test-runtime", value: "fixture", expires: nil)
        let transport = DelayedBootstrapTransport()
        let client = APIClient(origin: origin, transport: transport)
        let restore = Task { try await client.restore(saved, for: profile) }
        while await transport.count == 0 { await Task.yield() }
        await client.disconnect()
        await transport.release()
        await #expect(throws: ClientError.disconnected) { try await restore.value }
        #expect(await transport.count == 1)
        await #expect(throws: ClientError.requiresLogin) { try await client.socketSession() }
    }

}


private actor DelayedBootstrapTransport: HTTPTransport {
    var count = 0
    private var continuation: CheckedContinuation<HTTPResponse, Never>?
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        count += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        continuation?.resume(returning: HTTPResponse(data: Data(), status: 401))
        continuation = nil
    }
}
