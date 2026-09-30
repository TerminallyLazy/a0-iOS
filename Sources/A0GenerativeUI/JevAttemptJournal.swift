import Foundation
import CryptoKit

/// A bounded ledger of attempts, never payloads. Existing or uncertain attempts never replay.
public actor JevAttemptJournal {
    private struct Receipt: Codable { let attempt:UUID; let digest:String; let date:Date }
    private let directory:URL
    private var file:URL { directory.appendingPathComponent("attempts.json") }
    public init(directory:URL) { self.directory = directory }
    public func begin(identity:String,payload:Data) throws -> Bool {
        var receipts:[String:Receipt] = [:]
        if FileManager.default.fileExists(atPath:file.path) {
            let data = try Data(contentsOf:file)
            guard data.count <= 1_048_576 else { throw JevError.tooLarge }
            receipts = try JSONDecoder().decode([String:Receipt].self,from:data)
        }
        let id = Self.digest(Data(identity.utf8))
        guard receipts[id] == nil else { return false }
        // Historical replies are never admitted by the coordinator. Retain 30 days of
        // deduplication; fail closed if the bounded ledger fills within that window.
        receipts = receipts.filter { $0.value.date > Date().addingTimeInterval(-30*86400) }
        guard receipts.count < 2048 else { throw JevError.unavailable }
        receipts[id] = Receipt(attempt:UUID(),digest:Self.digest(payload),date:Date())
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        var dir = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true; try dir.setResourceValues(values)
        let data = try JSONEncoder().encode(receipts)
        #if os(iOS)
        try data.write(to:file,options:[.atomic,.completeFileProtection])
        #else
        try data.write(to:file,options:.atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        return true
    }
    static func digest(_ data:Data)->String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
}
