import Foundation
import Testing
@testable import A0Core

private func profile(_ user: String = "fixture") throws -> ProfileIdentity {
    ProfileIdentity(origin: try ServerOrigin("https://fixture.test"), username: user)
}
private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
@Test func archiveSurvivesNewRepositoryAndSeparatesAccounts() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try profile(), second = try profile("other")
    let store = try SessionRepository(directory: root)
    let archive = SessionArchive(profile: first, revision: 1, selectedContext: "chat-a", drafts: ["chat-a":"Hello 世界 👋"], deliveries: [])
    try await store.save(archive)
    let fresh = try SessionRepository(directory: root)
    #expect(try await fresh.load(first) == archive)
    #expect(try await fresh.load(second) == nil)
    let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
    #expect(names.count == 1)
    #expect(!names[0].contains("fixture"))
}
@Test func staleArchiveCannotOverwriteNewerDraft() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionRepository(directory: root), key = try profile()
    try await store.save(SessionArchive(profile: key, revision: 2, drafts: ["":"Newest"]))
    try await store.save(SessionArchive(profile: key, revision: 1, drafts: ["":"Old"]))
    #expect(try await store.load(key)?.drafts[""] == "Newest")
}
@Test func corruptArchiveIsNotSilentlyReplaced() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionRepository(directory: root), key = try profile()
    try await store.save(SessionArchive(profile: key, revision: 1))
    let file = try #require(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
    try Data("broken".utf8).write(to: file)
    let fresh = try SessionRepository(directory: root)
    await #expect(throws: PersistenceError.unreadableArchive) { try await fresh.load(key) }
    await #expect(throws: PersistenceError.unreadableArchive) { try await fresh.save(SessionArchive(profile:key, revision:2)) }
    #expect(try String(contentsOf: file, encoding: .utf8) == "broken")
}
@Test func futureSchemaCannotBeOverwritten() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionRepository(directory: root), key = try profile()
    try await store.save(SessionArchive(profile:key, revision:1))
    let file = try #require(FileManager.default.contentsOfDirectory(at:root, includingPropertiesForKeys:nil).first)
    var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:file)) as? [String:Any])
    json["version"] = 99
    try JSONSerialization.data(withJSONObject: json).write(to:file)
    let fresh = try SessionRepository(directory:root)
    await #expect(throws: PersistenceError.unsupportedVersion) { try await fresh.load(key) }
}
@Test func diskWriteFailureDoesNotPretendToSave() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionRepository(directory:root), key = try profile()
    try FileManager.default.removeItem(at:root)
    try Data().write(to:root)
    await #expect(throws:(any Error).self) { try await store.save(SessionArchive(profile:key,revision:1)) }
}
@Test func archiveHasPrivatePermissionsAndExcludedBackup() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionRepository(directory: root)
    try await store.save(SessionArchive(profile:try profile(),revision:1))
    let file = try #require(FileManager.default.contentsOfDirectory(at:root, includingPropertiesForKeys:nil).first)
    let attributes = try FileManager.default.attributesOfItem(atPath:file.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    #expect(try file.resourceValues(forKeys:[.isExcludedFromBackupKey]).isExcludedFromBackup == true)
}
actor FailingSessionStore: SessionStoring {
    func load(_ profile: ProfileIdentity) throws -> SessionArchive? { nil }
    func save(_ archive: SessionArchive) throws { throw PersistenceError.writeFailed }
}
@MainActor @Test func diskFailurePreventsNetworkMutationAndKeepsDraft() async throws {
    let api = ChatDouble(), key = try profile()
    let chat = try await ChatSession.restoring(api:api, profile:key, store:FailingSessionStore())
    chat.draft = "Must save before send"
    await chat.send()
    #expect(await api.calls.isEmpty)
    #expect(chat.draft == "Must save before send")
    #expect(chat.storageState == .failed)
}
@MainActor @Test func draftsAndSelectionSurviveSessionRecreation() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionRepository(directory:root), key = try profile(), api = ChatDouble()
    let chat = try await ChatSession.restoring(api:api,profile:key,store:store)
    chat.select("a"); chat.draft = "Draft A"
    chat.select("b"); chat.draft = "Draft B"
    try await chat.flush()
    let restored = try await ChatSession.restoring(api:api,profile:key,store:try SessionRepository(directory:root))
    #expect(restored.selectedContext == "b")
    #expect(restored.draft == "Draft B")
    restored.select("a"); #expect(restored.draft == "Draft A")
    try await restored.flush()
}
@MainActor @Test func terminatedSendRestoresUncertainAndNeverReplays() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionRepository(directory:root), key = try profile(), api = ChatDouble(.held)
    let chat = try await ChatSession.restoring(api:api,profile:key,store:store)
    chat.select("a"); chat.draft = "Only once"
    let sending = Task { await chat.send() }
    await api.waitForSend()
    let freshAPI = ChatDouble()
    let restored = try await ChatSession.restoring(api:freshAPI,profile:key,store:try SessionRepository(directory:root))
    #expect(restored.deliveries.first?.status == .uncertain)
    #expect(restored.draft == "Only once")
    await restored.send()
    #expect(await freshAPI.calls.isEmpty)
    chat.suspend(); await api.release(); await sending.value
    try await chat.flush()
}
@MainActor @Test func savedAcknowledgmentDoesNotRestoreAsSendableDraft() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
    let key = try profile(), api = ChatDouble()
    let chat = try await ChatSession.restoring(api:api,profile:key,store:try SessionRepository(directory:root))
    chat.draft = "Acknowledged"
    await chat.send(); try await chat.flush()
    let restored = try await ChatSession.restoring(api:api,profile:key,store:try SessionRepository(directory:root))
    #expect(restored.draft.isEmpty)
    #expect(restored.deliveries.first?.status == .accepted)
}

