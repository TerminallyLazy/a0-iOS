import Foundation
import Testing
import A0Core
@testable import A0GenerativeUI

func jevEntry(_ text: String, no: Int = 1, type: String = "response") throws -> LogEntry {
    let data = try JSONSerialization.data(withJSONObject:["no":no,"type":type,"content":text])
    return try JSONDecoder().decode(LogEntry.self,from:data)
}
func jevEnvelope(surface: String = GenerativeGuide.richExample, id: String = "overview", version: Int = 1) throws -> String {
    let object: [String:Any] = ["version":version,"intent":"Show a combined overview","candidates":[["id":id,"description":"Weather and trend overview","surface":try JSONSerialization.jsonObject(with:Data(surface.utf8))]]]
    return "Readable fallback.\n```a2ui-candidates\n" + String(decoding:try JSONSerialization.data(withJSONObject:object),as:UTF8.self) + "\n```"
}
actor JevTestCredentials: CredentialStoring {
    var records:[ProfileIdentity:String] = [:]
    var fails = false
    func setFailure() { fails = true }
    func password(for p:ProfileIdentity) throws -> String? { if fails { throw CredentialError.unavailable }; return records[p] }
    func save(_ value:String,for p:ProfileIdentity) throws { if fails { throw CredentialError.unavailable }; records[p] = value }
    func remove(_ p:ProfileIdentity) throws { if fails { throw CredentialError.unavailable }; records[p] = nil }
}
func jevProfile(_ username:String = "one") throws -> ProfileIdentity { try ProfileIdentity(origin:ServerOrigin("https://example.com"),username:username) }

