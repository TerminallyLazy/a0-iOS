import SwiftUI
import A0Core

@MainActor @Observable
final class ProjectWorkspace {
    var projects:[ProjectSummary] = []
    var busy = false
    var notice:String?
    var pending:ControlJournal.Receipt?
    var createdContext:String?
    private var journalReadable = false
    private var loadedGeneration:UUID?
    private var attemptedGeneration:UUID?
    func needsReload(_ model:SpikeModel) -> Bool { model.canSubmit && attemptedGeneration != model.connectionGeneration }
    var canMutate:Bool { !busy && journalReadable && pending == nil }
    private func profile(_ model:SpikeModel) -> ProfileIdentity? {
        try? ProfileIdentity(origin:ServerOrigin(model.origin),username:model.username)
    }
    func load(_ model:SpikeModel) async {
        let generation = model.connectionGeneration
        if loadedGeneration != generation { projects = []; pending = nil; createdContext = nil; journalReadable = false; notice = nil; loadedGeneration = generation }
        guard !busy,let profile = profile(model) else { return }
        do {
            let receipt = try await ControlReceipts.journal.pending(profile)
            guard generation == model.connectionGeneration else { return }
            pending = receipt; journalReadable = true
            if receipt?.title == "Create chat in project" { createdContext = receipt?.context }
        } catch { guard generation == model.connectionGeneration else { return }; journalReadable = false; notice = "Saved action state could not be read. Unlock this device and refresh."; return }
        if model.canSubmit { attemptedGeneration = generation }
        _ = await execute(.list,model:model)
    }
    func resolve(_ model:SpikeModel) async {
        guard !busy,let pending else { return }
        let generation = model.connectionGeneration
        do {
            try await ControlReceipts.journal.resolve(pending)
            guard generation == model.connectionGeneration else { return }
            self.pending = nil; notice = nil
        } catch { guard generation == model.connectionGeneration else { return }; notice = "The action receipt could not be updated. Unlock this device and try again." }
    }
    func execute(_ operation:ProjectOperation,model:SpikeModel) async -> ProjectResult? {
        guard !busy,model.canSubmit,!model.demo,let client = model.controlClient,let profile = profile(model),
              !operation.mutates || canMutate else { return nil }
        let generation = model.connectionGeneration, context = model.chat?.selectedContext
        busy = true; notice = nil
        defer { busy = false }
        var receipt:ControlJournal.Receipt?
        var submitted = false
        do {
            if operation.mutates {
                let intent = ControlJournal.Receipt(title:operation.title,context:context ?? "projects",profile:profile)
                try await ControlReceipts.journal.begin(intent); receipt = intent; pending = intent
            }
            guard generation == model.connectionGeneration,model.canSubmit,context == model.chat?.selectedContext else {
                if let receipt { try await ControlReceipts.journal.resolve(receipt); pending = nil }
                return nil
            }
            submitted = true
            let result = try await client.projects(operation)
            if let receipt { try await ControlReceipts.journal.resolve(receipt) }
            guard generation == model.connectionGeneration else { return nil }
            if receipt != nil { pending = nil }
            if case .list(let list) = result { projects = list; attemptedGeneration = generation }
            if operation.mutates {
                notice = "Project updated"
                if case .list(let list) = try? await client.projects(.list),generation == model.connectionGeneration { projects = list }
            }
            guard generation == model.connectionGeneration else { return nil }
            return result
        } catch {
            guard generation == model.connectionGeneration else { return nil }
            if receipt != nil && submitted { notice = "Outcome unknown. Refresh Projects and check the result before repeating this action." }
            else {
                let existing = try? await ControlReceipts.journal.pending(profile)
                guard generation == model.connectionGeneration else { return nil }
                pending = existing
                notice = "The request could not be completed. Check your connection and refresh."
            }
            return nil
        }
    }
    func newChat(project:String,model:SpikeModel) async -> String? {
        guard canMutate,model.canSubmit,!model.demo,let client = model.controlClient,let profile = profile(model) else { return nil }
        let generation = model.connectionGeneration, context = UUID().uuidString
        busy = true; notice = nil; createdContext = nil
        defer { busy = false }
        var receipt:ControlJournal.Receipt?
        do {
            let intent = ControlJournal.Receipt(title:"Create chat in project",context:context,profile:profile)
            try await ControlReceipts.journal.begin(intent); receipt = intent; pending = intent
            guard generation == model.connectionGeneration,model.canSubmit else {
                try await ControlReceipts.journal.resolve(intent); pending = nil; return nil
            }
            _ = try await client.createChat(id:context)
            guard generation == model.connectionGeneration,model.canSubmit else { return nil }
            createdContext = context
            _ = try await client.projects(.activate(name:project,context:context))
            try await ControlReceipts.journal.resolve(intent)
            guard generation == model.connectionGeneration else { return nil }
            pending = nil; return context
        } catch {
            guard generation == model.connectionGeneration else { return nil }
            notice = receipt == nil ? "Could not save the action intent. Unlock this device and try again." : "The outcome is unconfirmed. Check Projects and the chat before creating another. Nothing will be replayed."
            return nil
        }
    }
}
