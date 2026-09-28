import Foundation

public enum ClientError: Error, Sendable, Equatable, LocalizedError {
    case invalidOrigin, requiresLogin, invalidCredentials, unauthenticatedServer, csrfRejected
    case httpStatus(Int), unexpectedResponse, incompatiblePayload, invalidHandshake, disconnected
    public var errorDescription: String? {
        switch self {
        case .invalidOrigin: "Enter an HTTPS server origin without credentials, a path, query, or fragment."
        case .requiresLogin: "Sign in to this Agent Zero server."
        case .invalidCredentials: "Sign-in failed. Check the username and password."
        case .unauthenticatedServer: "This spike requires an authenticated server. Enable server login first."
        case .csrfRejected: "The security session expired or was rejected. Reconnect to sign in again."
        case .httpStatus(let code): "The server returned HTTP \(code)."
        case .unexpectedResponse: "The server returned an unexpected response. Check for a proxy login page."
        case .incompatiblePayload: "The server response does not match the supported Agent Zero contract."
        case .invalidHandshake: "The realtime state handler did not accept the handshake."
        case .disconnected: "The connection closed. Reconnect to refresh state."
        }
    }
}

public enum OriginPolicy: Sendable {
    case httpsOnly
    #if DEBUG
    case loopbackDevelopment
    #endif
}

public struct ServerOrigin: Sendable, Equatable {
    public let url: URL
    public let allowsUnauthenticatedLoopback: Bool
    public init(_ input: String, policy: OriginPolicy = .httpsOnly) throws {
        var allowLoopback = false
        #if DEBUG
        if case .loopbackDevelopment = policy { allowLoopback = true }
        #endif
        guard var c = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = c.host, !host.isEmpty,
              c.scheme?.lowercased() == "https" || (allowLoopback && c.scheme?.lowercased() == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host.lowercased())),
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.path.isEmpty || c.path == "/", c.port == nil || (1...65535).contains(c.port!) else {
            throw ClientError.invalidOrigin
        }
        c.scheme = c.scheme?.lowercased(); c.host = host.lowercased(); c.path = ""
        guard let url = c.url else { throw ClientError.invalidOrigin }
        self.url = url
        self.allowsUnauthenticatedLoopback = allowLoopback && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host.lowercased())
    }
    public var header: String { url.absoluteString }
}

