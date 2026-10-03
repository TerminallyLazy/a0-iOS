import Foundation

public enum ModelPresetError: Error, Sendable, Equatable, LocalizedError {
    case invalidCollection, invalidName, serverRejected, overrideDisabled
    public var errorDescription: String? {
        switch self {
        case .invalidCollection: "Keep Default with its Main, Utility and Embedding models, and give each preset a unique name."
        case .invalidName: "Enter a nonempty preset name."
        case .serverRejected: "Agent Zero could not complete the model preset request. Check the server settings before trying again."
        case .overrideDisabled: "This server does not allow a separate model preset for this chat."
        }
    }
}
public enum ModelSlot: String, Sendable, CaseIterable, Identifiable {
    case chat, vision, utility, embedding
    public var id: String { rawValue }
    public var title: String { switch self { case .chat:"Main"; case .vision:"Vision override"; case .utility:"Utility"; case .embedding:"Embedding" } }
}
public struct ModelPresetRow: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let provider: String
    public let name: String
}
/// Transient edit draft. Do not archive or log configuration dictionaries.
public struct ModelPresetDocument: Sendable, Equatable, Identifiable {
    public var fields: [String:JSONValue]
    public var id: String { name }
    public init(fields:[String:JSONValue]) { self.fields = fields }
    public init(name:String) { fields = ["name":.string(name)] }
    public var name:String { get { fields["name"]?.string ?? "" } set { fields["name"] = .string(newValue) } }
    public func slot(_ slot:ModelSlot) -> [String:JSONValue] {
        if case .object(let value) = fields[slot.rawValue] { value } else { [:] }
    }
    public mutating func setSlot(_ slot:ModelSlot,values:[String:JSONValue]) { fields[slot.rawValue] = .object(values) }
    /// Display projection only. Never write inherited values back over a sparse preset.
    public func effectiveSlot(_ key:ModelSlot,defaultPreset:ModelPresetDocument?) -> [String:JSONValue] {
        let own = slot(key)
        if key == .vision { return Self.hasIdentity(own) ? own : [:] }
        let base = defaultPreset?.slot(key) ?? [:]
        guard name != "Default" else { return own }
        guard Self.hasIdentity(own) else { return base }
        var result = base.merging(own,uniquingKeysWith: { _,new in new })
        result["kwargs"] = own["kwargs"] ?? .object([:])
        return result
    }
    public func summaryRows(defaultPreset:ModelPresetDocument?) -> [ModelPresetRow] {
        ModelSlot.allCases.compactMap { key in
            let value = effectiveSlot(key,defaultPreset:defaultPreset)
            if key == .vision {
                guard Self.hasIdentity(value) else { return nil }
                let main = effectiveSlot(.chat,defaultPreset:defaultPreset)
                if main["vision"] == .bool(true), value["override_main"] != .bool(true) { return nil }
            }
            return ModelPresetRow(id:key.rawValue,title:key.title,provider:value["provider"]?.string ?? "",name:value["name"]?.string ?? "")
        }
    }
    static func hasIdentity(_ fields:[String:JSONValue]) -> Bool {
        !(fields["provider"]?.string ?? "").isEmpty || !(fields["name"]?.string ?? "").isEmpty
    }
    /// The server strips managed fields only at a model slot's top level.
    /// Provider arguments inside kwargs are opaque, including underscore keys.
    var wireFields:[String:JSONValue] {
        var clean = fields.filter { !$0.key.hasPrefix("_") && $0.key != "api_key" }
        for slot in ModelSlot.allCases {
            if case .object(let values) = clean[slot.rawValue] {
                clean[slot.rawValue] = .object(values.filter { !$0.key.hasPrefix("_") && $0.key != "api_key" })
            }
        }
        return clean
    }
}
public struct ModelPresetRename: Sendable, Equatable {
    public let from:String
    public let to:String
    public init(from:String,to:String) { self.from = from; self.to = to }
}
public struct ModelPresetCollection: Sendable, Equatable {
    public let presets:[ModelPresetDocument]
    public let configuredPreset:String?
    public let selectedPreset:String?
    public init(presets:[ModelPresetDocument],configuredPreset:String? = nil,selectedPreset:String? = nil) {
        self.presets = presets; self.configuredPreset = configuredPreset; self.selectedPreset = selectedPreset
    }
}
public struct ModelOverrideState: Sendable, Equatable {
    public let allowed:Bool
    public let override:[String:JSONValue]?
    public let configuredPreset:String
    public let effectivePreset:String
}
public enum ModelPresetResult: Sendable, Equatable {
    case collection(ModelPresetCollection), selection(String), overrideState(ModelOverrideState)
}
public enum ModelPresetOperation: Sendable {
    case get(context:String?), save([ModelPresetDocument],renames:[ModelPresetRename]), reset
    /// This writes the scoped default, and also the named chat if context is supplied.
    case select(name:String,project:String?,agentProfile:String?,context:String?)
    case getOverride(context:String), setOverride(name:String,context:String), clearOverride(context:String)
    public var mutates:Bool { switch self { case .get,.getOverride:false; default:true } }
    public var title:String {
        switch self {
        case .get:"Model presets"; case .save:"Save global presets"; case .reset:"Reset global presets"
        case .select:"Select default preset"; case .getOverride:"Chat model preset"
        case .setOverride:"Change chat preset"; case .clearOverride:"Use inherited preset"
        }
    }
    func request() throws -> (path:String,payload:[String:JSONValue]) {
        var path = "/api/plugins/_model_config/model_presets"
        var body:[String:JSONValue]
        switch self {
        case .get(let context):
            body = ["action":.string("get")]
            if let context { guard !context.isEmpty else { throw ClientError.incompatiblePayload }; body["context_id"] = .string(context) }
        case .save(let presets,let renames):
            try Self.validateCollection(presets)
            for rename in renames {
                try Self.validateName(rename.from); try Self.validateName(rename.to)
                guard rename.from.lowercased() != "default", presets.contains(where: { $0.name == rename.to }) else { throw ModelPresetError.invalidCollection }
            }
            body = ["action":.string("save"),"presets":.array(presets.map { .object($0.wireFields) }),
                    "renames":.array(renames.map { .object(["from":.string($0.from),"to":.string($0.to)]) })]
        case .reset: body = ["action":.string("reset")]
        case .select(let name,let project,let profile,let context):
            try Self.validateName(name)
            body = ["action":.string("select"),"name":.string(name)]
            if let project { body["project_name"] = .string(project) }
            if let profile { body["agent_profile"] = .string(profile) }
            if let context { guard !context.isEmpty else { throw ClientError.incompatiblePayload }; body["context_id"] = .string(context) }
        case .getOverride(let context), .clearOverride(let context), .setOverride(_,let context):
            guard !context.isEmpty else { throw ClientError.incompatiblePayload }
            path = "/api/plugins/_model_config/model_override"
            let action = switch self { case .getOverride:"get"; case .clearOverride:"clear"; default:"set_preset" }
            body = ["action":.string(action),"context_id":.string(context)]
            if case .setOverride(let name,_) = self { try Self.validateName(name); body["preset_name"] = .string(name) }
        }
        return (path,body)
    }
    func result(_ data:Data) throws -> ModelPresetResult {
        guard data.count <= 2_097_152, let body = try? JSONDecoder().decode([String:JSONValue].self,from:data) else { throw ClientError.incompatiblePayload }
        if case .getOverride = self {
            guard case .bool(let allowed) = body["allowed"],
                  let configured = body["configured_preset"]?.string, !configured.isEmpty,
                  let effective = body["effective_preset"]?.string, !effective.isEmpty else { throw ClientError.incompatiblePayload }
            let override:[String:JSONValue]?
            switch body["override"] { case .object(let value):override = value; case .null:override = nil; default:throw ClientError.incompatiblePayload }
            return .overrideState(ModelOverrideState(allowed:allowed,override:override,configuredPreset:configured,effectivePreset:effective))
        }
        guard case .bool(let ok) = body["ok"] else { throw ClientError.incompatiblePayload }
        guard ok else { throw ModelPresetError.serverRejected }
        switch self {
        case .get,.save,.reset:
            guard case .array(let items) = body["presets"], items.count <= 1000 else { throw ClientError.incompatiblePayload }
            let presets = try items.map { item -> ModelPresetDocument in
                guard case .object(let fields) = item else { throw ClientError.incompatiblePayload }
                let doc = ModelPresetDocument(fields:fields)
                do { try Self.validateName(doc.name) } catch { throw ClientError.incompatiblePayload }
                return doc
            }
            guard Set(presets.map { $0.name.lowercased() }).count == presets.count else { throw ClientError.incompatiblePayload }
            return .collection(ModelPresetCollection(presets:presets,configuredPreset:body["configured_preset"]?.string,selectedPreset:body["selected_preset"]?.string))
        case .select,.setOverride,.clearOverride:
            let key = switch self { case .select:"selected_preset"; case .setOverride:"preset_name"; default:"effective_preset" }
            guard let name = body[key]?.string, !name.isEmpty else { throw ClientError.incompatiblePayload }
            return .selection(name)
        case .getOverride: throw ClientError.incompatiblePayload
        }
    }
    private static func validateName(_ name:String) throws {
        guard !name.isEmpty, name == name.trimmingCharacters(in:.whitespacesAndNewlines),
              name.rangeOfCharacter(from:.controlCharacters) == nil else { throw ModelPresetError.invalidName }
    }
    private static func validateCollection(_ presets:[ModelPresetDocument]) throws {
        guard !presets.isEmpty, presets.count <= 1000,
              Set(presets.map { $0.name.lowercased() }).count == presets.count,
              let baseline = presets.first(where: { $0.name == "Default" }),
              [ModelSlot.chat,.utility,.embedding].allSatisfy({ ModelPresetDocument.hasIdentity(baseline.slot($0)) }) else { throw ModelPresetError.invalidCollection }
        for preset in presets { try validateName(preset.name) }
    }
}
extension APIClient {
    public func setModelPreset(name: String, context: String) async throws {
        _ = try await modelPresets(.setOverride(name: name, context: context))
    }
    /// Persist intent before mutations. This client never replays a model change.
    public func modelPresets(_ operation:ModelPresetOperation) async throws -> ModelPresetResult {
        _ = try socketSession()
        let call = try operation.request()
        let response = try await request(call.path,method:"POST",body:JSONEncoder().encode(call.payload))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 {
            if case .setOverride = operation,
               response.data == Data("Per-chat override is disabled".utf8) { throw ModelPresetError.overrideDisabled }
            disconnect(); throw ClientError.csrfRejected
        }
        try validate(response)
        return try operation.result(response.data)
    }
}
