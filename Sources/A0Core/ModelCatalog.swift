import Foundation

public struct ModelProvider: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    enum CodingKeys: String, CodingKey { case id = "value", label }
}

/// Decode only dropdown metadata, never retain config or provider credential fields.
public struct ModelProviderCatalog: Decodable, Sendable {
    public let chat: [ModelProvider]
    public let embedding: [ModelProvider]
    enum CodingKeys: String, CodingKey { case chat = "chat_providers", embedding = "embedding_providers" }
    public func providers(for slot: ModelSlot) -> [ModelProvider] { slot == .embedding ? embedding : chat }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 2_097_152, let catalog = try? JSONDecoder().decode(Self.self,from:data),
              [catalog.chat,catalog.embedding].allSatisfy({ list in
                  list.count <= 512 && Set(list.map(\.id)).count == list.count && list.allSatisfy { !$0.id.isEmpty && $0.id.utf8.count <= 256 && !$0.label.isEmpty && $0.label.utf8.count <= 512 }
              }) else { throw ClientError.incompatiblePayload }
        return catalog
    }
}
public struct ModelSearchResult: Sendable {
    public let models: [String]
    public let hasProviderError: Bool
    public static func decode(_ data: Data, provider: String) throws -> Self {
        struct Wire: Decodable { let provider: String; let models: [String]; let error: String? }
        guard data.count <= 2_097_152, let wire = try? JSONDecoder().decode(Wire.self,from:data),
              wire.provider == provider, wire.models.count <= 20_000,
              wire.models.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 2048 }) else { throw ClientError.incompatiblePayload }
        return Self(models:Array(Set(wire.models)).sorted { $0.localizedStandardCompare($1) == .orderedAscending },hasProviderError:!(wire.error ?? "").isEmpty)
    }
}
extension APIClient {
    public func modelProviderCatalog() async throws -> ModelProviderCatalog {
        try ModelProviderCatalog.decode(await modelCatalogRequest("model_config_get",payload:[:]))
    }
    public func searchModels(provider:String,slot:ModelSlot,apiBase:String) async throws -> ModelSearchResult {
        let provider = provider.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        guard !provider.isEmpty, provider.utf8.count <= 256, apiBase.utf8.count <= 4096 else { throw ClientError.incompatiblePayload }
        let bytes = try await modelCatalogRequest("model_search",payload:["provider":.string(provider),"query":.string(""),"model_type":.string(slot == .embedding ? "embedding" : "chat"),"api_base":.string(apiBase)])
        return try ModelSearchResult.decode(bytes,provider:provider)
    }
    private func modelCatalogRequest(_ endpoint:String,payload:[String:JSONValue]) async throws -> Data {
        _ = try socketSession()
        let response = try await request("/api/plugins/_model_config/"+endpoint,method:"POST",body:JSONEncoder().encode(payload))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response)
        return response.data
    }
}
