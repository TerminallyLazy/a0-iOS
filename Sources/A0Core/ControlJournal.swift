import Foundation
import CryptoKit

/// One actor per directory; stores command intent only, never response bodies or credentials.
public actor ControlJournal {
    public struct Receipt: Codable,Sendable,Equatable {
        public let id:UUID
        public let title:String
        public let context:String
        public let profile:ProfileIdentity
        public init(title:String,context:String,profile:ProfileIdentity) { id = UUID(); self.title = title; self.context = context; self.profile = profile }
    }
    private let directory:URL
    public init(directory:URL) { self.directory = directory }
    private func file(_ profile:ProfileIdentity) throws -> URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let digest = SHA256.hash(data:try encoder.encode(profile)).map { String(format:"%02x",$0) }.joined()
        return directory.appendingPathComponent(digest+".json")
    }
    public func pending(_ profile:ProfileIdentity) throws -> Receipt? {
        let url = try file(profile)
        guard FileManager.default.fileExists(atPath:url.path) else { return nil }
        let receipt = try JSONDecoder().decode(Receipt.self,from:Data(contentsOf:url))
        guard receipt.profile == profile else { throw PersistenceError.unreadableArchive }
        return receipt
    }
    public func begin(_ receipt:Receipt) throws {
        guard try pending(receipt.profile) == nil else { throw PersistenceError.writeFailed }
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        var dir = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true; try dir.setResourceValues(values)
        let data = try JSONEncoder().encode(receipt)
        #if os(iOS)
        try data.write(to:file(receipt.profile),options:[.atomic,.completeFileProtection])
        #else
        try data.write(to:file(receipt.profile),options:.atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:try file(receipt.profile).path)
    }
    public func resolve(_ receipt:Receipt) throws {
        guard try pending(receipt.profile)?.id == receipt.id else { return }
        try FileManager.default.removeItem(at:file(receipt.profile))
    }
}
