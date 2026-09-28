import Foundation
import Testing
@testable import A0Core

actor ScriptTransport: HTTPTransport {
    var responses: [HTTPResponse]
    var requests: [URLRequest] = []
    init(_ responses: [HTTPResponse]) { self.responses = responses }
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw ClientError.disconnected }
        return responses.removeFirst()
    }
}
func loginResponses() -> [HTTPResponse] {
    [HTTPResponse(data: Data(), status: 302, headers: ["Location":"/login?next=/api/csrf_token"]),
     HTTPResponse(data: Data(), status: 302, headers: ["Location":"/", "Set-Cookie":"session_test-runtime=synthetic-session; Path=/; HttpOnly"]),
     HTTPResponse(data: Data(#"{"ok":true,"token":"synthetic-csrf","runtime_id":"test-runtime"}"#.utf8), status:200, headers:["Content-Type":"application/json"])]
}
@Test(arguments: ["http://server.test", "https://user:password@server.test", "https://server.test/path", "https://server.test?token=x", "https://server.test#fragment"])
func invalidOriginsAreRejected(input: String) {
    #expect(throws: ClientError.invalidOrigin) { try ServerOrigin(input) }
}
@Test func loginUsesFormAndPollHasSessionAndCSRF() async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data: try fixture("full"), status: 200, headers:["Content-Type":"application/json"])])
    let client = APIClient(origin: try ServerOrigin("https://server.test"), transport: transport)
    try await client.connect(username:"user+name", password:"a&b= c")
    let state = try await client.poll(StateRequest())
    #expect(state.context == "synthetic-chat")
    let requests = await transport.requests
    #expect(String(decoding: try #require(requests[1].httpBody), as: UTF8.self) == "username=user%2Bname&password=a%26b%3D%20c")
    #expect(requests[3].value(forHTTPHeaderField: "X-CSRF-Token") == "synthetic-csrf")
    #expect(requests[3].value(forHTTPHeaderField: "Cookie")?.contains("session_test-runtime=synthetic-session") == true)
    #expect(requests[3].value(forHTTPHeaderField: "Cookie")?.contains("csrf_token_test-runtime=synthetic-csrf") == true)
    #expect(requests[3].value(forHTTPHeaderField: "Origin") == "https://server.test")
}
@Test func badLoginHTMLCannotBecomeAuthenticated() async throws {
    let transport = ScriptTransport([loginResponses()[0], HTTPResponse(data: Data("<html>Invalid Credentials</html>".utf8), status:200)])
    let client = APIClient(origin: try ServerOrigin("https://server.test"), transport:transport)
    await #expect(throws: ClientError.invalidCredentials) { try await client.connect(username:"user", password:"wrong") }
    await #expect(throws: ClientError.requiresLogin) { try await client.socketSession() }
    #expect(await transport.requests.count == 2)
}
@Test func crossOriginRedirectNeverReceivesCredentials() async throws {
    let transport = ScriptTransport([HTTPResponse(data: Data(),status:302,headers:["Location":"https://elsewhere.test/login"])])
    let client = APIClient(origin: try ServerOrigin("https://server.test"),transport:transport)
    await #expect(throws: ClientError.httpStatus(302)) { try await client.connect(username:"user",password:"private") }
    #expect(await transport.requests.count == 1)
}
@Test func csrfRejectionClearsSessionWithoutReplay() async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data: Data(),status:403)])
    let client = APIClient(origin: try ServerOrigin("https://server.test"),transport:transport)
    try await client.connect(username:"user",password:"fixture")
    await #expect(throws: ClientError.csrfRejected) { try await client.poll(StateRequest()) }
    await #expect(throws: ClientError.requiresLogin) { try await client.socketSession() }
    #expect(await transport.requests.count == 4)
}
@Test func profilesDoNotShareCookies() async throws {
    let transport = ScriptTransport(loginResponses())
    let a = APIClient(origin: try ServerOrigin("https://server.test"),transport:transport)
    let b = APIClient(origin: try ServerOrigin("https://other.test"),transport:transport)
    try await a.connect(username:"user",password:"fixture")
    await #expect(throws: ClientError.requiresLogin) { try await b.socketSession() }
    await a.disconnect()
    await #expect(throws: ClientError.requiresLogin) { try await a.socketSession() }
}
@Test func malformedJSONClassifiedWithoutEchoingBody() async throws {
    let transport = ScriptTransport(loginResponses() + [HTTPResponse(data: Data("{private invalid".utf8),status:200,headers:["Content-Type":"application/json"])])
    let client = APIClient(origin: try ServerOrigin("https://server.test"),transport:transport)
    try await client.connect(username:"user",password:"fixture")
    await #expect(throws: ClientError.incompatiblePayload) { try await client.poll(StateRequest()) }
}

#if DEBUG
@Test(arguments: ["http://192.168.1.5:49805", "http://example.com", "http://localhost.example.com", "http://127.0.0.1.evil.test"])
func developmentPolicyCannotEnableRemoteHTTP(input: String) {
    #expect(throws: ClientError.invalidOrigin) { try ServerOrigin(input, policy: .loopbackDevelopment) }
}
@Test func loopbackDevelopmentPreservesCSRFAndProductionStillRejectsHTTP() async throws {
    let response = HTTPResponse(data:Data(#"{"ok":true,"token":"synthetic-csrf","runtime_id":"test-runtime"}"#.utf8),status:200,headers:["Content-Type":"application/json","Set-Cookie":"session_test-runtime=fixture; Path=/"])
    let transport = ScriptTransport([response])
    let origin = try ServerOrigin("http://localhost:49805",policy:.loopbackDevelopment)
    let client = APIClient(origin:origin,transport:transport)
    try await client.connect(username:"",password:"")
    let socket = try await client.socketSession()
    #expect(socket.cookieHeader.contains("csrf_token_test-runtime=synthetic-csrf"))
    #expect(throws: ClientError.invalidOrigin) { try ServerOrigin("http://localhost:49805") }
}
#endif
@Test func bootstrapRejectsMissingSessionCookie() async throws {
    var responses = loginResponses()
    responses[1] = HTTPResponse(data:Data(),status:302,headers:["Location":"/"])
    let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:ScriptTransport(responses))
    await #expect(throws: ClientError.csrfRejected) { try await client.connect(username:"user",password:"fixture") }
}
@Test func transportDoesNotUseSharedCookies() async throws {
    // Exercise real URLSession request preparation, not only the client double.
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieStorage = .shared
    config.protocolClasses = [FixtureURLProtocol.self]
    let transport = URLSessionTransport(configuration:config)
    var request = URLRequest(url:URL(string:"https://isolated-fixture.invalid")!)
    request.setValue("manual=isolated",forHTTPHeaderField:"Cookie")
    let response = try await transport.execute(request)
    #expect(response.status == 200)
    #expect(String(decoding:response.data,as:UTF8.self) == "manual=isolated")
}
private final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request:URLRequest)->Bool { request.url?.host == "isolated-fixture.invalid" }
    override class func canonicalRequest(for request:URLRequest)->URLRequest { request }
    override func startLoading() {
        guard let url=request.url, let response=HTTPURLResponse(url:url,statusCode:200,httpVersion:nil,headerFields:["Content-Type":"text/plain"]) else { return }
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:Data((request.value(forHTTPHeaderField:"Cookie") ?? "").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
