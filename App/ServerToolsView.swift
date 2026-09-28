import SwiftUI
import A0Core

struct ServerToolsView: View {
    let model:SpikeModel
    var onAttach: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo:.body) private var panelHeight:CGFloat = 350
    @State private var busy = false
    @State private var notice:String?
    @State private var result:AgentControlResult?
    @State private var resultTitle = ""
    @State private var showingResult = false
    @State private var pending:ControlJournal.Receipt?
    @State private var confirmingNudge = false
    @State private var confirmsResolved = false
    @State private var confirmsWeb = false
    private static var journal:ControlJournal { ControlReceipts.journal }
    private var profile:ProfileIdentity? { try? ProfileIdentity(origin:ServerOrigin(model.origin),username:model.username) }
    var body: some View {
        NavigationStack {
            List {
                if let onAttach {
                    Section {
                        Button(action:onAttach) {
                            Label("Attach images or files",systemImage:"paperclip").frame(minHeight:44)
                        }.accessibilityIdentifier("attachFiles")
                    }
                }
                Section {
                    Button(model.state.paused ? "Resume agent" : "Pause agent",systemImage:model.state.paused ? "play" : "pause") { run(.pause(!model.state.paused)) }
                        .disabled(!canControl || pending != nil).accessibilityIdentifier("pauseAgent")
                    Button("Nudge agent",systemImage:"hand.tap") { confirmingNudge = true }
                        .disabled(!canControl || pending != nil).accessibilityIdentifier("nudgeAgent")
                }
                Section {
                    Button("History",systemImage:"clock.arrow.circlepath") { run(.history) }.disabled(!canControl).accessibilityIdentifier("serverHistory")
                    Button("Context",systemImage:"rectangle.stack") { run(.context) }.disabled(!canControl).accessibilityIdentifier("serverContext")
                }
                if let pending {
                    Section("Check the previous action") {
                        Text("\(pending.title) has an unconfirmed outcome. Check the conversation before allowing another control action. It will not be replayed.")
                        Button("I checked the outcome") { confirmsResolved = true }.disabled(busy)
                    }
                }
                Section {
                    Button("Open full WebUI",systemImage:"safari") { confirmsWeb = true }.disabled(URL(string:model.origin) == nil)
                }
                if busy { ProgressView("Contacting Agent Zero…") }
                if let notice { Text(notice).font(.callout).accessibilityIdentifier("controlNotice") }
            }
            .listStyle(.plain)
            .navigationTitle("Tools").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(isPresented:$showingResult) {
                ScrollView {
                    if let result {
                        VStack(alignment:.leading,spacing:16) {
                            if let tokens = result.tokens { Label("\(tokens) tokens",systemImage:"text.word.spacing").font(.caption).foregroundStyle(Color.a0Supporting) }
                            Text(result.text.isEmpty ? "Nothing here yet." : result.text).font(.body).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                        }.padding(20)
                    }
                }.navigationTitle(resultTitle).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Back to tools") { showingResult = false }.accessibilityIdentifier("backToTools") } }
            }
            .task { await loadPending() }
            .confirmationDialog("Nudge this agent?",isPresented:$confirmingNudge,titleVisibility:.visible) {
                Button("Nudge agent") { run(.nudge) }
            } message: { Text("Resets the current process and prompts the agent to continue. This may interrupt work already running.") }
            .confirmationDialog("Have you checked the outcome?",isPresented:$confirmsResolved,titleVisibility:.visible) {
                Button("Allow another action") { Task { guard let pending else { return }; do { try await Self.journal.resolve(pending); self.pending = nil } catch { notice = "Could not update the receipt. Try again after unlocking the device." } } }
            }
            .confirmationDialog("Open Agent Zero in your browser?",isPresented:$confirmsWeb,titleVisibility:.visible) {
                Button("Open WebUI") { if let url = URL(string:model.origin),url.scheme == "https" { openURL(url) } }
            } message: { Text(model.origin) }
        }.frame(width:320,height:min(showingResult ? panelHeight + 100 : panelHeight,560))
    }
    private var canControl:Bool { !busy && model.canSubmit && !model.demo && model.chat?.selectedContext != nil }
    private func loadPending() async {
        guard let profile else { return }
        do { pending = try await Self.journal.pending(profile) }
        catch { notice = "Could not read saved action state. Controls are unavailable until it can be read."; busy = true }
    }
    private func run(_ action:AgentControl) {
        guard canControl,let client = model.controlClient,let context = model.chat?.selectedContext,let profile else { return }
        let generation = model.connectionGeneration
        busy = true; notice = nil
        Task {
            var receipt:ControlJournal.Receipt?
            do {
                if action.mutates {
                    let intent = ControlJournal.Receipt(title:action.title,context:context,profile:profile)
                    try await Self.journal.begin(intent); receipt = intent; pending = intent
                }
                guard generation == model.connectionGeneration,context == model.chat?.selectedContext,model.canSubmit else {
                    if let receipt { try await Self.journal.resolve(receipt); pending = nil }
                    busy = false; return
                }
                let response = try await client.perform(action,context:context)
                if let receipt { try await Self.journal.resolve(receipt) }
                guard generation == model.connectionGeneration,context == model.chat?.selectedContext else { busy = false; return }
                if receipt != nil { pending = nil }
                if action.mutates { notice = response.text }
                else { result = response; resultTitle = action.title; showingResult = true }
            } catch {
                guard generation == model.connectionGeneration else { busy = false; return }
                notice = receipt == nil ? "Could not complete the request. Check your connection and try again." : "Outcome unknown. Check History before repeating this action."
            }
            busy = false
        }
    }
}
