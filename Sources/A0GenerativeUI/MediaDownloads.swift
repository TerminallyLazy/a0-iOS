import Foundation

private final class MediaNetworkPolicy:NSObject,URLSessionTaskDelegate,Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping @Sendable (URLRequest?)->Void) { completionHandler(nil) }
    func urlSession(_ session:URLSession,task:URLSessionTask,didReceive challenge:URLAuthenticationChallenge,completionHandler:@escaping @Sendable (URLSession.AuthChallengeDisposition,URLCredential?)->Void) {
        completionHandler(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust ? .performDefaultHandling : .cancelAuthenticationChallenge,nil)
    }
}
/// Owns one uniquely named temporary file. Releasing the last player owner removes it.
public final class MediaFile:Sendable {
    public let url:URL
    public let mimeType:String
    init(url:URL,mimeType:String) { self.url = url; self.mimeType = mimeType }
    deinit { try? FileManager.default.removeItem(at:url) }
}
public actor MediaDownloads {
    public static let shared = MediaDownloads()
    private let configuration:URLSessionConfiguration
    private let hostCheck:@Sendable (String)->Bool
    private let byteLimit:Int?
    private var active = 0
    public init() {
        configuration = .ephemeral; hostCheck = PublicImageHost.check; byteLimit = nil
    }
    init(configuration:URLSessionConfiguration,hostCheck:@escaping @Sendable (String)->Bool,byteLimit:Int) {
        self.configuration = configuration; self.hostCheck = hostCheck; self.byteLimit = byteLimit
    }
    public func load(_ string:String,kind:MediaKind) async throws -> MediaFile {
        guard let url = RichImagePolicy.url(string), let host = url.host, active < 2 else { throw URLError(.badURL) }
        active += 1; defer { active -= 1 }
        try Task.checkCancellation()
        let check = hostCheck
        guard await Task.detached(operation:{ check(host) }).value else { throw URLError(.cannotFindHost) }
        try Task.checkCancellation()
        let config = configuration.copy() as! URLSessionConfiguration
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 90
        let session = URLSession(configuration:config,delegate:MediaNetworkPolicy(),delegateQueue:nil)
        defer { session.invalidateAndCancel() }
        let (bytes,response) = try await session.bytes(from:url)
        let limit = min(byteLimit ?? kind.byteLimit,kind.byteLimit)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let mime = http.mimeType, let ext = kind.fileExtension(for:mime),
              http.expectedContentLength <= limit else { throw URLError(.badServerResponse) }
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("a0-media-" + UUID().uuidString).appendingPathExtension(ext)
        let file = MediaFile(url:fileURL,mimeType:mime)
        guard FileManager.default.createFile(atPath:fileURL.path,contents:nil) else { throw URLError(.cannotCreateFile) }
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],ofItemAtPath:fileURL.path)
        #endif
        let handle = try FileHandle(forWritingTo:fileURL)
        defer { try? handle.close() }
        var chunk = Data(), count = 0
        chunk.reserveCapacity(65_536)
        for try await byte in bytes {
            guard count < limit else { throw URLError(.dataLengthExceedsMaximum) }
            count += 1; chunk.append(byte)
            if chunk.count == 65_536 {
                try Task.checkCancellation(); try handle.write(contentsOf:chunk); chunk.removeAll(keepingCapacity:true)
            }
        }
        try Task.checkCancellation()
        guard count > 0 else { throw URLError(.zeroByteResource) }
        try handle.write(contentsOf:chunk)
        return file
    }
}
