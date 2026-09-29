import Foundation
import Testing
@testable import A0Core

@Suite struct ModelCatalogTests {
    @Test func providerCatalogUsesWebUIListsAndIgnoresConfiguration() throws {
        let catalog = try ModelProviderCatalog.decode(Data(#"{"chat_providers":[{"value":"codex_oauth","label":"Codex OAuth"},{"value":"openrouter","label":"OpenRouter"}],"embedding_providers":[{"value":"huggingface","label":"Hugging Face"}],"config":{"private":"ignored"}}"#.utf8))
        #expect(catalog.providers(for:.utility).map(\.id) == ["codex_oauth","openrouter"])
        #expect(catalog.providers(for:.vision) == catalog.providers(for:.chat))
        #expect(catalog.providers(for:.embedding).map(\.id) == ["huggingface"])
        #expect(throws:ClientError.incompatiblePayload) { try ModelProviderCatalog.decode(Data(#"{"chat_providers":[],"embedding_providers":"wrong"}"#.utf8)) }
    }
    @Test func searchIsScopedToProviderTypeAndBaseAndNeverReturnsWrongProvider() async throws {
        let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:Data(#"{"provider":"openrouter","models":["b/model","a/model","a/model"],"source":"provider_api","error":""}"#.utf8),status:200,headers:["Content-Type":"application/json"])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        let result = try await client.searchModels(provider:"openrouter",slot:.vision,apiBase:"https://models.test/v1")
        #expect(result.models == ["a/model","b/model"])
        let request = try #require(await transport.requests.last)
        #expect(request.url?.path == "/api/plugins/_model_config/model_search")
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
        let body = try JSONDecoder().decode([String:JSONValue].self,from:request.httpBody!)
        #expect(body == ["provider":.string("openrouter"),"model_type":.string("chat"),"query":.string(""),"api_base":.string("https://models.test/v1")])
        #expect(throws:ClientError.incompatiblePayload) { try ModelSearchResult.decode(Data(#"{"provider":"wrong","models":["x"],"source":"api","error":""}"#.utf8),provider:"openrouter") }
    }
    @Test func catalogReadsAuthenticateAndEmbeddingSearchUsesEmbeddingType() async throws {
        let transport = ScriptTransport(loginResponses()+[
            HTTPResponse(data:Data(#"{"chat_providers":[],"embedding_providers":[]}"#.utf8),status:200,headers:["Content-Type":"application/json"]),
            HTTPResponse(data:Data(#"{"provider":"huggingface","models":[],"source":"none","error":"private upstream error"}"#.utf8),status:200,headers:["Content-Type":"application/json"])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        _ = try await client.modelProviderCatalog()
        #expect(await transport.requests.last?.url?.path == "/api/plugins/_model_config/model_config_get")
        let result = try await client.searchModels(provider:"huggingface",slot:.embedding,apiBase:"")
        #expect(result.hasProviderError && result.models.isEmpty)
        let request = try #require(await transport.requests.last)
        #expect(try JSONDecoder().decode([String:JSONValue].self,from:request.httpBody!)["model_type"] == .string("embedding"))
    }
    @Test func rejectsMalformedOrUnboundedCatalogs() throws {
        for raw in [
            #"{"chat_providers":[{"value":"x","label":"X"},{"value":"x","label":"Again"}],"embedding_providers":[]}"#,
            #"{"chat_providers":[{"value":"","label":"X"}],"embedding_providers":[]}"#
        ] {
            #expect(throws:ClientError.incompatiblePayload) { try ModelProviderCatalog.decode(Data(raw.utf8)) }
        }
        #expect(throws:ClientError.incompatiblePayload) { try ModelProviderCatalog.decode(Data(repeating:32,count:2_097_153)) }
        #expect(throws:ClientError.incompatiblePayload) { try ModelSearchResult.decode(Data(#"{"provider":"x","models":[""]}"#.utf8),provider:"x") }
        let many = try JSONEncoder().encode(["provider":JSONValue.string("x"),"models":.array(Array(repeating:.string("x"),count:20_001))])
        #expect(throws:ClientError.incompatiblePayload) { try ModelSearchResult.decode(many,provider:"x") }
    }
    @Test func catalogAuthenticationFailuresInvalidateSession() async throws {
        for status in [401,403,302] {
            let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:Data(),status:status,headers:["Location":"/login"])])
            let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
            try await client.connect(username:"fixture",password:"fixture")
            await #expect(throws: status == 403 ? ClientError.csrfRejected : ClientError.requiresLogin) { try await client.modelProviderCatalog() }
            await #expect(throws:ClientError.requiresLogin) { try await client.searchModels(provider:"x",slot:.chat,apiBase:"") }
            #expect(await transport.requests.count == loginResponses().count + 1)
        }
    }

}
