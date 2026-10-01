import Foundation
import Testing
@testable import A0Core

@Suite struct ComputerSetupTests {
    private func snapshot(_ overrides:[String:Any]=[:]) throws -> Data {
        var value:[String:Any] = ["version":1,"server_id":String(repeating:"a",count:32),"observed_at":100,
            "connected":false,"platform":"macos","steps":[["id":"connection","state":"action_on_computer","reason":"launcher_disconnected","title":"Connect your computer","detail":"Open Launcher","action":"open_launcher","location":"computer","help_id":"connection","help_text":"Use the same server on your computer."]]]
        value.merge(overrides) { _,new in new };return try JSONSerialization.data(withJSONObject:value)
    }
    @Test func sharedHelpAndUnavailableStateDecode() throws {
        let result=try ComputerSetupSnapshot(data:snapshot())
        #expect(!result.connected)
        #expect(result.steps.first?.helpText == "Use the same server on your computer.")
    }
    @Test func untrustedSchemaAndOversizedRepliesFailClosed() throws {
        for change:[String:Any] in [["version":2],["server_id":"other"],["platform":String(repeating:"x",count:33)]] {
            #expect(throws:ClientError.incompatiblePayload) { try ComputerSetupSnapshot(data:snapshot(change)) }
        }
        #expect(throws:ClientError.incompatiblePayload) { try ComputerSetupSnapshot(data:Data(repeating:0,count:65_537)) }
    }
    @Test func statusIsAuthenticatedAndChatIndependent() async throws {
        let transport=ScriptTransport(loginResponses()+[HTTPResponse(data:try snapshot(),status:200,headers:["Content-Type":"application/json"])])
        let client=APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        _=try await client.computerSetup()
        let request=try #require(await transport.requests.last)
        #expect(request.url?.path == "/api/plugins/_a0_connector/v1/host_setup")
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") != nil)
        #expect(String(decoding:try #require(request.httpBody),as:UTF8.self) == "{\"action\":\"status\"}")
    }
    @Test func mutationNeverRetriesCSRFRejection() async throws {
        let transport=ScriptTransport(loginResponses()+[HTTPResponse(data:Data(),status:403,headers:[:])])
        let client=APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        await #expect(throws:ClientError.csrfRejected) {
            try await client.computerSetupContinuation(action:"create",requestID:UUID().uuidString,capabilities:["browser"])
        }
        #expect(await transport.requests.count == 4)
    }
}