actor RecoveringStore: SessionStoring {
    var blocked = true
    var archive: SessionArchive?
    func load(_ profile: ProfileIdentity) -> SessionArchive? { archive }
    func save(_ archive: SessionArchive) throws {
        if blocked { throw PersistenceError.writeFailed }
        self.archive = archive
    }
    func unblock() { blocked = false }
}
@MainActor @Test func retrySavingRecoversWithoutSendingAnything() async throws {
    let store = RecoveringStore(), api = ChatDouble()
    let chat = try await ChatSession.restoring(api:api,profile:try profile(),store:store)
    chat.draft = "Save retry"
    await #expect(throws:PersistenceError.writeFailed) { try await chat.flush() }
    await store.unblock(); await chat.retrySave()
    #expect(chat.storageState == .saved)
    #expect(await store.archive?.drafts[""] == "Save retry")
    #expect(await api.calls.isEmpty)
}
@MainActor @Test func rapidDraftEditsPersistTheLatestValue() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at:root) }
    let key = try profile()
    let chat = try await ChatSession.restoring(api:ChatDouble(),profile:key,store:try SessionRepository(directory:root))
    for index in 0..<50 { chat.draft = "Draft \(index)" }
    try await chat.flush()
    let fresh = try SessionRepository(directory:root)
    #expect(try await fresh.load(key)?.drafts[""] == "Draft 49")
}

actor CreationCheckpointStore: SessionStoring {
    var archive: SessionArchive?
    func load(_ profile: ProfileIdentity) -> SessionArchive? { archive }
    func save(_ archive: SessionArchive) throws {
        if archive.deliveries.last?.status == .sending { throw PersistenceError.writeFailed }
        self.archive = archive
    }
}
@MainActor @Test func failedPostCreationCheckpointNeverSubmitsMessage() async throws {
    let store = CreationCheckpointStore(), api = ChatDouble(), key = try profile()
    let chat = try await ChatSession.restoring(api:api,profile:key,store:store)
    chat.draft = "Create then stop on disk failure"
    await chat.send()
    let delivery = try #require(chat.deliveries.first)
    #expect(await api.calls == [.create(delivery.context)])
    #expect(chat.draft == "Create then stop on disk failure")
    #expect(chat.storageState == .failed)
    let restored = try await ChatSession.restoring(api:api,profile:key,store:store)
    #expect(restored.deliveries.first?.status == .uncertain)
    #expect(restored.canSend == false)
}
@Test func archiveFromAnotherAccountCannotBeLoaded() async throws {
    let root = try directory(); defer { try? FileManager.default.removeItem(at:root) }
    let key = try profile(), other = try profile("other")
    let store = try SessionRepository(directory:root)
    try await store.save(SessionArchive(profile:key,revision:1))
    let file = try #require(FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil).first)
    try JSONEncoder().encode(SessionArchive(profile:other,revision:1,drafts:["":"Wrong account"])).write(to:file)
    let fresh = try SessionRepository(directory:root)
    await #expect(throws:PersistenceError.unreadableArchive) { try await fresh.load(key) }
}
