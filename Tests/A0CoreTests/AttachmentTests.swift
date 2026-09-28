import Foundation
import Testing
@testable import A0Core

@Test func attachmentRejectsHeaderInjectionAndOversizeData() throws {
    #expect(throws: AttachmentError.invalidFile) { try ChatAttachment(name: "bad\r\nX-Evil: true.pdf", contentType: "application/pdf", data: Data([1])) }
    #expect(throws: AttachmentError.invalidFile) { try ChatAttachment(name: "file.pdf", contentType: "application/pdf\r\nX-Evil: true", data: Data([1])) }
    #expect(throws: AttachmentError.tooLarge) { try ChatAttachment(name: "large.bin", contentType: "application/octet-stream", data: Data(count: ChatAttachment.maximumBytes + 1)) }
}
@Test func multipartPreservesBytesAndEscapesFilename() throws {
    let file = try ChatAttachment(name: "../report\".pdf", contentType: "application/pdf", data: Data([0, 255, 1]))
    let body = try AttachmentMultipart(fields: [("text", "Hello 世界"), ("context", "chat-a"), ("message_id", "id-a")], files: [file], fileField: "attachments")
    #expect(body.contentType.hasPrefix("multipart/form-data; boundary="))
    #expect(body.data.range(of: Data([0, 255, 1])) != nil)
    let text = String(decoding: body.data, as: UTF8.self)
    #expect(text.contains("name=\"attachments\"; filename=\""))
    #expect(text.contains("Hello 世界"))
    #expect(!file.uploadName.contains("/"))
    #expect(!file.uploadName.contains("\""))
}

