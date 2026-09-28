import Foundation
import Testing
@testable import A0Core

@Suite struct ModelPresetTests {
    static var baseline: ModelPresetDocument {
        var doc = ModelPresetDocument(name:"Default")
        for slot in [ModelSlot.chat,.utility,.embedding] {
            doc.setSlot(slot,values:["provider":.string("fixture"),"name":.string("base"),"kwargs":.object(["vendor":.string("only-base")])])
        }
        return doc
    }
    @Test func composerOverridesAreChatOnlyAndClearInherits() throws {
        let request = try ModelPresetOperation.setOverride(name:"Power",context:"chat").request()
        #expect(request.path == "/api/plugins/_model_config/model_override")
        #expect(request.payload == ["action":.string("set_preset"),"preset_name":.string("Power"),"context_id":.string("chat")])
        #expect(try ModelPresetOperation.clearOverride(context:"chat").request().payload["action"] == .string("clear"))
        let global = try ModelPresetOperation.select(name:"Power",project:nil,agentProfile:nil,context:nil).request()
        #expect(global.path == "/api/plugins/_model_config/model_presets")
        #expect(global.payload["action"] == .string("select"))
        let scoped = try ModelPresetOperation.select(name:"Power",project:"research",agentProfile:"coder",context:nil).request()
        #expect(scoped.payload["project_name"] == .string("research"))
        #expect(scoped.payload["agent_profile"] == .string("coder"))
    }
    @Test func presetEditingPreservesUnknownTuningButStripsManagedSecrets() throws {
        var doc = Self.baseline
        var slot = doc.slot(.chat)
        slot["new_tuning"] = .object(["nested":.number(0.8)])
        slot["api_key"] = .string("synthetic-private")
        slot["_editor"] = .string("local")
        doc.setSlot(.chat,values:slot)
        let request = try ModelPresetOperation.save([doc],renames:[]).request()
        guard case .array(let docs) = request.payload["presets"], case .object(let preset) = docs.first,
              case .object(let sent) = preset["chat"] else { Issue.record("Missing slot"); return }
        #expect(sent["new_tuning"] == slot["new_tuning"])
        #expect(sent["api_key"] == nil)
        #expect(sent["_editor"] == nil)
        #expect(!String(decoding:try JSONEncoder().encode(request.payload),as:UTF8.self).contains("synthetic-private"))
    }
    @Test func defaultIdentityAndUniqueNamesAreRequired() throws {
        #expect(throws:ModelPresetError.invalidCollection) { try ModelPresetOperation.save([],renames:[]).request() }
        #expect(throws:ModelPresetError.invalidCollection) { try ModelPresetOperation.save([Self.baseline,ModelPresetDocument(name:"default")],renames:[]).request() }
        #expect(throws:ModelPresetError.invalidCollection) { try ModelPresetOperation.save([Self.baseline],renames:[ModelPresetRename(from:"Default",to:"Power")]).request() }
        #expect(throws:ClientError.incompatiblePayload) { try ModelPresetOperation.setOverride(name:"Power",context:"").request() }
    }
    @Test func unrelatedPresetEditPreservesOpaqueNestedProviderArguments() throws {
        var doc = Self.baseline
        var slot = doc.slot(.chat)
        let arguments:JSONValue = .object(["extra_body":.object(["_custom":.string("keep"),"api_key":.string("provider-option"),"items":.array([.object(["_nested":.bool(true)])])])])
        slot["kwargs"] = arguments
        slot["api_key"] = .string("managed-secret")
        slot["_editor"] = .string("local")
        doc.setSlot(.chat,values:slot)
        var utility = doc.slot(.utility)
        utility["name"] = .string("updated-utility")
        doc.setSlot(.utility,values:utility)
        let request = try ModelPresetOperation.save([doc],renames:[]).request()
        guard case .array(let docs) = request.payload["presets"], case .object(let preset) = docs.first,
              case .object(let sent) = preset["chat"] else { Issue.record("Missing slot"); return }
        #expect(sent["kwargs"] == arguments)
        #expect(sent["api_key"] == nil)
        #expect(sent["_editor"] == nil)
    }
    @Test func displayInheritanceKeepsOptionalVisionPerPreset() {
        var base = Self.baseline
        base.setSlot(.vision,values:["provider":.string("vision"),"name":.string("eyes")])
        var power = ModelPresetDocument(name:"Power")
        #expect(power.summaryRows(defaultPreset:base).map(\.id) == ["chat","utility","embedding"])
        power.setSlot(.chat,values:["provider":.string("other"),"name":.string("reasoner")])
        #expect(power.effectiveSlot(.chat,defaultPreset:base)["kwargs"] == .object([:]))
        #expect(power.summaryRows(defaultPreset:base).first?.name == "reasoner")
        #expect(power.summaryRows(defaultPreset:base).last?.name == "base")
    }
    @Test func envelopeAndOverrideResponsesAreTypedWithoutSecretDiagnostics() throws {
        let bytes = Data(#"{"allowed":true,"override":{"preset_name":"Power"},"configured_preset":"Default","effective_preset":"Power"}"#.utf8)
        guard case .overrideState(let state) = try ModelPresetOperation.getOverride(context:"chat").result(bytes) else { Issue.record("Wrong result"); return }
        #expect(state.allowed && state.effectivePreset == "Power")
        #expect(try ModelPresetOperation.clearOverride(context:"chat").result(Data(#"{"ok":true,"override":null,"effective_preset":"Default"}"#.utf8)) == .selection("Default"))
        #expect(throws:ModelPresetError.serverRejected) { try ModelPresetOperation.reset.result(Data(#"{"ok":false,"error":"private"}"#.utf8)) }
    }
    @Test func collectionDecodingAndRenamesPreserveSparseDefinitions() throws {
        let power = ModelPresetDocument(name:"Power")
        let body:[String:JSONValue] = ["ok":.bool(true),"presets":.array([.object(Self.baseline.fields),.object(power.fields)]),"configured_preset":.string("Default"),"selected_preset":.string("Power")]
        guard case .collection(let collection) = try ModelPresetOperation.get(context:"chat").result(JSONEncoder().encode(body)) else { Issue.record("Missing collection"); return }
        #expect(collection.presets == [Self.baseline,power])
        #expect(collection.configuredPreset == "Default")
        #expect(collection.selectedPreset == "Power")
        let request = try ModelPresetOperation.save(collection.presets,renames:[ModelPresetRename(from:"Old",to:"Power")]).request()
        #expect(request.payload["renames"] == .array([.object(["from":.string("Old"),"to":.string("Power")])]))
        #expect(power.fields.count == 1)
    }
    @Test func mutationNeverRetriesAndDisabledOverrideDoesNotSignOut() async throws {
        let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:Data("Per-chat override is disabled".utf8),status:403),HTTPResponse(data:Data(),status:503)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        await #expect(throws:ModelPresetError.overrideDisabled) { try await client.modelPresets(.setOverride(name:"Power",context:"chat")) }
        _ = try await client.socketSession()
        await #expect(throws:ClientError.httpStatus(503)) { try await client.modelPresets(.setOverride(name:"Power",context:"chat")) }
        let requests = await transport.requests
        #expect(requests.count == 5)
        #expect(requests.last?.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
        #expect(requests.last?.value(forHTTPHeaderField:"Origin") == "https://server.test")
    }
}
