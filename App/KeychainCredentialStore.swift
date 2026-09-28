import Foundation
import Security
import CryptoKit
import A0Core

/// Foreground-only, device-local generic passwords. No shared access group or iCloud sync.
actor KeychainCredentialStore: CredentialStoring {
    private let service: String
    init(service: String = "local.agentzero.saved-credentials.v1") { self.service = service }
    private func query(_ profile: ProfileIdentity) throws -> [String:Any] {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let key = SHA256.hash(data:try encoder.encode(profile)).map { String(format:"%02x",$0) }.joined()
        return [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service,
                kSecAttrAccount as String:key, kSecAttrSynchronizable as String:false]
    }
    func password(for profile: ProfileIdentity) throws -> String? {
        var query = try query(profile)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,&result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let password = String(data:data,encoding:.utf8) else {
            throw CredentialError.unavailable
        }
        return password
    }
    func save(_ password: String, for profile: ProfileIdentity) throws {
        let query = try query(profile)
        let attributes: [String:Any] = [kSecValueData as String:Data(password.utf8),
            kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary,attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _,new in new } as CFDictionary,nil)
        }
        guard status == errSecSuccess else { throw CredentialError.unavailable }
    }
    func remove(_ profile: ProfileIdentity) throws {
        let status = SecItemDelete(try query(profile) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.unavailable }
    }
}
