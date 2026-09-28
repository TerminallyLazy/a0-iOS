import Foundation
import Testing
@testable import A0Core

private func saved(_ username: String = "fixture", host: String = "https://fixture.test") throws -> SavedProfile {
    SavedProfile(identity: ProfileIdentity(origin: try ServerOrigin(host), username:username), name:"My server")
}
private func profileDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
    return url
}
actor TestCredentials: CredentialStoring {
    var values: [ProfileIdentity:String] = [:]
    var fail = false
    func password(for profile: ProfileIdentity) throws -> String? {
        if fail { throw CredentialError.unavailable }
        return values[profile]
    }
    func save(_ password: String, for profile: ProfileIdentity) throws {
        if fail { throw CredentialError.unavailable }; values[profile] = password
    }
    func remove(_ profile: ProfileIdentity) throws {
        if fail { throw CredentialError.unavailable }; values[profile] = nil
    }
    func block() { fail = true }
}
@Test func profilesPersistWithoutPasswordsAndUpsertByIdentity() async throws {
    let root = try profileDirectory(); defer { try? FileManager.default.removeItem(at:root) }
    let store = try ProfileRepository(directory:root), credential = TestCredentials()
    let library = ProfileLibrary(profiles:store,credentials:credential)
    let profile = try saved()
    try await library.recordLogin(profile,password:"synthetic-secret-unique",rememberPassword:true)
    try await library.recordLogin(SavedProfile(identity:profile.identity,name:"Renamed"),password:"new-synthetic-secret",rememberPassword:true)
    let fresh = try ProfileRepository(directory:root)
    #expect(try await fresh.load().count == 1)
    #expect(try await fresh.load().first?.name == "Renamed")
    for file in try FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil) {
        #expect(!String(decoding:try Data(contentsOf:file),as:UTF8.self).contains("synthetic-secret"))
    }
    #expect(try await library.password(for:profile.identity) == "new-synthetic-secret")
}
@Test func optOutRemovesOnlyMatchingCredential() async throws {
    let root = try profileDirectory(); defer { try? FileManager.default.removeItem(at:root) }
    let library = ProfileLibrary(profiles:try ProfileRepository(directory:root),credentials:TestCredentials())
    let first = try saved(), second = try saved("other"), remote = try saved(host:"https://another.test")
    for profile in [first,second,remote] { try await library.recordLogin(profile,password:"synthetic",rememberPassword:true) }
    try await library.recordLogin(first,password:"not-stored",rememberPassword:false)
    #expect(try await library.password(for:first.identity) == nil)
    #expect(try await library.password(for:second.identity) == "synthetic")
    #expect(try await library.password(for:remote.identity) == "synthetic")
}
@Test func forgetPasswordKeepsProfileWhileRemovalDeletesBoth() async throws {
    let root = try profileDirectory(); defer { try? FileManager.default.removeItem(at:root) }
    let library = ProfileLibrary(profiles:try ProfileRepository(directory:root),credentials:TestCredentials()), profile = try saved()
    try await library.recordLogin(profile,password:"synthetic",rememberPassword:true)
    try await library.forgetPassword(profile.identity)
    #expect(try await library.load() == [profile])
    #expect(try await library.password(for:profile.identity) == nil)
    try await library.remove(profile.identity)
    #expect(try await library.load().isEmpty)
}
@Test func unavailableKeychainDoesNotSilentlyRemoveProfile() async throws {
    let root = try profileDirectory(); defer { try? FileManager.default.removeItem(at:root) }
    let credential = TestCredentials(), profile = try saved()
    let library = ProfileLibrary(profiles:try ProfileRepository(directory:root),credentials:credential)
    try await library.recordLogin(profile,password:"synthetic",rememberPassword:true)
    await credential.block()
    await #expect(throws:CredentialError.unavailable) { try await library.password(for:profile.identity) }
    await #expect(throws:CredentialError.unavailable) { try await library.remove(profile.identity) }
    #expect(try await library.load() == [profile])
}
@Test func corruptProfilesArePreservedOnAttemptedSave() async throws {
    let root = try profileDirectory(); defer { try? FileManager.default.removeItem(at:root) }
    let store = try ProfileRepository(directory:root)
    try await store.save(saved())
    let file = try #require(FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil).first)
    try Data("corrupt".utf8).write(to:file)
    let fresh = try ProfileRepository(directory:root)
    await #expect(throws:PersistenceError.unreadableArchive) { try await fresh.save(saved("other")) }
    #expect(try String(contentsOf:file,encoding:.utf8) == "corrupt")
}
@Test func profilesRejectFutureVersion() async throws {
    let root = try profileDirectory(); defer { try? FileManager.default.removeItem(at:root) }
    let store = try ProfileRepository(directory:root)
    try await store.save(saved())
    let file = try #require(FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil).first)
    var json = try #require(JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any])
    json["version"] = 999
    try JSONSerialization.data(withJSONObject:json).write(to:file)
    let fresh = try ProfileRepository(directory:root)
    await #expect(throws:PersistenceError.unsupportedVersion) { try await fresh.load() }
}

@Test func profileWriteFailureKeepsLastCommittedMetadata() async throws {
    let root = try profileDirectory(); defer { try? FileManager.default.removeItem(at:root) }
    let store = try ProfileRepository(directory:root), profile = try saved()
    try await store.save(profile)
    let file = root.appendingPathComponent("profiles.json")
    try FileManager.default.removeItem(at:file)
    try FileManager.default.createDirectory(at:file,withIntermediateDirectories:false)
    await #expect(throws:PersistenceError.writeFailed) { try await store.save(saved("other")) }
    #expect(try await store.load() == [profile])
}