private actor AttachmentAPI: ChatAPI {
    var calls: [String] = []
    var received: [ChatAttachment] = []
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }
    func createChat(id: String) async throws -> String { calls.append("create"); return id }
    func sendText(context: String, text: String, messageID: String, queued: Bool) async throws { calls.append("text") }
    func sendAttachments(context: String, text: String, messageID: String, queued: Bool, attachments: [ChatAttachment]) async throws {
        calls.append(queued ? "queue" : "attachments"); received = attachments
        if fails { throw URLError(.timedOut) }
    }
}
@MainActor @Test func attachmentOnlyDraftCreatesAndSendsOnce() async throws {
    let api = AttachmentAPI(), chat = ChatSession(api: AttachmentAPI())
    chat.resume(api: api)
    let file = try ChatAttachment(name: "test.pdf", contentType: "application/pdf", data: Data([1,2,3]))
    try await chat.addAttachments([file])
    #expect(chat.canSend)
    #expect(await api.calls.isEmpty)
    await chat.send()
    #expect(await api.calls == ["create", "attachments"])
    #expect(await api.received == [file])
    #expect(chat.attachments.isEmpty)
    #expect(chat.deliveries.first?.attachmentIDs == [file.id])
}
@MainActor @Test func attachmentDraftsPersistIsolatedAndUnknownSendNeverReplays() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let profile = ProfileIdentity(origin: try ServerOrigin("https://fixture.test"), username: "one")
    let repository = try SessionRepository(directory: dir)
    let api = AttachmentAPI(fails: true)
    let chat = try await ChatSession.restoring(api: api, profile: profile, store: repository)
    chat.select("a")
    let file = try ChatAttachment(name: "sample.txt", contentType: "text/plain", data: Data("private fixture".utf8))
    try await chat.addAttachments([file])
    chat.select("b"); #expect(chat.attachments.isEmpty)
    chat.select("a"); await chat.send(); try await chat.flush()
    #expect(chat.deliveries.first?.status == .uncertain)
    let nextAPI = AttachmentAPI()
    let restored = try await ChatSession.restoring(api: nextAPI, profile: profile, store: try SessionRepository(directory: dir))
    #expect(restored.attachments == [file.staged])
    await restored.send(); #expect(await nextAPI.calls.isEmpty)
    let other = ProfileIdentity(origin: try ServerOrigin("https://fixture.test"), username: "two")
    #expect(try await repository.load(other) == nil)
    await #expect(throws: (any Error).self) { try await repository.attachment(file.staged, for: other) }
    let jsonFile = try #require(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).first { $0.pathExtension == "json" })
    let archive = try String(contentsOf: jsonFile, encoding: .utf8)
    #expect(!archive.contains(file.data.base64EncodedString()))
    #expect(!archive.contains("private fixture"))
    #expect(try await repository.attachment(file.staged, for: profile) == file)
}
@MainActor @Test func attachingOverLimitAndStorageFailureCannotUpload() async throws {
    let chat = ChatSession(api: AttachmentAPI())
    let files = try (0..<6).map { try ChatAttachment(name: "\($0).txt", contentType: "text/plain", data: Data([1])) }
    await #expect(throws: AttachmentError.tooMany) { try await chat.addAttachments(files) }
    #expect(chat.attachments.isEmpty)
    let api = AttachmentAPI()
    let profile = ProfileIdentity(origin: try ServerOrigin("https://fixture.test"), username: "fixture")
    let failed = try await ChatSession.restoring(api: api, profile: profile, store: FailingSessionStore())
    await #expect(throws: AttachmentError.unsupported) { try await failed.addAttachments([files[0]]) }
    await failed.send(); #expect(await api.calls.isEmpty)
}
@Test func authenticatedMultipartUsesOriginalSecurityAndQueueContract() async throws {
    let file = try ChatAttachment(name: "sample.txt", contentType: "text/plain", data: Data("synthetic attachment".utf8))
    let responses = loginResponses() + [
        HTTPResponse(data: Data(#"{"context":"chat-a"}"#.utf8), status: 200, headers: ["Content-Type":"application/json"]),
        HTTPResponse(data: try JSONEncoder().encode(["filenames": [file.uploadName]]), status: 200, headers: ["Content-Type":"application/json"]),
        HTTPResponse(data: Data(#"{"ok":true,"item_id":"queued-id"}"#.utf8), status: 200, headers: ["Content-Type":"application/json"])
    ]
    let transport = ScriptTransport(responses)
    let client = APIClient(origin: try ServerOrigin("https://fixture.test"), transport: transport)
    try await client.connect(username: "fixture", password: "synthetic")
    try await client.sendAttachments(context: "chat-a", text: "caption", messageID: "msg-id", queued: false, attachments: [file])
    try await client.sendAttachments(context: "chat-a", text: "caption", messageID: "queued-id", queued: true, attachments: [file])
    let calls = await transport.requests
    #expect(calls.suffix(3).map { $0.url!.path } == ["/api/message_async", "/api/upload", "/api/message_queue_add"])
    for call in calls.suffix(3) {
        #expect(call.value(forHTTPHeaderField: "X-CSRF-Token") == "synthetic-csrf")
        #expect(call.value(forHTTPHeaderField: "Origin") == "https://fixture.test")
        #expect(call.value(forHTTPHeaderField: "Cookie")?.contains("session_test-runtime=synthetic-session") == true)
    }
    let body = try #require(calls.last?.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(payload["attachments"] as? [String] == [file.uploadName])
    #expect(payload["item_id"] as? String == "queued-id")
}
@Test func rejectedUploadDoesNotQueueOrReplay() async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data: Data(), status: 403)])
    let client = APIClient(origin: try ServerOrigin("https://fixture.test"), transport: transport)
    try await client.connect(username: "fixture", password: "synthetic")
    let file = try ChatAttachment(name: "sample.txt", contentType: "text/plain", data: Data([1]))
    await #expect(throws: ClientError.csrfRejected) { try await client.sendAttachments(context: "a", text: "", messageID: "id", queued: true, attachments: [file]) }
    #expect(await transport.requests.count == 4)
}

