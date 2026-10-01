import Foundation

public enum HostCapability: String, Codable, Sendable, CaseIterable {
    case browser, computerUse = "computer_use"
    public var title: String { self == .browser ? "Browser" : "Computer use" }
    public var starter: String {
        self == .browser ? "Use the authorized browser on my computer to " : "Inspect the application on my computer and "
    }
}

/// Persist intent, never the session-bound generation. Restored drafts require review.
public struct HostTaskSelection: Codable, Sendable, Equatable {
    public let targetID: String
    public let hostLabel: String
    public let capability: HostCapability
    public var generation: String? = nil
    enum CodingKeys: String, CodingKey { case targetID, hostLabel, capability }
    public init(targetID: String, hostLabel: String, capability: HostCapability, generation: String) {
        self.targetID = targetID; self.hostLabel = hostLabel; self.capability = capability; self.generation = generation
    }
}

public struct HostConnection: Sendable, Equatable {
    public let context: String?
    public let state: String
    public let hostLabel: String?
    public let targetID: String?
    public let generation: String?
    public let capabilities: [String:String]
    public let bound: Bool
    public let bindingCurrent: Bool
    public var targeted: Bool { context != nil && targetID != nil && generation != nil && ["connected","needs_action"].contains(state) }
    public func selection(_ capability: HostCapability) -> HostTaskSelection? {
        guard targeted, capabilities[capability.rawValue] == "ready", let targetID, let generation, let hostLabel else { return nil }
        return HostTaskSelection(targetID:targetID,hostLabel:hostLabel,capability:capability,generation:generation)
    }
    public init(data: Data, context: String) throws {
        guard data.count <= 65_536,
              let value = try? JSONDecoder().decode([String:JSONValue].self,from:data),
              value["version"] == .number(1), value["context_id"]?.string == context,
              let state = value["state"]?.string, state.count <= 64,
              case .object(let caps) = value["capabilities"],
              case .bool(let bound) = value["bound"], case .bool(let current) = value["binding_current"] else { throw ClientError.incompatiblePayload }
        self.context = context; self.state = state; self.bound = bound; bindingCurrent = current
        hostLabel = Self.label(value["host_label"]?.string)
        targetID = Self.token(value["target_id"]?.string)
        generation = Self.token(value["generation"]?.string)
        var parsed: [String:String] = [:]
        for name in ["browser","computer_use","files","file_write","code_execution"] {
            guard case .object(let cap) = caps[name], let state = cap["state"]?.string,
                  ["ready","off","unsupported","needs_attention","container"].contains(state),
                  cap["ready"] == .bool(state == "ready") else { throw ClientError.incompatiblePayload }
            parsed[name] = state
        }
        capabilities = parsed
    }
    public init(legacyData: Data? = nil) throws {
        context = nil; targetID = nil; generation = nil; capabilities = [:]; bound = false; bindingCurrent = false
        if let legacyData {
            guard legacyData.count <= 65_536, let value = try? JSONDecoder().decode([String:JSONValue].self,from:legacyData) else { throw ClientError.incompatiblePayload }
            state = value["multiple_hosts"] == .bool(true) ? "ambiguous" : (value["connected"] == .bool(true) ? "presence_only" : "disconnected")
            if case .object(let gateway) = value["gateway"] { hostLabel = Self.label(gateway["host_label"]?.string) }
            else { hostLabel = nil }
        } else { state = "unsupported"; hostLabel = nil }
    }
    private static func label(_ text: String?) -> String? {
        guard let text, !text.isEmpty, text.count <= 128,
              !text.unicodeScalars.contains(where:{ CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return text
    }
    private static func token(_ text: String?) -> String? {
        guard let text, text.count == 64, text.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
        return text
    }
}

extension APIClient {
    public func hostConnection(context: String?) async throws -> HostConnection {
        let session = try socketSession()
        let discovery = try await hostRequest("capabilities",payload:[:],allowMissing:true)
        guard discovery.status != 404 else { return try HostConnection() }
        guard discovery.data.count <= 65_536,
              let value = try? JSONDecoder().decode([String:JSONValue].self,from:discovery.data),
              value["protocol"]?.string == "a0-connector.v1", case .array(let features) = value["features"] else { throw ClientError.incompatiblePayload }
        let result: HostConnection
        if features.contains(.string("host_tasks_v1")), let context {
            result = try HostConnection(data:await hostRequest("host_status",payload:["context":context]).data,context:context)
        } else if features.contains(.string("launcher_gateway")) {
            result = try HostConnection(legacyData:await hostRequest("launcher_gateway_status",payload:[:]).data)
        } else { result = try HostConnection() }
        let current = try socketSession()
        // The request path fences account changes. A same-account cookie refresh
        // must not make the computer appear disconnected.
        guard current.runtimeID == session.runtimeID else { throw ClientError.disconnected }
        return result
    }
    public func sendHostTask(context: String, text: String, messageID: String, queued: Bool, selection: HostTaskSelection) async throws {
        guard !context.isEmpty, let generation = selection.generation else { throw ClientError.incompatiblePayload }
        let response = try await hostRequest("host_task",payload:["context":context,"text":text,"message_id":messageID,
            "queued":queued ? "true" : "false","target_id":selection.targetID,"generation":generation,"capability":selection.capability.rawValue])
        guard let value = try? JSONDecoder().decode([String:JSONValue].self,from:response.data),
              value["ok"] == .bool(true), value["context"]?.string == context,
              value["message_id"]?.string == messageID, value["queued"] == .bool(queued) else { throw ClientError.incompatiblePayload }
    }
    private func hostRequest(_ route: String, payload: [String:String], allowMissing: Bool = false) async throws -> HTTPResponse {
        _ = try socketSession()
        let response = try await request("/api/plugins/_a0_connector/v1/"+route,method:"POST",body:JSONEncoder().encode(payload))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        if allowMissing && response.status == 404 { return response }
        try validate(response)
        guard response.data.count <= 65_536 else { throw ClientError.incompatiblePayload }
        return response
    }
}