struct JevContractTests {
    @Test func candidatePreservesOriginalAndMinimizesProjection() throws {
        let reply = try #require(JevCandidates.extract(try jevEntry(jevEnvelope())))
        #expect(reply.prose == "Readable fallback.")
        #expect(reply.complete)
        let batch = try reply.validated()
        #expect(batch.candidates.count == 1)
        #expect(try GeneratedDocument.validate(batch.candidates[0].source).surfaceID == "overview")
        let wire = String(decoding:try batch.requestData(),as:UTF8.self)
        #expect(wire.contains("Markdown"))
        for excluded in ["Bloomington","weather.gov","temperature","images.example.com","72"] { #expect(!wire.contains(excluded)) }
    }
    @Test func userToolAndNestedExamplesDoNotOptIn() throws {
        for type in ["user","tool","util"] { #expect(JevCandidates.extract(try jevEntry(jevEnvelope(),type:type)) == nil) }
        #expect(JevCandidates.extract(try jevEntry("````markdown\n" + jevEnvelope() + "\n````")) == nil)
    }
    @Test func malformedAndIncompleteKeepProse() throws {
        let incomplete = try #require(JevCandidates.extract(try jevEntry("Fallback\n```a2ui-candidates\n{")))
        #expect(incomplete.prose == "Fallback")
        #expect(!incomplete.complete)
        #expect(throws:(any Error).self) { try incomplete.validated() }
        for value in ["Fallback\n```a2ui-candidates\n{}\n```",try jevEnvelope(version:2),try jevEnvelope(id:"Markdown"),try jevEnvelope(surface:"[]")] {
            let reply = try #require(JevCandidates.extract(try jevEntry(value)))
            #expect(!reply.prose.isEmpty)
            #expect(throws:(any Error).self) { try reply.validated() }
        }
    }
    @Test func noProseTooLargeAndDuplicateEnvelopesRejected() throws {
        for text in [try jevEnvelope().replacingOccurrences(of:"Readable fallback.",with:""),try jevEnvelope()+"\n"+jevEnvelope(),"Fallback\n```a2ui-candidates\n"+String(repeating:"x",count:65537)+"\n```"] {
            let reply = try #require(JevCandidates.extract(try jevEntry(text)))
            #expect(throws:(any Error).self) { try reply.validated() }
        }
    }
    @Test func requestAndResponseChoiceBoundaries() throws {
        let batch = try #require(JevCandidates.extract(try jevEntry(jevEnvelope()))).validated()
        let data = Data(#"{"model":"jev-1.13.0","answers":{"presentation":{"type":"choice","choice":"overview","confidence":0.94}}}"#.utf8)
        #expect(try JevChoice.decode(data,eligible:batch.ids).candidateID == "overview")
        for bad in [data.replacing("overview","unknown"),data.replacing("choice\",\"choice","score\",\"choice"),Data("{}".utf8)] {
            #expect(throws:(any Error).self) { try JevChoice.decode(bad,eligible:batch.ids) }
        }
    }
}
private extension Data { func replacing(_ old:String,_ new:String)->Data { Data(String(decoding:self,as:UTF8.self).replacingOccurrences(of:old,with:new).utf8) } }
struct JevCredentialTests {
    @Test func saveDoesNotEnableAndProfilesStaySeparate() async throws {
        let backend = JevTestCredentials(), store = JevSettingsStore(credentials:backend)
        let p = try jevProfile(), other = try jevProfile("other")
        try await store.saveKey("synthetic-key",for:p)
        #expect(try await store.status(for:p) == JevSettingsStatus(configured:true,enabled:false))
        #expect(try await store.keyIfEnabled(for:p) == nil)
        try await store.setEnabled(true,for:p)
        #expect(try await store.keyIfEnabled(for:p) == "synthetic-key")
        #expect(try await store.keyIfEnabled(for:other) == nil)
        try await store.saveKey("replacement",for:p)
        #expect(try await store.keyIfEnabled(for:p) == nil)
        try await store.remove(p)
        #expect(try await store.status(for:p).configured == false)
    }
    @Test func emptyKeysAndFailedStorageNeverReportSuccess() async throws {
        let backend = JevTestCredentials(), store = JevSettingsStore(credentials:backend), p = try jevProfile()
        await #expect(throws:(any Error).self) { try await store.saveKey(" \n",for:p) }
        await #expect(throws:(any Error).self) { try await store.setEnabled(true,for:p) }
        await backend.setFailure()
        await #expect(throws:(any Error).self) { try await store.saveKey("synthetic",for:p) }
    }
}
struct JevReceiptTests {
    @Test func persistentAttemptsCannotReplayAndContainNoPayload() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let journal = JevAttemptJournal(directory:dir)
        #expect(try await journal.begin(identity:"opaque-reply",payload:Data("private synthetic prompt".utf8)))
        #expect(try await journal.begin(identity:"opaque-reply",payload:Data("changed".utf8)) == false)
        let restored = JevAttemptJournal(directory:dir)
        #expect(try await restored.begin(identity:"opaque-reply",payload:Data()) == false)
        let text = try String(contentsOf:dir.appendingPathComponent("attempts.json"),encoding:.utf8)
        #expect(!text.contains("private synthetic prompt"))
        #expect(!text.contains("opaque-reply"))
    }
    @Test func invalidJournalFailsClosed() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        try Data("invalid".utf8).write(to:dir.appendingPathComponent("attempts.json"))
        await #expect(throws:(any Error).self) { try await JevAttemptJournal(directory:dir).begin(identity:"new",payload:Data()) }
    }
}

struct JevTransportTests {
    func client() -> JevClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [JevFixtureProtocol.self]
        return JevClient(configuration:configuration)
    }
    @Test func authenticatedChoiceUsesOnlyTypeSafeCredential() async throws {
        let batch = try #require(JevCandidates.extract(try jevEntry(jevEnvelope()))).validated()
        #expect(try await client().choose(batch,key:"synthetic-ok").candidateID == "overview")
    }
    @Test func statusMalformedOversizeAndCancellationFail() async throws {
        let batch = try #require(JevCandidates.extract(try jevEntry(jevEnvelope()))).validated()
        for key in ["401","403","429","500","redirect","malformed","oversize","unknown"] {
            await #expect(throws:(any Error).self) { try await client().choose(batch,key:key) }
        }
        let task = Task { try await client().choose(batch,key:"synthetic-ok") }
        task.cancel()
        await #expect(throws:(any Error).self) { try await task.value }
    }
}
private final class JevFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request:URLRequest)->Bool { true }
    override class func canonicalRequest(for request:URLRequest)->URLRequest { request }
    override func startLoading() {
        let key = request.value(forHTTPHeaderField:"Authorization")?.replacingOccurrences(of:"Bearer ",with:"") ?? ""
        guard request.url?.absoluteString == "https://api.typesafe.ai/v1/systemone", request.httpMethod == "POST",
              request.value(forHTTPHeaderField:"Cookie") == nil, request.value(forHTTPHeaderField:"X-CSRF-Token") == nil else {
            client?.urlProtocol(self,didFailWithError:URLError(.badURL)); return
        }
        let status = Int(key) ?? (key == "redirect" ? 302 : 200)
        let response = HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        let body = key == "malformed" ? "{}" : key == "oversize" ? String(repeating:"x",count:65537) : "{\"model\":\"jev-1.13.0\",\"answers\":{\"presentation\":{\"type\":\"choice\",\"choice\":\"\(key == "unknown" ? "foreign" : "overview")\"}}}"
        client?.urlProtocol(self,didLoad:Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

actor JevTestChooser: JevChoosing {
    var calls = 0
    let slow: Bool
    init(slow:Bool = false) { self.slow = slow }
    func count()->Int { calls }
    func choose(_ batch:JevBatch,key:String) async throws -> JevChoice {
        calls += 1
        if slow { try? await Task.sleep(for:.milliseconds(80)) }
        return JevChoice(candidateID:"overview",model:"fixture")
    }
}
@MainActor struct JevCoordinatorTests {
    func make(_ chooser:JevTestChooser)->(JevCoordinator,URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (JevCoordinator(chooser:chooser,journal:JevAttemptJournal(directory:dir)),dir)
    }
    @Test func baselineSkippedAndRepeatedSnapshotsSubmitOnce() async throws {
        let chooser = JevTestChooser(), (coordinator,dir) = make(chooser)
        defer { try? FileManager.default.removeItem(at:dir) }
        let historical = try jevEntry(jevEnvelope()), fresh = try jevEntry(jevEnvelope(),no:2)
        coordinator.arm(scope:"profile-chat-epoch",baseline:[historical],key:"synthetic")
        coordinator.observe([historical,fresh],scope:"profile-chat-epoch")
        await coordinator.waitForPending()
        coordinator.observe([historical,fresh],scope:"profile-chat-epoch")
        await coordinator.waitForPending()
        #expect(await chooser.count() == 1)
        #expect(coordinator.selected[1] == nil)
        #expect(coordinator.selected[2]?.source.contains("Forecast") == true)
    }
    @Test func lateAnswerAfterCancellationOrReplacementCannotRender() async throws {
        for changeSource in [false,true] {
            let chooser = JevTestChooser(slow:true), (coordinator,dir) = make(chooser)
            defer { try? FileManager.default.removeItem(at:dir) }
            let entry = try jevEntry(jevEnvelope())
            coordinator.arm(scope:"a",baseline:[],key:"synthetic")
            coordinator.observe([entry],scope:"a")
            if changeSource { coordinator.observe([try jevEntry(jevEnvelope().replacingOccurrences(of:"Readable fallback.",with:"Changed prose."))],scope:"a") }
            else { coordinator.observe([entry],scope:"b") }
            await coordinator.waitForPending()
            #expect(coordinator.selected.isEmpty)
            #expect(await chooser.count() <= 1)
        }
    }
    @Test func incompleteReplyWaitsAndInvalidReplyNeverSubmits() async throws {
        let chooser = JevTestChooser(), (coordinator,dir) = make(chooser)
        defer { try? FileManager.default.removeItem(at:dir) }
        coordinator.arm(scope:"a",baseline:[],key:"synthetic")
        coordinator.observe([try jevEntry("Prose\n```a2ui-candidates\n{")],scope:"a")
        await coordinator.waitForPending()
        #expect(await chooser.count() == 0)
        coordinator.observe([try jevEntry(jevEnvelope())],scope:"a")
        await coordinator.waitForPending()
        #expect(await chooser.count() == 1)
        coordinator.observe([try jevEntry("Prose\n```a2ui-candidates\n{}\n```",no:2)],scope:"a")
        await coordinator.waitForPending()
        #expect(await chooser.count() == 1)
    }
}
