import Foundation
import Testing
@testable import A0GenerativeUI

@Suite struct MediaDownloadTests {
    func loader(allowed:Bool = true,limit:Int = 16) -> MediaDownloads {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MediaFixtureProtocol.self]
        return MediaDownloads(configuration:config,hostCheck:{_ in allowed},byteLimit:limit)
    }
    @Test func boundedLocalFileHasNoCredentialsAndIsRemovedWithOwner() async throws {
        var file:MediaFile? = try await loader().load("https://media.example.com/audio",kind:.audio)
        let url = try #require(file?.url)
        #expect(try Data(contentsOf:url) == Data([1,2,3]))
        file = nil
        #expect(!FileManager.default.fileExists(atPath:url.path))
        let video = try await loader().load("https://media.example.com/video",kind:.video)
        #expect(video.url.pathExtension == "mp4")
    }
    @Test func rejectsHTMLPlaylistsRedirectsTypeMismatchSizeAndPrivateDNS() async {
        for path in ["html","playlist","redirect","large","empty","video","overflow"] {
            await #expect(throws:(any Error).self) { try await loader().load("https://media.example.com/" + path,kind:.audio) }
        }
        await #expect(throws:(any Error).self) { try await loader(allowed:false).load("https://media.example.com/audio",kind:.audio) }
        await #expect(throws:(any Error).self) { try await loader().load("http://media.example.com/audio",kind:.audio) }
    }
    @Test func cancellationDoesNotReturnPlayableFile() async {
        let service = loader()
        let task = Task { try await service.load("https://media.example.com/audio",kind:.audio) }
        task.cancel()
        await #expect(throws:(any Error).self) { try await task.value }
    }
}
private final class MediaFixtureProtocol:URLProtocol,@unchecked Sendable {
    override class func canInit(with request:URLRequest)->Bool { true }
    override class func canonicalRequest(for request:URLRequest)->URLRequest { request }
    override func startLoading() {
        guard request.value(forHTTPHeaderField:"Cookie") == nil, request.value(forHTTPHeaderField:"Authorization") == nil else {
            client?.urlProtocol(self,didFailWithError:URLError(.userAuthenticationRequired)); return
        }
        let path = request.url!.lastPathComponent
        let mime = ["html":"text/html","playlist":"application/vnd.apple.mpegurl","video":"video/mp4"][path] ?? "audio/mpeg"
        let data = path == "chunks" ? Data(repeating:1,count:70_000) : path == "empty" ? Data() : path == "overflow" ? Data(repeating:1,count:17) : Data([1,2,3])
        var headers = ["Content-Type":mime]
        if path != "overflow" { headers["Content-Length"] = path == "large" ? "999999999" : "\(data.count)" }
        let response = HTTPURLResponse(url:request.url!,statusCode:path == "redirect" ? 302 : 200,httpVersion:nil,headerFields:headers)!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension MediaDownloadTests {
    @Test func allowlistDistinguishesAudioVideoAndRejectsRemotePlaylists() {
        for mime in ["audio/mpeg","audio/mp4","audio/x-m4a","audio/aac","audio/wav","audio/x-wav"] {
            #expect(MediaKind.audio.fileExtension(for:mime) != nil)
            #expect(MediaKind.video.fileExtension(for:mime) == nil)
        }
        #expect(MediaKind.video.fileExtension(for:"video/quicktime") == "mov")
        #expect(MediaKind.audio.byteLimit == 33_554_432)
        #expect(MediaKind.video.byteLimit == 104_857_600)
        #expect(MediaKind.video.fileExtension(for:"application/vnd.apple.mpegurl") == nil)
    }
    @Test func streamsAcrossDiskChunkBoundary() async throws {
        let file = try await loader(limit:80_000).load("https://media.example.com/chunks",kind:.audio)
        #expect(try Data(contentsOf:file.url).count == 70_000)
    }
}