private actor HeldAttachmentStore: SessionStoring {
    var archive: SessionArchive?
    var files: [UUID: ChatAttachment] = [:]
    var held = false
    var continuation: CheckedContinuation<Void, Never>?
    var observers: [CheckedContinuation<Void, Never>] = []
    func load(_ profile: ProfileIdentity) -> SessionArchive? { archive }
    func save(_ archive: SessionArchive) { self.archive = archive }
    func stage(_ attachment: ChatAttachment, for profile: ProfileIdentity) async {
        if held {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                for observer in observers { observer.resume() }; observers = []
            }
        }
        files[attachment.id] = attachment
    }
    func attachment(_ reference: StagedAttachment, for profile: ProfileIdentity) async throws -> ChatAttachment { try #require(files[reference.id]) }
    func removeAttachment(_ id: UUID, for profile: ProfileIdentity) async throws { files[id] = nil }
    func hold() { held = true }
    func wait() async { if continuation != nil { return }; await withCheckedContinuation { observers.append($0) } }
    func release() { held = false; continuation?.resume(); continuation = nil }
}
@MainActor @Test func removingDuringImportCannotResurrectFileAndSendWaitsForImport() async throws {
    let store = HeldAttachmentStore(), api = AttachmentAPI()
    let profile = ProfileIdentity(origin: try ServerOrigin("https://fixture.test"), username: "one")
    let chat = try await ChatSession.restoring(api: api, profile: profile, store: store)
    chat.select("a")
    let first = try ChatAttachment(name: "first.txt", contentType: "text/plain", data: Data([1]))
    let second = try ChatAttachment(name: "second.txt", contentType: "text/plain", data: Data([2]))
    try await chat.addAttachments([first]); await store.hold()
    let importing = Task { try await chat.addAttachments([second]) }
    await store.wait()
    chat.removeAttachment(first.id)
    await chat.send(); #expect(await api.calls.isEmpty)
    await store.release(); try await importing.value
    #expect(chat.attachments == [second.staged])
}
@MainActor @Test func changingOwnerContextDuringImportDiscardsNewFile() async throws {
    let store = HeldAttachmentStore()
    let profile = ProfileIdentity(origin: try ServerOrigin("https://fixture.test"), username: "one")
    let chat = try await ChatSession.restoring(api: AttachmentAPI(), profile: profile, store: store)
    chat.select("a"); await store.hold()
    let file = try ChatAttachment(name: "sample.txt", contentType: "text/plain", data: Data([1]))
    let importing = Task { try await chat.addAttachments([file]) }
    await store.wait(); chat.select("b"); await store.release()
    await #expect(throws: CancellationError.self) { try await importing.value }
    #expect(chat.attachments.isEmpty)
    chat.select("a"); #expect(chat.attachments.isEmpty)
    #expect(await store.files.isEmpty)
}

@Test func startupPrunesOnlyUnreferencedStagedFilesBeforeNewImports() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let profile = ProfileIdentity(origin: try ServerOrigin("https://fixture.test"), username: "one")
    let repository = try SessionRepository(directory: root)
    let kept = try ChatAttachment(name: "kept.txt", contentType: "text/plain", data: Data([1]))
    let orphan = try ChatAttachment(name: "orphan.txt", contentType: "text/plain", data: Data([2]))
    try await repository.stage(kept, for: profile)
    try await repository.save(SessionArchive(profile: profile, revision: 1, attachments: ["a": [kept.staged]]))
    try await repository.stage(orphan, for: profile)
    let fresh = try SessionRepository(directory: root)
    _ = try await fresh.load(profile)
    #expect(try await fresh.attachment(kept.staged, for: profile) == kept)
    await #expect(throws: (any Error).self) { try await fresh.attachment(orphan.staged, for: profile) }
    let pending = try ChatAttachment(name: "pending.txt", contentType: "text/plain", data: Data([3]))
    try await fresh.stage(pending, for: profile)
    _ = try await fresh.load(profile)
    #expect(try await fresh.attachment(pending.staged, for: profile) == pending)
}

@Test func attachmentUploadNamesMatchServerTrailingDotNormalization() throws {
    let file = try ChatAttachment(name:"notes...",contentType:"text/plain",data:Data([1]))
    #expect(!file.uploadName.hasSuffix("."))
}

@MainActor @Test func preparingAttachmentBytesBlocksSendUntilMatchingReservationEnds() async throws {
    let api = AttachmentAPI(), chat = ChatSession(api: AttachmentAPI())
    chat.resume(api: api); chat.select("a"); chat.draft = "Message with upcoming file"
    #expect(chat.canSend)
    let token = try #require(chat.beginAttachmentPreparation())
    #expect(!chat.canSend)
    await chat.send(); #expect(await api.calls.isEmpty)
    chat.endAttachmentPreparation(UUID()); #expect(!chat.canSend)
    chat.endAttachmentPreparation(token); #expect(chat.canSend)
}
@MainActor @Test func changedContextReleasesPreparationAndStaleCompletionCannotReleaseNewReservation() throws {
    let chat = ChatSession(api: AttachmentAPI()); chat.select("a"); chat.draft = "A"
    let old = try #require(chat.beginAttachmentPreparation())
    chat.select("b"); chat.draft = "B"
    #expect(chat.canSend)
    let fresh = try #require(chat.beginAttachmentPreparation())
    chat.endAttachmentPreparation(old); #expect(!chat.canSend)
    chat.endAttachmentPreparation(fresh); #expect(chat.canSend)
    _ = chat.beginAttachmentPreparation(); chat.suspend(); #expect(chat.canSend)
}
@Test func uploadFilenameMatchesServerTrailingDotNormalization() throws {
    let file = try ChatAttachment(name: "report...", contentType: "text/plain", data: Data([1]))
    #expect(!file.uploadName.hasSuffix("."))
    #expect(file.uploadName.hasSuffix("report"))
}
