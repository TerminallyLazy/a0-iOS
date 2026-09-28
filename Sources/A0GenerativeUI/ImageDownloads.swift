import Foundation
import Darwin

private final class ImageRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping @Sendable (URLRequest?) -> Void) {
        // An agent must supply the actual image URL; no authenticated or unreviewed redirect hop.
        completionHandler(nil)
    }
}
public actor ImageDownloads {
    public static let shared = ImageDownloads()
    private var cache:[URL:Data] = [:]
    private let session:URLSession
    private let hostCheck:@Sendable (String) -> Bool
    public init() {
        hostCheck = PublicImageHost.check
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 20
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration:configuration,delegate:ImageRedirectPolicy(),delegateQueue:nil)
    }
    init(configuration:URLSessionConfiguration,hostCheck:@escaping @Sendable (String) -> Bool) {
        self.hostCheck = hostCheck
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        session = URLSession(configuration:configuration,delegate:ImageRedirectPolicy(),delegateQueue:nil)
    }
    deinit { session.invalidateAndCancel() }
    public func load(_ string:String) async throws -> Data {
        guard let url = RichImagePolicy.url(string), let host = url.host else { throw URLError(.badURL) }
        if let saved = cache[url] { return saved }
        // DNS lookup stays off MainActor. Reject local/private addresses before requesting.
        let check = hostCheck
        let publicHost = await Task.detached { check(host) }.value
        guard publicHost else { throw URLError(.cannotFindHost) }
        try Task.checkCancellation()
        let (bytes,response) = try await session.bytes(from:url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              ["image/jpeg","image/png","image/webp","image/gif","image/heic"].contains(http.mimeType ?? ""),
              http.expectedContentLength <= 4_194_304 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            if data.count >= 4_194_304 { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        if cache.values.reduce(0,{$0 + $1.count}) + data.count > 12_582_912 { cache.removeAll() }
        cache[url] = data
        return data
    }
}
enum PublicImageHost {
    static func check(_ host:String) -> Bool {
        var result:UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host,nil,nil,&result) == 0, let first = result else { return false }
        defer { freeaddrinfo(first) }
        var current:UnsafeMutablePointer<addrinfo>? = first
        var found = false
        while let item = current {
            let info = item.pointee
            if info.ai_family == AF_INET {
                let address = UnsafeRawPointer(info.ai_addr!).assumingMemoryBound(to:sockaddr_in.self).pointee.sin_addr.s_addr
                let n = UInt32(bigEndian:address), a = n >> 24, b = (n >> 16) & 255
                if a == 0 || a == 10 || a == 127 || a >= 224 || (a == 169 && b == 254) || (a == 172 && (16...31).contains(b)) || (a == 192 && b == 168) || (a == 100 && (64...127).contains(b)) { return false }
                found = true
            } else if info.ai_family == AF_INET6 {
                let address = UnsafeRawPointer(info.ai_addr!).assumingMemoryBound(to:sockaddr_in6.self).pointee.sin6_addr
                let bytes = withUnsafeBytes(of:address) { Array($0) }
                // Global unicast only; excludes loopback, link-local, ULA and IPv4 mapping.
                if bytes[0] & 0xe0 != 0x20 { return false }
                found = true
            }
            current = info.ai_next
        }
        return found
    }
}
