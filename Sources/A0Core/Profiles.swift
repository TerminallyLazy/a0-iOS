import Foundation

public struct SavedProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: ProfileIdentity { identity }
    public let identity: ProfileIdentity
    public let name: String
    public let localDevelopment: Bool
    public init(identity: ProfileIdentity, name: String, localDevelopment: Bool = false) {
        self.identity = identity
        let trimmed = name.trimmingCharacters(in:.whitespacesAndNewlines)
        self.name = trimmed.isEmpty ? identity.origin : trimmed
        self.localDevelopment = localDevelopment
    }
}
public enum CredentialError: Error, Sendable { case unavailable }
public protocol CredentialStoring: Sendable {
    func password(for profile: ProfileIdentity) async throws -> String?
    func save(_ password: String, for profile: ProfileIdentity) async throws
    func remove(_ profile: ProfileIdentity) async throws
}
public protocol ProfileStoring: Sendable {
    func load() async throws -> [SavedProfile]
    func save(_ profile: SavedProfile) async throws
    func remove(_ profile: ProfileIdentity) async throws
}

/// Metadata only. Credentials belong exclusively to CredentialStoring.
public actor ProfileRepository: ProfileStoring {
    private struct Archive: Codable { var version = 1; var profiles: [SavedProfile] }
    private let file: URL
    private var cache: [SavedProfile]?
    public init(directory: URL) throws {
        guard directory.isFileURL, directory.path != "/" else { throw PersistenceError.invalidDirectory }
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        var root = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],ofItemAtPath:root.path)
        #endif
        file = directory.appendingPathComponent("profiles.json")
    }
    public func load() throws -> [SavedProfile] {
        if let cache { return cache }
        let data: Data
        do { data = try Data(contentsOf:file) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { cache = []; return [] }
        catch { throw PersistenceError.unreadableArchive }
        let archive: Archive
        do { archive = try JSONDecoder().decode(Archive.self,from:data) }
        catch { throw PersistenceError.unreadableArchive }
        guard archive.version == 1 else { throw PersistenceError.unsupportedVersion }
        guard Set(archive.profiles.map(\.identity)).count == archive.profiles.count else { throw PersistenceError.unreadableArchive }
        cache = archive.profiles; return archive.profiles
    }
    public func save(_ profile: SavedProfile) throws {
        var profiles = try load().filter { $0.identity != profile.identity }
        profiles.append(profile)
        try persist(profiles)
    }
    public func remove(_ profile: ProfileIdentity) throws {
        try persist(load().filter { $0.identity != profile })
    }
    private func persist(_ profiles: [SavedProfile]) throws {
        do {
            let data = try JSONEncoder().encode(Archive(profiles:profiles))
            #if os(iOS)
            try data.write(to:file,options:[.atomic,.completeFileProtection])
            #else
            try data.write(to:file,options:.atomic)
            #endif
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
            var url = file; var values = URLResourceValues(); values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            cache = profiles
        } catch { throw PersistenceError.writeFailed }
    }
}

public actor ProfileLibrary {
    private let profiles: any ProfileStoring
    private let credentials: any CredentialStoring
    public init(profiles: any ProfileStoring, credentials: any CredentialStoring) {
        self.profiles = profiles; self.credentials = credentials
    }
    public func load() async throws -> [SavedProfile] { try await profiles.load() }
    /// Call only after authentication succeeds. No network work happens here.
    public func recordLogin(_ profile: SavedProfile, password: String, rememberPassword: Bool) async throws {
        try await profiles.save(profile)
        if rememberPassword { try await credentials.save(password,for:profile.identity) }
        else { try await credentials.remove(profile.identity) }
    }
    public func password(for profile: ProfileIdentity) async throws -> String? { try await credentials.password(for:profile) }
    public func forgetPassword(_ profile: ProfileIdentity) async throws { try await credentials.remove(profile) }
    public func remove(_ profile: ProfileIdentity) async throws {
        // Keep a visible profile if credential removal fails, so removal can be retried.
        try await credentials.remove(profile)
        try await profiles.remove(profile)
    }
}