public struct HTTPResponse: Sendable {
    public let data: Data
    public let status: Int
    public let headers: [String: String]
    public init(data: Data, status: Int, headers: [String: String] = [:]) {
        self.data = data; self.status = status; self.headers = headers
    }
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
public protocol HTTPTransport: Sendable {
    func execute(_ request: URLRequest) async throws -> HTTPResponse
    func execute(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse
}

extension HTTPTransport {
    public func execute(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        let response = try await execute(request)
        guard response.data.count <= maximumResponseBytes else { throw ClientError.unexpectedResponse }
        return response
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public final class URLSessionTransport: HTTPTransport, Sendable {
    private let session: URLSession
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }
    public func execute(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.unexpectedResponse }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { out, pair in
            if let key = pair.key as? String, let value = pair.value as? String { out[key] = value }
        }
        return HTTPResponse(data: data, status: http.statusCode, headers: headers)
    }
    public func execute(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        let (bytes, response) = try await session.bytes(for:request)
        guard let http = response as? HTTPURLResponse,
              response.expectedContentLength <= Int64(maximumResponseBytes) else { throw ClientError.unexpectedResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else { throw ClientError.unexpectedResponse }
            data.append(byte)
        }
        try Task.checkCancellation()
        let headers = http.allHeaderFields.reduce(into:[String:String]()) { result,pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        return HTTPResponse(data:data,status:http.statusCode,headers:headers)
    }
    deinit { session.invalidateAndCancel() }
}

public struct SocketSession: Sendable {
    public let origin: ServerOrigin
    public let cookieHeader: String
    public let csrfToken: String
    public let runtimeID: String
}

/// One instance per server profile. Only an explicitly exported session cookie may enter secure storage.
public actor APIClient: ChatAPI {
    public let origin: ServerOrigin
    private let transport: any HTTPTransport
    private var cookies: [String: HTTPCookie] = [:]
    private var csrf: String?
    private var runtimeID: String?
    private var authenticated = false
    private var authenticatedUsername: String?
    private var authenticationEpoch = UUID()
    public init(origin: ServerOrigin, transport: any HTTPTransport = URLSessionTransport()) {
        self.origin = origin; self.transport = transport
    }
    public func disconnect() { authenticationEpoch = UUID(); cookies = [:]; csrf = nil; runtimeID = nil; authenticated = false; authenticatedUsername = nil }

    public func connect(username: String, password: String) async throws {
        disconnect()
        let initial = try await request("/api/csrf_token", method: "GET")
        // With a new empty cookie jar, a successful protected bootstrap means server login is off.
        if initial.status == 200 {
            try validate(initial)
            guard origin.allowsUnauthenticatedLoopback else { throw ClientError.unauthenticatedServer }
            try acceptBootstrap(initial)
            authenticatedUsername = username
            return
        }
        guard isLoginRedirect(initial) || initial.status == 401 else {
            try validate(initial); throw ClientError.unexpectedResponse
        }
        guard !username.isEmpty, !password.isEmpty else { throw ClientError.requiresLogin }
        let body = "username=\(Self.formEncode(username))&password=\(Self.formEncode(password))"
        let login = try await request("/login", method: "POST", body: Data(body.utf8), contentType: "application/x-www-form-urlencoded")
        guard (300..<400).contains(login.status), let location = login.header("Location"),
              let redirect = URL(string: location, relativeTo: origin.url)?.absoluteURL,
              redirect.scheme == origin.url.scheme, redirect.host == origin.url.host,
              (redirect.port ?? 443) == (origin.url.port ?? 443), redirect.path != "/login" else {
            throw ClientError.invalidCredentials
        }
        let bootstrap = try await request("/api/csrf_token", method: "GET")
        if isLoginRedirect(bootstrap) { throw ClientError.invalidCredentials }
        try acceptBootstrap(bootstrap)
        authenticatedUsername = username
    }
    public func savedAuthentication(for profile: ProfileIdentity) throws -> SavedAuthentication {
        guard authenticated, profile.origin == origin.header, profile.username == authenticatedUsername, let runtimeID,
              let cookie = cookies["session_\(runtimeID)"] else { throw ClientError.requiresLogin }
        return SavedAuthentication(profile: profile, name: cookie.name, value: cookie.value, expires: cookie.expiresDate)
    }
    /// Resume the same account with read-only security bootstrap. Never log in or replay a mutation.
    public func restore(_ saved: SavedAuthentication, for profile: ProfileIdentity) async throws {
        disconnect()
        let cookie = try saved.validatedCookie(for: profile, origin: origin)
        do {
            // An anonymous protected bootstrap must still require login, as on first connection.
            let anonymous = try await request("/api/csrf_token", method: "GET")
            if anonymous.status == 200 { throw ClientError.unauthenticatedServer }
            guard isLoginRedirect(anonymous) || anonymous.status == 401 else {
                try validate(anonymous); throw ClientError.unexpectedResponse
            }
            cookies = [cookie.name: cookie]
            let bootstrap = try await request("/api/csrf_token", method: "GET")
            if isLoginRedirect(bootstrap) || bootstrap.status == 401 { throw ClientError.requiresLogin }
            try acceptBootstrap(bootstrap)
            authenticatedUsername = profile.username
        } catch { disconnect(); throw error }
    }
    private func acceptBootstrap(_ bootstrap: HTTPResponse) throws {
        try validate(bootstrap)
        struct Bootstrap: Decodable { let ok: Bool; let token: String?; let runtime_id: String? }
        let state: Bootstrap = try decode(bootstrap.data)
        guard state.ok, let token = state.token, !token.isEmpty,
              token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
              let runtime = state.runtime_id,
              !runtime.isEmpty, runtime.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
              cookies["session_\(runtime)"] != nil else { throw ClientError.csrfRejected }
        // Retain only the currently authenticated runtime session cookie.
        cookies = cookies.filter { $0.key == "session_\(runtime)" }
        csrf = token; runtimeID = runtime; authenticated = true
    }
    public func poll(_ state: StateRequest) async throws -> Snapshot {
        guard authenticated else { throw ClientError.requiresLogin }
        let response = try await request("/api/poll", method: "POST", body: JSONEncoder().encode(state))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response)
        return try decode(response.data)
    }
    public func createChat(id: String) async throws -> String {
        let response = try await command("/api/chat_create", payload: ["new_context": id, "current_context": ""])
        struct Created: Decodable { let ok: Bool; let ctxid: String }
        let created: Created = try decode(response.data)
        guard created.ok, created.ctxid == id else { throw ClientError.incompatiblePayload }
        return created.ctxid
    }
    public func sendText(context: String, text: String, messageID: String, queued: Bool) async throws {
        let response = try await command(queued ? "/api/message_queue_add" : "/api/message_async",
            payload: ["context": context, "text": text, queued ? "item_id" : "message_id": messageID])
        if queued {
            struct Queued: Decodable { let ok: Bool; let item_id: String }
            let ack: Queued = try decode(response.data)
            guard ack.ok, ack.item_id == messageID else { throw ClientError.incompatiblePayload }
        } else {
            struct Accepted: Decodable { let context: String }
            let ack: Accepted = try decode(response.data)
            guard ack.context == context else { throw ClientError.incompatiblePayload }
        }
    }
    func command(_ path: String, payload: [String: String]) async throws -> HTTPResponse {
        guard authenticated else { throw ClientError.requiresLogin }
        let response = try await request(path, method: "POST", body: JSONEncoder().encode(payload))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response)
        return response
    }
    /// Refresh only an existing session; never submit credentials or replay commands.
    public func refreshSocketSession() async throws -> SocketSession {
        guard authenticated else { throw ClientError.requiresLogin }
        let response = try await request("/api/csrf_token", method: "GET")
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        // A transient server/network failure leaves the polling session intact.
        try validate(response)
        do { try acceptBootstrap(response) }
        catch { disconnect(); throw error }
        return try socketSession()
    }
    public func socketSession() throws -> SocketSession {
        guard authenticated, let csrf, let runtimeID else { throw ClientError.requiresLogin }
        return SocketSession(origin: origin, cookieHeader: cookieHeader(), csrfToken: csrf, runtimeID: runtimeID)
    }
    func request(_ path: String, method: String, body: Data? = nil, contentType: String = "application/json") async throws -> HTTPResponse {
        let url = origin.url.appendingPathComponent(String(path.dropFirst()))
        var request = URLRequest(url: url)
        request.httpMethod = method; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(origin.header, forHTTPHeaderField: "Origin")
        if body != nil { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let csrf { request.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token") }
        let cookie = cookieHeader(); if !cookie.isEmpty { request.setValue(cookie, forHTTPHeaderField: "Cookie") }
        let epoch = authenticationEpoch
        let response = try await transport.execute(request)
        try Task.checkCancellation()
        guard epoch == authenticationEpoch else { throw ClientError.disconnected }
        // Server-issued cookies are isolated to this already-validated origin.
        for cookie in HTTPCookie.cookies(withResponseHeaderFields: response.headers, for: url) {
            guard cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == origin.url.host else { continue }
            if cookie.expiresDate.map({ $0 <= Date() }) == true { cookies.removeValue(forKey: cookie.name) }
            else { cookies[cookie.name] = cookie }
        }
        return response
    }
    func boundedImageRequest(_ request: URLRequest, maximumBytes: Int) async throws -> HTTPResponse {
        guard authenticated else { throw ClientError.requiresLogin }
        let epoch = authenticationEpoch
        let response = try await transport.execute(request,maximumResponseBytes:maximumBytes)
        try Task.checkCancellation()
        guard epoch == authenticationEpoch else { throw ClientError.disconnected }
        return response
    }
    private func cookieHeader() -> String {
        var parts = cookies.values.filter { $0.expiresDate.map { $0 > Date() } ?? true }
            .sorted { $0.name < $1.name }.map { "\($0.name)=\($0.value)" }
        if let csrf, let runtimeID { parts.append("csrf_token_\(runtimeID)=\(csrf)") }
        return parts.joined(separator: "; ")
    }
    func isLoginRedirect(_ response: HTTPResponse) -> Bool {
        guard (300..<400).contains(response.status), let location = response.header("Location"),
              let url = URL(string: location, relativeTo: origin.url)?.absoluteURL else { return false }
        return url.scheme == origin.url.scheme && url.host == origin.url.host
            && (url.port ?? 443) == (origin.url.port ?? 443) && url.path == "/login"
    }
    func validate(_ response: HTTPResponse) throws {
        guard (200..<300).contains(response.status) else { throw ClientError.httpStatus(response.status) }
        guard response.header("Content-Type")?.lowercased().contains("application/json") == true else {
            throw ClientError.unexpectedResponse
        }
    }
    func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw ClientError.incompatiblePayload }
    }
    private static func formEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
