import Foundation
import Security
import A0Core

/// One active authenticated account, isolated from optional saved passwords.
/// Synchronization and backup are disabled; the system only releases it while unlocked.
actor KeychainSessionStore {
    private let service: String
    init(service: String) { self.service = service }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "active-session",
         kSecAttrSynchronizable as String: false]
    }
    func load() throws -> SavedAuthentication? {
        var query = query
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CredentialError.unavailable }
        return try JSONDecoder().decode(SavedAuthentication.self, from: data)
    }
    func save(_ authentication: SavedAuthentication) throws {
        let data = try JSONEncoder().encode(authentication)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CredentialError.unavailable }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.unavailable }
    }
}
