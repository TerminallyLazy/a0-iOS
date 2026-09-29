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
}
