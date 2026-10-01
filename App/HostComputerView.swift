import SwiftUI
import A0Core

struct HostComputerButton: View {
    let model: SpikeModel
    @Environment(\.a0Theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: HostConnection?
    @State private var presented = false
    @State private var refreshing = false
    @State private var unavailable = false
    @State private var refreshID = 0
    private var identity: String { "\(model.connectionGeneration)|\(model.chat?.selectedContext ?? "")|\(model.canSubmit)|\(scenePhase)|\(refreshID)" }
    private var title: String {
        if let draft = model.chat?.hostTask { return draft.generation == nil ? "Computer · review needed" : "Computer · \(draft.hostLabel)" }
        if unavailable { return "Computer · unavailable" }
        if let status, let label = status.hostLabel { return "Computer · \(label)" }
        return "Computer"
    }
    var body: some View {
        Button { presented = true } label: {
            Label(title, systemImage:"desktopcomputer").font(.caption)
                .foregroundStyle(theme.muted).frame(minHeight:44).padding(.horizontal,20)
        }.buttonStyle(.plain).accessibilityIdentifier("hostComputer")
        .frame(maxWidth:.infinity,alignment:.leading)
        .sheet(isPresented:$presented) {
            NavigationStack {
                ThemeForm {
                    Section {
                        NavigationLink { ComputerSetupView(model:model) } label: {
                            Label("Connect your computer",systemImage:"desktopcomputer.badge.plus")
                        }
                    }
                    Section(status?.context == nil ? "Computer connected to server" : "This chat's computer") {
                        Text(status?.hostLabel ?? "No verified computer").font(.headline)
                        Text(explanation).font(.callout).foregroundStyle(theme.muted)
                        if let status {
                            ForEach([("browser","Browser"),("computer_use","Computer use"),("files","Read files"),("file_write","Write files"),("code_execution","Code execution")],id:\.0) { key,label in
                                LabeledContent(label,value:capabilityLabel(status.capabilities[key]))
                            }
                            if status.bound {
                                Text(status.bindingCurrent ? "Host actions in this chat stay pinned to this computer." : "This chat's previous host target is stale. Review the current computer before another host task.")
                                    .font(.footnote)
                            }
                        }
                        Button { refreshID += 1 } label: {
                            Label(refreshing ? "Refreshing…" : "Refresh status",systemImage:"arrow.clockwise")
                        }.disabled(refreshing || !model.canSubmit)
                    }
                    Section("Prepare a task") {
                        ForEach(HostCapability.allCases,id:\.self) { capability in
                            Button(capability == .browser ? "Use my browser" : "Check my computer",systemImage:capability == .browser ? "globe" : "desktopcomputer") {
                                guard let selection = status?.selection(capability), let chat = model.chat else { return }
                                chat.selectHostTask(selection)
                                if chat.draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { chat.draft = capability.starter }
                                presented = false
                            }.disabled(unavailable || refreshing || !model.canSubmit || status?.selection(capability) == nil || model.chat?.attachments.isEmpty != true)
                        }
                        Text("Review the draft, then tap Send. Host tasks currently accept text in an existing chat. The computer must remain awake and connected.").font(.footnote)
                        if let draft = model.chat?.hostTask {
                            Text("Draft target: \(draft.hostLabel) · \(draft.capability.title)").font(.footnote)
                            Button("Remove target from this draft",role:.destructive) { model.chat?.clearHostTaskDraft() }
                            Text("Removing a draft target does not remove a server-side chat binding. Use a new chat for unrelated work.").font(.footnote)
                        }
                    }
                    Section("At the computer") {
                        Text("Connect A0 Launcher to the same Agent Zero server. Enable Browser or Computer Use there and complete any local permission prompts. Browser selection, shared folders and host Disconnect remain in Launcher.")
                        Text("Chat Stop cancels the server task and clears queued follow-ups. It is not a host-wide disconnect; an external action may already have happened.").font(.footnote)
                        Text("Screenshots and page content can be processed by your server's configured models.").font(.footnote)
                    }
                }.navigationTitle("Computer").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { presented = false } } }
            }.foregroundStyle(theme.text,theme.muted).tint(theme.tint)
        }
        .task(id:identity) {
            status = nil; unavailable = false; refreshing = false
            guard scenePhase == .active, model.canSubmit, !model.demo, let client = model.controlClient else { return }
            let identity = identity, context = model.chat?.selectedContext
            repeat {
                refreshing = true
                do {
                    let result = try await client.hostConnection(context:context)
                    try Task.checkCancellation()
                    guard identity == self.identity else { return }
                    status = result; unavailable = false; model.chat?.reconcileHost(result)
                } catch {
                    guard !Task.isCancelled, identity == self.identity else { return }
                    status = nil; unavailable = true; model.chat?.invalidateHostTask()
                }
                refreshing = false
                do { try await Task.sleep(for:.seconds(30)) } catch { return }
            } while !Task.isCancelled
        }
    }
    private var explanation: String {
        if model.demo { return "Computer access is unavailable in synthetic preview." }
        if unavailable { return "Status could not be verified. Ordinary chat remains available; host drafts need a fresh review." }
        if refreshing && status == nil { return "Checking the server's connector support…" }
        guard let status else { return "Connect to your server to check for an available computer." }
        switch status.state {
        case "unsupported": return "This server does not advertise compatible connector support. Chat still works normally."
        case "ambiguous": return "Multiple or competing clients are connected. Resolve this in Launcher before choosing a target."
        case "disconnected": return "No Launcher computer is connected. Open Launcher on the computer and connect it to this server."
        case "paused": return "Host access is paused. Enable it in Launcher on the computer."
        case "presence_only": return model.chat?.selectedContext == nil ? "Send an ordinary message or open an existing chat to review its host target." : "A computer is connected, but this server cannot verify this chat's target. Update Core for targeted tasks."
        case "needs_action": return "A capability needs attention on the computer. Available capabilities are listed separately."
        default: return "Readiness is reported by the connected host. Each task revalidates the target before dispatch."
        }
    }
    private func capabilityLabel(_ state: String?) -> String {
        switch state {
        case "ready": "Ready"
        case "off": "Off"
        case "container": "Server browser selected"
        case "needs_attention": "Needs local attention"
        case "unsupported": "Unsupported"
        default: "Not verified"
        }
    }
}
