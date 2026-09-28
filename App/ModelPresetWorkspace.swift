import SwiftUI
import A0Core

/// Ephemeral editor state; only an operation title and chat ID enter the shared journal.
@MainActor @Observable
final class ModelPresetWorkspace {
    var presets:[ModelPresetDocument] = []
    var overrideState:ModelOverrideState?
    var configuredName = ""
    var busy = false
    var notice:String?
    var pending:ControlJournal.Receipt?
    private var journalReadable = false
    private var ownerGeneration:UUID?
    private var ownerContext:String?
    private var attemptedGeneration:UUID?
    private var attemptedContext:String?
    func needsReload(_ model:SpikeModel) -> Bool { attemptedGeneration != model.connectionGeneration || attemptedContext != model.chat?.selectedContext }
    var canMutate:Bool { !busy && journalReadable && pending == nil }
    var defaultPreset:ModelPresetDocument? { presets.first { $0.name == "Default" } }
    var effectiveName:String { overrideState?.effectivePreset ?? configuredName }
    var effectivePreset:ModelPresetDocument? { presets.first { $0.name == effectiveName } }
    var closedLabel:String {
        guard let preset = effectivePreset else { return "Model presets" }
        let main = preset.effectiveSlot(.chat,defaultPreset:defaultPreset)
        let leaf = main["name"]?.string?.split(separator:"/").last.map(String.init) ?? ""
        return leaf.isEmpty ? preset.name : "\(preset.name) · \(leaf)"
    }
    private func profile(_ model:SpikeModel) -> ProfileIdentity? { try? ProfileIdentity(origin:ServerOrigin(model.origin),username:model.username) }
    private func matches(_ model:SpikeModel,generation:UUID,context:String?) -> Bool {
        generation == model.connectionGeneration && context == model.chat?.selectedContext
    }
    func clear() { presets = []; overrideState = nil; configuredName = ""; pending = nil; notice = nil; journalReadable = false; attemptedGeneration = nil; attemptedContext = nil }
    func load(_ model:SpikeModel) async {
        let generation = model.connectionGeneration,context = model.chat?.selectedContext
        if ownerGeneration != generation || ownerContext != context {
            clear(); ownerGeneration = generation; ownerContext = context
        }
        guard !busy,model.canSubmit,!model.demo,let client = model.controlClient,let profile = profile(model) else { return }
        attemptedGeneration = generation; attemptedContext = context
        overrideState = nil
        busy = true; defer { busy = false }
        do {
            let pending = try await ControlReceipts.journal.pending(profile)
            guard matches(model,generation:generation,context:context) else { return }
            self.pending = pending; journalReadable = true
            let collection = try await client.modelPresets(.get(context:context))
            guard matches(model,generation:generation,context:context) else { return }
            if case .collection(let collection) = collection { presets = collection.presets; configuredName = collection.selectedPreset ?? collection.configuredPreset ?? "Default" }
            if let context {
                let state = try await client.modelPresets(.getOverride(context:context))
                guard matches(model,generation:generation,context:context) else { return }
                if case .overrideState(let value) = state { overrideState = value }
            }
            notice = nil
        } catch {
            guard matches(model,generation:generation,context:context) else { return }
            notice = "Model presets could not be loaded. Refresh when Agent Zero is reachable."
        }
    }
    func resolve(_ model:SpikeModel) async {
        guard !busy,let pending else { return }
        let generation = model.connectionGeneration,context = model.chat?.selectedContext
        do {
            try await ControlReceipts.journal.resolve(pending)
            guard matches(model,generation:generation,context:context) else { return }
            self.pending = nil; notice = nil
        } catch {
            guard matches(model,generation:generation,context:context) else { return }
            notice = "The receipt could not be updated. Unlock this device and try again."
        }
    }
    /// Collection saves compare the fetched editor baseline before sending any mutation.
    func mutate(_ operation:ModelPresetOperation,model:SpikeModel,baseline:[ModelPresetDocument]? = nil) async -> Bool {
        guard canMutate,model.canSubmit,!model.demo,let client = model.controlClient,let profile = profile(model) else { return false }
        let generation = model.connectionGeneration,context = model.chat?.selectedContext
        guard ownerGeneration == generation,ownerContext == context else { return false }
        busy = true; notice = nil
        var receipt:ControlJournal.Receipt?
        var committed = false
        defer { busy = false }
        do {
            if let baseline {
                let latest = try await client.modelPresets(.get(context:context))
                guard matches(model,generation:generation,context:context) else { return false }
                guard case .collection(let collection) = latest,collection.presets == baseline else {
                    notice = "Presets changed on the server. Close this editor and refresh before saving; your changes have not been sent."
                    return false
                }
            }
            let intent = ControlJournal.Receipt(title:operation.title,context:context ?? "model-presets",profile:profile)
            try await ControlReceipts.journal.begin(intent); receipt = intent; pending = intent
            guard matches(model,generation:generation,context:context),model.canSubmit else {
                try await ControlReceipts.journal.resolve(intent)
                if matches(model,generation:generation,context:context) { pending = nil }
                return false
            }
            let result = try await client.modelPresets(operation)
            try await ControlReceipts.journal.resolve(intent)
            guard matches(model,generation:generation,context:context) else { return false }
            pending = nil; committed = true
            if case .collection(let collection) = result { presets = collection.presets }
            // Read the actual inherited/effective selection rather than predicting it locally.
            if let context {
                let state = try await client.modelPresets(.getOverride(context:context))
                guard matches(model,generation:generation,context:context) else { return false }
                if case .overrideState(let state) = state { overrideState = state }
            }
            notice = nil
            return true
        } catch {
            if let known = error as? ModelPresetError,
               known == .invalidCollection || known == .invalidName || known == .overrideDisabled {
                do {
                    if let receipt { try await ControlReceipts.journal.resolve(receipt) }
                    guard matches(model,generation:generation,context:context) else { return false }
                    pending = nil; notice = known.errorDescription
                    return false
                } catch { /* Keep the unresolved receipt if protected storage is unavailable. */ }
            }
            guard matches(model,generation:generation,context:context) else { return false }
            if committed {
                notice = "The change was saved, but the current model selection could not be refreshed. Refresh before making another change."
            } else if let receipt, pending?.id == receipt.id {
                notice = "Outcome unconfirmed. Refresh and check the selected models before repeating this action. Nothing will be replayed."
            } else {
                let stored = try? await ControlReceipts.journal.pending(profile)
                guard matches(model,generation:generation,context:context) else { return false }
                pending = stored
                notice = "The request could not be completed. Refresh to check the current models."
            }
            return false
        }
    }
}
