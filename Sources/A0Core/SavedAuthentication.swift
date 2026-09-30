import Foundation

/// Sensitive session material. Store only in a device-only, when-unlocked Keychain item.
/// Passwords, CSRF tokens, server content and generated form input are deliberately excluded.
public struct SavedAuthentication: Codable, Sendable, Equatable {
    public var version = 1
    public let profile: ProfileIdentity
    public let name: String
    public let value: String
    public let expires: Date?
    public init(profile: ProfileIdentity, name: String, value: String, expires: Date?) {
        self.profile = profile; self.name = name; self.value = value; self.expires = expires
    }
    public func validatedCookie(for identity: ProfileIdentity, origin: ServerOrigin) throws -> HTTPCookie {
        guard version == 1, profile == identity, profile.origin == origin.header,
              name.hasPrefix("session_"), name.count <= 256,
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }),
              !value.isEmpty, value.utf8.count <= 16_384,
              value.utf8.allSatisfy({ $0 > 32 && $0 < 127 && $0 != 59 && $0 != 44 }),
              expires.map({ $0 > Date() }) ?? true,
              let host = origin.url.host else { throw ClientError.requiresLogin }
        var properties: [HTTPCookiePropertyKey: Any] = [.name:name,.value:value,.domain:host,.path:"/",.secure:"TRUE",HTTPCookiePropertyKey(rawValue:"HttpOnly"):"TRUE"]
        if let expires { properties[.expires] = expires }
        guard let cookie = HTTPCookie(properties: properties) else { throw ClientError.requiresLogin }
        return cookie
    }
}
