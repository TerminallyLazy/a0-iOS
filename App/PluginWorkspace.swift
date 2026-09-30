import SwiftUI
import A0Core

/// Catalogs are transient. Only command intent enters the existing profile-isolated journal.
@MainActor @Observable final class PluginWorkspace {
    var plugins:[InstalledPlugin] = []
    var hub:[PluginHubEntry] = []
    var hubInstalled:Set<String> = []
    var busy = false
    var hubLoaded = false
    var notice:String?
    var pending:ControlJournal.Receipt?
    private var generation:UUID?
    private var journalReadable = false
    var canMutate:Bool { journalReadable && pending == nil && !busy }
    func installed(_ id:String) -> InstalledPlugin? { plugins.first { $0.id == id } }
    func profile(_ model:SpikeModel) -> ProfileIdentity? { try? ProfileIdentity(origin:ServerOrigin(model.origin),username:model.username) }
    func clear() { busy = false; plugins = []; hub = []; hubInstalled = []; hubLoaded = false; pending = nil; notice = nil; journalReadable = false; generation = nil }
    func load(_ model:SpikeModel,includeHub:Bool = false) async {
        let owner = model.connectionGeneration
        if generation != owner { clear(); generation = owner }
        guard !busy,model.canSubmit,!model.demo,let client = model.controlClient,let profile = profile(model) else { return }
        busy = true; defer { if generation == owner { busy = false } }
        do {
            let receipt = try await ControlReceipts.journal.pending(profile)
            guard owner == model.connectionGeneration else { return }
            pending = receipt; journalReadable = true
            let installed = try await client.installedPlugins()
            guard owner == model.connectionGeneration else { return }
            plugins = installed
            if includeHub {
                let catalog = try await client.pluginHub()
                guard owner == model.connectionGeneration else { return }
                hub = catalog.entries; hubInstalled = catalog.installedIDs; hubLoaded = true
            }
            notice = nil
        } catch {
            guard owner == model.connectionGeneration else { return }
            notice = includeHub ? "Plugin Hub could not be loaded. Check the connection and that Plugin Installer is available on this server." : "Plugins could not be loaded. Check the connection and refresh."
        }
    }
    func run(_ command:PluginCommand,model:SpikeModel) async -> Bool {
        guard canMutate,model.canSubmit,!model.demo,generation == model.connectionGeneration,
              let client = model.controlClient,let profile = profile(model) else { return false }
        let owner = model.connectionGeneration
        busy = true; notice = nil
        var intent:ControlJournal.Receipt?
        var acknowledged = false
        do {
            _ = try command.validatedRequest()
            let receipt = ControlJournal.Receipt(title:command.title,context:"plugin:"+command.pluginID,profile:profile)
            try await ControlReceipts.journal.begin(receipt); intent = receipt
            guard owner == model.connectionGeneration,model.canSubmit else {
                try await ControlReceipts.journal.resolve(receipt); if generation == owner { busy = false }; return false
            }
            pending = receipt
            try await client.performPluginCommand(command)
            try await ControlReceipts.journal.resolve(receipt)
            guard owner == model.connectionGeneration else { return false }
            pending = nil; acknowledged = true
        } catch {
            if owner == model.connectionGeneration {
                if intent != nil { notice = "Outcome unknown. Inspect the plugin before repeating this action. Nothing will be replayed." }
                else {
                    notice = "The command could not be prepared. Refresh before trying again."
                    let receipt = try? await ControlReceipts.journal.pending(profile)
                    if owner == model.connectionGeneration { pending = receipt }
                }
            }
        }
        if generation == owner { busy = false }
        if acknowledged {
            if command.pluginID == "selectable_theme" { model.themeRefreshRevision += 1 }
            await load(model,includeHub:hubLoaded)
        }
        return acknowledged
    }
    func resolve(_ model:SpikeModel) async {
        guard !busy,let pending,generation == model.connectionGeneration else { return }
        let owner = model.connectionGeneration
        do {
            try await ControlReceipts.journal.resolve(pending)
            guard owner == model.connectionGeneration else { return }
            self.pending = nil; notice = nil
        } catch { if owner == model.connectionGeneration { notice = "The saved command could not be cleared. Unlock this device and try again." } }
    }
}
