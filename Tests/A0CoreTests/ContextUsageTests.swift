import Foundation
import Testing
@testable import A0Core

@Suite struct ContextUsageTests {
    static let fixture = Data(#"{"tokens":46000,"context_window":200000,"usage":{"messages":18000,"system_tools":6000,"skills":4000,"mcp_tools":3000,"system_prompt":12000,"extras":3000},"provider_usage":{"input_tokens":46000,"cached_tokens":23000,"output_tokens":1800,"cost":0.014}}"#.utf8)

    @Test func projectionUsesServerCountsAndFullWindowDenominator() throws {
        let usage = try ContextUsage(data:Self.fixture)
        #expect(usage.tokens == 46000)
        #expect(usage.contextWindow == 200000)
        #expect(usage.usedFraction == 0.23)
        #expect(usage.remainingTokens == 154000)
        #expect(usage.buckets.map(\.id) == ["messages","system_tools","skills","mcp_tools","system_prompt","extras"])
        #expect(usage.buckets.first?.fraction == 0.09)
        #expect(usage.providerUsage.cacheHitFraction == 0.5)
        #expect(usage.providerUsage.cost == 0.014)
        #expect(usage.providerUsage.outputTokens == 1800)
    }

    @Test func olderChatHasNoInventedBreakdownOrProviderRows() throws {
        let usage = try ContextUsage(data:Data(#"{"tokens":1000,"context_window":200000,"usage":{},"provider_usage":{}}"#.utf8))
        #expect(!usage.hasBreakdown)
        #expect(usage.buckets.isEmpty)
        #expect(!usage.providerUsage.hasData)
        #expect(usage.providerUsage.cost == nil)
        #expect(usage.providerUsage.cacheHitFraction == nil)
    }

    @Test func unknownLimitAndOverCapacityRemainTruthful() throws {
        let unknown = try ContextUsage(data:Data(#"{"tokens":10,"context_window":0,"usage":{},"provider_usage":{"input_tokens":0,"cached_tokens":0,"cost":0}}"#.utf8))
        #expect(unknown.usedFraction == nil)
        #expect(unknown.remainingTokens == nil)
        #expect(unknown.providerUsage.cacheHitFraction == nil)
        #expect(unknown.providerUsage.cost == 0)
        let over = try ContextUsage(data:Data(#"{"tokens":120,"context_window":100,"usage":{},"provider_usage":{"input_tokens":100,"cached_tokens":120}}"#.utf8))
        #expect(over.usedFraction == 1.2)
        #expect(over.meterFraction == 1)
        #expect(over.remainingTokens == 0)
        #expect(over.providerUsage.cacheHitFraction == 1)
    }

    @Test(arguments:[#"{"tokens":-1,"context_window":100}"#, #"{"tokens":1.5,"context_window":100}"#, #"{"tokens":1,"context_window":"100"}"#, #"{"tokens":1e99,"context_window":100}"#, #"{"tokens":1,"context_window":100,"usage":{"messages":2}}"#])
    func malformedMeasurementsDoNotRender(json:String) {
        #expect(throws:ClientError.incompatiblePayload) { try ContextUsage(data:Data(json.utf8)) }
    }

    @Test func unavailableProviderFieldsStayAbsent() throws {
        let usage = try ContextUsage(data:Data(#"{"tokens":0,"context_window":100,"usage":{},"provider_usage":{"input_tokens":null,"cached_tokens":-1,"output_tokens":8,"cost":"private"}}"#.utf8))
        #expect(usage.providerUsage.inputTokens == nil)
        #expect(usage.providerUsage.cachedTokens == nil)
        #expect(usage.providerUsage.cost == nil)
        #expect(usage.providerUsage.outputTokens == 8)
    }

    @Test func usageReadUsesAuthenticatedPluginRouteAndDoesNotRetry() async throws {
        let response = HTTPResponse(data:Self.fixture,status:200,headers:["Content-Type":"application/json"])
        let transport = ScriptTransport(loginResponses() + [response,HTTPResponse(data:Data(),status:404),HTTPResponse(data:Data(),status:401)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        await #expect(throws:ClientError.requiresLogin) { try await client.contextUsage(context:"chat") }
        try await client.connect(username:"fixture",password:"fixture")
        let usage = try await client.contextUsage(context:"chat")
        #expect(usage.tokens == 46000)
        let request = try #require(await transport.requests.last)
        #expect(request.url?.path == "/api/plugins/_context_window/context_window")
        #expect(try JSONDecoder().decode([String:String].self,from:#require(request.httpBody)) == ["context":"chat"])
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
        #expect(request.value(forHTTPHeaderField:"Origin") == "https://server.test")
        await #expect(throws:ClientError.httpStatus(404)) { try await client.contextUsage(context:"chat") }
        #expect(await transport.requests.count == 5)
        await #expect(throws:ClientError.requiresLogin) { try await client.contextUsage(context:"chat") }
        await #expect(throws:ClientError.requiresLogin) { try await client.contextUsage(context:"chat") }
        #expect(await transport.requests.count == 6)
    }
}
