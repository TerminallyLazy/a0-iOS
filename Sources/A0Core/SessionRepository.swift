import Foundation
import CryptoKit

public struct ProfileIdentity: Codable, Hashable, Sendable {
    public let origin: String
    public let username: String
    public init(origin: ServerOrigin, username: String) { self.origin = origin.header; self.username = username }
}

public enum PersistenceError: Error, Sendable, Equatable {
    case invalidDirectory, unreadableArchive, unsupportedVersion, writeFailed
}

public struct SessionArchive: Codable, Equatable, Sendable {
    public var version = 1
    public let profile: ProfileIdentity
    public let revision: Int
    public let selectedContext: String?
    public let drafts: [String: String]
    public let deliveries: [Delivery]
    public let attachments: [String: [StagedAttachment]]?
    public let hostDrafts: [String: HostTaskSelection]?
    public let pendingModelPresets: [String: String]?
    public init(profile: ProfileIdentity, revision: Int, selectedContext: String? = nil,
                drafts: [String: String] = [:], deliveries: [Delivery] = [], attachments: [String: [StagedAttachment]]? = nil, hostDrafts: [String: HostTaskSelection]? = nil, pendingModelPresets: [String: String]? = nil) {
        self.profile = profile; self.revision = revision; self.selectedContext = selectedContext
        self.drafts = drafts; self.deliveries = deliveries; self.attachments = attachments; self.hostDrafts = hostDrafts; self.pendingModelPresets = pendingModelPresets
    }
}
public protocol SessionStoring: Sendable {
    func load(_ profile: ProfileIdentity) async throws -> SessionArchive?
    func save(_ archive: SessionArchive) async throws
    func stage(_ attachment: ChatAttachment, for profile: ProfileIdentity) async throws
    func attachment(_ reference: StagedAttachment, for profile: ProfileIdentity) async throws -> ChatAttachment
    func removeAttachment(_ id: UUID, for profile: ProfileIdentity) async throws
}
extension SessionStoring {
    public func stage(_ attachment: ChatAttachment, for profile: ProfileIdentity) async throws { throw AttachmentError.unsupported }
    public func attachment(_ reference: StagedAttachment, for profile: ProfileIdentity) async throws -> ChatAttachment { throw AttachmentError.unsupported }
    public func removeAttachment(_ id: UUID, for profile: ProfileIdentity) async throws { }
}

/// One actor per storage directory. Cache changes only after a successful atomic write.
public actor SessionRepository: SessionStoring {
    private let directory: URL
    private var cache: [ProfileIdentity: SessionArchive] = [:]
    private var initializedAttachmentProfiles: Set<ProfileIdentity> = []
    public init(directory: URL) throws {
        guard directory.isFileURL, directory.path != "/", !directory.path.isEmpty else { throw PersistenceError.invalidDirectory }
        self.directory = directory.standardizedFileURL.resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        var url = self.directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
    private func file(_ profile: ProfileIdentity) throws -> URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let digest = SHA256.hash(data: try encoder.encode(profile)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }
    private func attachmentDirectory(_ profile: ProfileIdentity) throws -> URL {
        let root = try file(profile).deletingPathExtension().appendingPathExtension("attachments")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var url = root; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        #endif
        return root
    }
    public func stage(_ attachment: ChatAttachment, for profile: ProfileIdentity) async throws {
        _ = try load(profile) // One startup cleanup must precede any new staged write.
        let root = try attachmentDirectory(profile)
        let contents = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey])
        let total = try contents.reduce(0) { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
        guard total + attachment.data.count <= 64 * 1_024 * 1_024 else { throw AttachmentError.storageFull }
        var url = root.appendingPathComponent(attachment.id.uuidString)
        #if os(iOS)
        try attachment.data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try attachment.data.write(to: url, options: .atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
    }
    public func attachment(_ reference: StagedAttachment, for profile: ProfileIdentity) async throws -> ChatAttachment {
        let url = try attachmentDirectory(profile).appendingPathComponent(reference.id.uuidString)
        let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, info.fileSize == reference.byteCount,
              reference.byteCount <= ChatAttachment.maximumBytes else { throw AttachmentError.invalidFile }
        return try ChatAttachment(id: reference.id, name: reference.name, contentType: reference.contentType, data: Data(contentsOf: url))
    }
    public func removeAttachment(_ id: UUID, for profile: ProfileIdentity) async throws {
        let url = try attachmentDirectory(profile).appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    public func load(_ profile: ProfileIdentity) throws -> SessionArchive? {
        if let value = cache[profile] { return value }
        let url = try file(profile)
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            try pruneInitialOrphans(profile, references: [])
            return nil
        }
        catch { throw PersistenceError.unreadableArchive }
        let archive: SessionArchive
        do { archive = try JSONDecoder().decode(SessionArchive.self, from: data) }
        catch { throw PersistenceError.unreadableArchive }
        guard archive.version == 1 else { throw PersistenceError.unsupportedVersion }
        guard archive.profile == profile, archive.revision >= 0,
              Set(archive.deliveries.map(\.id)).count == archive.deliveries.count else { throw PersistenceError.unreadableArchive }
        try pruneInitialOrphans(profile, references: Set((archive.attachments ?? [:]).values.flatMap { $0.map(\.id) }))
        cache[profile] = archive
        return archive
    }
    private func pruneInitialOrphans(_ profile: ProfileIdentity, references: Set<UUID>) throws {
        guard !initializedAttachmentProfiles.contains(profile) else { return }
        let root = try file(profile).deletingPathExtension().appendingPathExtension("attachments")
        if FileManager.default.fileExists(atPath: root.path) {
            for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                // Only files owned by this staging mechanism; never recurse into arbitrary content.
                if let id = UUID(uuidString: url.lastPathComponent), !references.contains(id) { try FileManager.default.removeItem(at: url) }
            }
        }
        initializedAttachmentProfiles.insert(profile)
    }
    public func save(_ archive: SessionArchive) throws {
        guard archive.version == 1 else { throw PersistenceError.unsupportedVersion }
        if let existing = try load(archive.profile), existing.revision >= archive.revision { return }
        do {
            var url = try file(archive.profile)
            let data = try JSONEncoder().encode(archive)
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: url, options: .atomic)
            #endif
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            cache[archive.profile] = archive
        } catch { throw PersistenceError.writeFailed }
    }
}
