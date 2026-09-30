import Foundation

public struct JevChoice: Sendable, Equatable {
    public let candidateID:String
    public let model:String
    public init(candidateID:String,model:String) { self.candidateID = candidateID; self.model = model }
    static func decode(_ data:Data,eligible:Set<String>) throws -> Self {
        struct Answer: Decodable { let type:String; let choice:String }
        struct Response: Decodable { let model:String; let answers:[String:Answer] }
        guard data.count <= 65_536 else { throw JevError.tooLarge }
        let result = try JSONDecoder().decode(Response.self,from:data)
        guard let answer = result.answers["presentation"], answer.type == "choice", eligible.contains(answer.choice),
              !result.model.isEmpty, result.model.utf8.count <= 128 else { throw JevError.invalid }
        return Self(candidateID:answer.choice,model:result.model)
    }
}
public protocol JevChoosing: Sendable {
    func choose(_ batch:JevBatch,key:String) async throws -> JevChoice
}
private final class JevRedirectPolicy:NSObject,URLSessionTaskDelegate,Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping @Sendable (URLRequest?)->Void) { completionHandler(nil) }
}
public actor JevClient: JevChoosing {
    private let session:URLSession
    public init() { self.init(configuration:.ephemeral) }
    init(configuration:URLSessionConfiguration) {
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.httpAdditionalHeaders = nil
        configuration.timeoutIntervalForRequest = 5; configuration.timeoutIntervalForResource = 5
        configuration.waitsForConnectivity = false; configuration.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration:configuration,delegate:JevRedirectPolicy(),delegateQueue:nil)
    }
    deinit { session.invalidateAndCancel() }
    public func choose(_ batch:JevBatch,key:String) async throws -> JevChoice {
        try Task.checkCancellation()
        guard !key.isEmpty, key.utf8.count <= 4096, key.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }) else { throw JevError.invalid }
        var request = URLRequest(url:URL(string:"https://api.typesafe.ai/v1/systemone")!,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:5)
        request.httpMethod = "POST"; request.httpBody = try batch.requestData()
        request.setValue("Bearer " + key,forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        let (bytes,response) = try await session.bytes(for:request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.mimeType == "application/json",
              http.expectedContentLength <= 65_536 else { throw JevError.unavailable }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 65_536 else { throw JevError.tooLarge }
            data.append(byte)
        }
        try Task.checkCancellation()
        return try JevChoice.decode(data,eligible:batch.ids)
    }
}
