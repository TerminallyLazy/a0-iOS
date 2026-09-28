import Foundation

/// Explicit tool metadata only. Ordinary transcript Markdown never loads private server files.
public struct BrowserScreenshot: Sendable, Hashable, Identifiable {
    public let path: String
    public let revision: String
    public var id: String { path + "|" + revision }
    public static let maximumBytes = 8 * 1024 * 1024
    private static let mimeTypes: Set<String> = ["image/png","image/jpeg","image/webp","image/gif","image/bmp"]

    public static func extract(_ entry: LogEntry, context: String) -> Self? {
        guard ["tool","browser","agent","code_exe"].contains(entry.type), let fields = entry.kvps else { return nil }
        if let structured = fields["browser_snapshot"] {
            guard case .object(let snapshot) = structured,
                  snapshot["ephemeral"] != .bool(true),
                  snapshot["context_id"]?.string.map({ $0.isEmpty || $0 == context }) ?? true,
                  snapshot["mime"]?.string.map({ mimeTypes.contains($0.lowercased()) }) ?? true else { return nil }
            let path = snapshot["path"]?.string ?? snapshot["a0_path"]?.string
            if let path, validPath(path) {
                return Self(path:path,revision:snapshot["uri"]?.string ?? String(entry.no))
            }
            return snapshot["uri"]?.string.flatMap(parseURI)
        }
        return fields["Screenshot"]?.string.flatMap(parseURI)
    }
    private static func parseURI(_ uri: String) -> Self? {
        guard uri.hasPrefix("img://"), uri.utf8.count <= 4096 else { return nil }
        let value = String(uri.dropFirst(6))
        let components = value.components(separatedBy:"&t=")
        guard components.count <= 2,
              components.count == 1 || (!components[1].isEmpty && components[1].allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") })),
              let path = components.first, validPath(path) else { return nil }
        return Self(path:path,revision:components.count == 2 ? components[1] : "")
    }
    private static func validPath(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= 2048, !path.hasPrefix("//"),
              !path.contains("://"), !path.contains("\\"),
              !path.unicodeScalars.contains(where:{ CharacterSet.controlCharacters.contains($0) }),
              !path.contains(where:{ "%?#&".contains($0) }),
              !path.split(separator:"/",omittingEmptySubsequences:false).contains(where:{ $0 == "." || $0 == ".." }) else { return false }
        return ["png","jpg","jpeg","webp","gif","bmp"].contains((path as NSString).pathExtension.lowercased())
    }
    public func request(session: SocketSession) throws -> URLRequest {
        var components = URLComponents(url:session.origin.url,resolvingAgainstBaseURL:false)!
        components.path = "/api/image_get"; components.queryItems = [URLQueryItem(name:"path",value:path)]
        guard let url = components.url else { throw ClientError.incompatiblePayload }
        var request = URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:20)
        request.setValue("image/png, image/jpeg, image/webp, image/gif, image/bmp",forHTTPHeaderField:"Accept")
        request.setValue(session.origin.header,forHTTPHeaderField:"Origin")
        request.setValue(session.cookieHeader,forHTTPHeaderField:"Cookie")
        request.setValue(session.csrfToken,forHTTPHeaderField:"X-CSRF-Token")
        return request
    }
    public static func validate(_ response: HTTPResponse) throws -> Data {
        guard response.status == 200 else { throw ClientError.httpStatus(response.status) }
        let mime = response.header("Content-Type")?.split(separator:";").first.map(String.init)?.lowercased() ?? ""
        guard mimeTypes.contains(mime), !response.data.isEmpty, response.data.count <= maximumBytes else { throw ClientError.unexpectedResponse }
        return response.data
    }
}

extension APIClient {
    /// Separate ephemeral bounded transport: never caches private captures or follows redirects.
    public func browserScreenshot(_ reference: BrowserScreenshot) async throws -> Data {
        let session = try socketSession()
        let response = try await boundedImageRequest(reference.request(session:session),maximumBytes:BrowserScreenshot.maximumBytes)
        try Task.checkCancellation()
        let current = try socketSession()
        guard current.cookieHeader == session.cookieHeader, current.runtimeID == session.runtimeID else { throw ClientError.disconnected }
        if isLoginRedirect(response) || response.status == 401 { throw ClientError.requiresLogin }
        return try BrowserScreenshot.validate(response)
    }
}
