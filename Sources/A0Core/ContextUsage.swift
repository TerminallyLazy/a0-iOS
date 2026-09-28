import Foundation

/// Server-calculated context estimates and separately reported provider usage.
/// This projection never measures message text or invents missing provider counts.
public struct ContextUsage: Sendable, Equatable {
    public struct Bucket: Sendable, Equatable, Identifiable {
        public let id: String
        public let label: String
        public let tokens: Int
        /// Fraction of the configured model window, not fraction of used tokens.
        public let fraction: Double?
    }
    public struct ProviderUsage: Sendable, Equatable {
        public let inputTokens: Int?
        public let cachedTokens: Int?
        public let outputTokens: Int?
        /// Provider-reported USD cost. Nil means unavailable, not free.
        public let cost: Double?
        public var cacheHitFraction: Double? {
            guard let inputTokens, inputTokens > 0, let cachedTokens else { return nil }
            return min(Double(cachedTokens) / Double(inputTokens),1)
        }
        public var hasData: Bool { inputTokens != nil || outputTokens != nil || cost != nil || cacheHitFraction != nil }
    }
    public let tokens: Int
    public let contextWindow: Int
    public let buckets: [Bucket]
    public let providerUsage: ProviderUsage
    public var hasBreakdown: Bool { !buckets.isEmpty }
    public var usedFraction: Double? { contextWindow > 0 ? Double(tokens) / Double(contextWindow) : nil }
    public var meterFraction: Double? { usedFraction.map { min($0,1) } }
    public var remainingTokens: Int? { contextWindow > 0 ? max(contextWindow-tokens,0) : nil }
    public var remainingFraction: Double? { remainingTokens.map { Double($0) / Double(contextWindow) } }

    public init(data: Data) throws {
        guard data.count <= 65_536,
              let body = try? JSONDecoder().decode([String:JSONValue].self,from:data),
              let tokens = Self.count(body["tokens"]), let window = Self.count(body["context_window"])
        else { throw ClientError.incompatiblePayload }
        self.tokens = tokens; contextWindow = window
        let usage = try Self.mapping(body["usage"])
        let definitions = [("messages","Messages"), ("system_tools","System tools"), ("skills","Skills"),
                           ("mcp_tools","MCP tools"), ("system_prompt","System prompt"), ("extras","Extras")]
        var rows: [Bucket] = []
        if !usage.isEmpty {
            var sum = 0
            for (key,label) in definitions {
                guard let count = Self.count(usage[key]) else { throw ClientError.incompatiblePayload }
                let (total,overflow) = sum.addingReportingOverflow(count)
                guard !overflow else { throw ClientError.incompatiblePayload }
                sum = total
                rows.append(Bucket(id:key,label:label,tokens:count,fraction:window > 0 ? Double(count)/Double(window) : nil))
            }
            // The server reconciles the six buckets to its stored prompt estimate.
            guard sum == tokens else { throw ClientError.incompatiblePayload }
            if sum == 0 { rows = [] }
        }
        buckets = rows
        let provider = try Self.mapping(body["provider_usage"])
        providerUsage = ProviderUsage(inputTokens:Self.count(provider["input_tokens"]),
                                      cachedTokens:Self.count(provider["cached_tokens"]),
                                      outputTokens:Self.count(provider["output_tokens"]),
                                      cost:Self.nonNegativeNumber(provider["cost"]))
    }
    private static func mapping(_ value: JSONValue?) throws -> [String:JSONValue] {
        guard let value, value != .null else { return [:] }
        guard case .object(let object) = value else { throw ClientError.incompatiblePayload }
        return object
    }
    private static func count(_ value: JSONValue?) -> Int? {
        guard let number = nonNegativeNumber(value) else { return nil }
        return Int(exactly:number)
    }
    private static func nonNegativeNumber(_ value: JSONValue?) -> Double? {
        guard case .number(let number) = value, number.isFinite, number >= 0 else { return nil }
        return number
    }
}

extension APIClient {
    /// Existing bundled plugin endpoint: counts only, no prompt content and no mutation.
    public func contextUsage(context: String) async throws -> ContextUsage {
        _ = try socketSession()
        guard !context.isEmpty else { throw ClientError.incompatiblePayload }
        let body = try JSONEncoder().encode(["context":context])
        let response = try await request("/api/plugins/_context_window/context_window",method:"POST",body:body)
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response)
        return try ContextUsage(data:response.data)
    }
}
