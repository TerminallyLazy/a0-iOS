import Foundation
import Testing
@testable import A0GenerativeUI

@Suite struct ImageDownloadTests {
    func loader(allowed:Bool = true) -> ImageDownloads {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ImageFixtureProtocol.self]
        return ImageDownloads(configuration:config,hostCheck:{_ in allowed})
    }
    @Test func numericDNSPreflightRejectsNonPublicAddresses() {
        for host in ["127.0.0.1","10.0.0.1","192.168.1.1","172.16.0.1","169.254.0.1","100.64.0.1","::1","fc00::1"] { #expect(!PublicImageHost.check(host)) }
        #expect(PublicImageHost.check("8.8.8.8"))
        #expect(PublicImageHost.check("2001:4860:4860::8888"))
    }
    @Test func boundedImagesAndNoSharedCredentials() async throws {
        let service = loader()
        let data = try await service.load("https://images.example.com/image")
        #expect(data == Data([1,2,3]))
        #expect(try await service.load("https://images.example.com/image") == data)
    }
    @Test func badStatusTypeSizeAndDNSAreRejected() async {
        await #expect(throws:(any Error).self) { try await ImageDownloads.shared.load("https://localhost/image") }
        for path in ["html","redirect","large"] {
            await #expect(throws:(any Error).self) { try await loader().load("https://images.example.com/" + path) }
        }
        await #expect(throws:(any Error).self) { try await loader(allowed:false).load("https://images.example.com/image") }
        await #expect(throws:(any Error).self) { try await loader().load("https://127.0.0.1/image") }
    }
}
private final class ImageFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request:URLRequest) -> Bool { true }
    override class func canonicalRequest(for request:URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard request.value(forHTTPHeaderField:"Cookie") == nil, request.value(forHTTPHeaderField:"Authorization") == nil else {
            client?.urlProtocol(self,didFailWithError:URLError(.userAuthenticationRequired));return
        }
        let path = request.url!.lastPathComponent
        let response = HTTPURLResponse(url:request.url!,statusCode:path == "redirect" ? 302 : 200,httpVersion:nil,headerFields:["Content-Type":path == "html" ? "text/html" : "image/png","Content-Length":path == "large" ? "5000000" : "3"])!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:Data([1,2,3]))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
