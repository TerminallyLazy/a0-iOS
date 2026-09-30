import Foundation
import A0Core

public struct JevSettingsStatus: Equatable, Sendable {
    public let configured:Bool
    public let enabled:Bool
    public init(configured:Bool,enabled:Bool) { self.configured = configured; self.enabled = enabled }
}
/// Both key and consent are in the dedicated device-only credential service.
public actor JevSettingsStore {
    private struct Record: Codable { var key:String; var enabled:Bool }
    private let credentials:any CredentialStoring
    public init(credentials:any CredentialStoring) { self.credentials = credentials }
    private func record(_ profile:ProfileIdentity) async throws -> Record? {
        guard let value = try await credentials.password(for:profile) else { return nil }
        return try JSONDecoder().decode(Record.self,from:Data(value.utf8))
    }
    public func status(for profile:ProfileIdentity) async throws -> JevSettingsStatus {
        let value = try await record(profile)
        return .init(configured:value != nil,enabled:value?.enabled == true)
    }
    public func keyIfEnabled(for profile:ProfileIdentity) async throws -> String? {
        guard let value = try await record(profile), value.enabled else { return nil }
        return value.key
    }
    public func saveKey(_ key:String,for profile:ProfileIdentity) async throws {
        let key = key.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !key.isEmpty, key.utf8.count <= 4096, key.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }) else { throw JevError.invalid }
        try await write(Record(key:key,enabled:false),profile)
    }
    public func setEnabled(_ enabled:Bool,for profile:ProfileIdentity) async throws {
        guard var value = try await record(profile) else { throw JevError.unavailable }
        value.enabled = enabled; try await write(value,profile)
    }
    private func write(_ value:Record,_ profile:ProfileIdentity) async throws {
        try await credentials.save(String(decoding:JSONEncoder().encode(value),as:UTF8.self),for:profile)
    }
    public func remove(_ profile:ProfileIdentity) async throws { try await credentials.remove(profile) }
}
