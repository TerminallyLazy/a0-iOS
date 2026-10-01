import SwiftUI
import A0Core
import TipKit

struct ComputerSetupTip: Tip {
    var title:Text { Text("Connect once, use it anywhere") }
    var message:Text? { Text("Start in Launcher, the WebUI, or here. Your computer handles its own permissions.") }
    var image:Image? { Image(systemName:"desktopcomputer") }
}

@MainActor @Observable final class ComputerSetupModel {
    var snapshot:ComputerSetupSnapshot?
    var continuation:ComputerSetupContinuation?
    var busy=false
    var stale=false
    var notice:String?
    var receipt:ControlJournal.Receipt?
    private var owner:UUID?
    // Setup continuation is independent of uncertain host input. It cannot grant
    // permissions or resume the host, and uses its own protected intent journal.
    static let journal:ControlJournal = {
        var directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("AgentZeroSetupReceipts")
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("--synthetic-") }) {
            let index=args.firstIndex(of:"--persistence-test-id")
            let namespace=index.flatMap { args.indices.contains($0+1) ? args[$0+1]:nil } ?? UUID().uuidString
            directory=FileManager.default.temporaryDirectory.appendingPathComponent("A0SetupFixtures").appendingPathComponent(namespace)
        }
        #endif
        return ControlJournal(directory:directory)
    }()
    private func profile(_ model:SpikeModel) throws -> ProfileIdentity { try ProfileIdentity(origin:ServerOrigin(model.origin),username:model.username) }
    func clear() { owner=nil;snapshot=nil;continuation=nil;receipt=nil;notice=nil;busy=false;stale=false }
    func load(_ model:SpikeModel) async {
        let generation=model.connectionGeneration
        if owner != generation { clear();owner=generation }
        guard !busy,model.canSubmit,!model.demo,let client=model.controlClient else { return }
        busy=true;defer { if owner==generation { busy=false } }
        do {
            let result=try await client.computerSetup()
            guard owner==generation,model.connectionGeneration==generation,!Task.isCancelled else { return }
            snapshot=result;stale=false;notice=nil
            let saved=try await Self.journal.pending(profile(model))
            guard owner==generation,model.connectionGeneration==generation else { return }
            receipt=saved
            if let saved, let requestID=saved.context.split(separator:":").last, UUID(uuidString:String(requestID)) != nil {
                let linked=try await client.computerSetupContinuation(action:"read",requestID:String(requestID))
                guard owner==generation,model.connectionGeneration==generation,linked.serverID==result.serverID else { return }
                continuation=linked
            }
        } catch {
            guard owner==generation,model.connectionGeneration==generation,!Task.isCancelled else { return }
            stale=true
            notice="Setup could not be refreshed. Sign in and check again. Older servers need an update; local setup remains available in Launcher."
        }
    }
    func change(_ action:String,model:SpikeModel,capabilities:[String]=[]) async {
        guard !busy,!stale,let snapshot,let client=model.controlClient,owner==model.connectionGeneration,model.canSubmit else { return }
        let generation=model.connectionGeneration
        busy=true;defer { if owner==generation { busy=false } }
        do {
            let requestID=action=="create" ? UUID().uuidString:continuation?.requestID
            guard let requestID else { return }
            // A successful read reconciles setup-only state before replacing the
            // previous intent. No host action is ever replayed here.
            if let receipt { try await Self.journal.resolve(receipt) }
            let next=ControlJournal.Receipt(title:action=="create" ? "Create setup code":action=="confirm" ? "Confirm computer":"Cancel setup request",context:"setup:"+requestID,profile:try profile(model))
            try await Self.journal.begin(next)
            guard owner==generation,model.connectionGeneration==generation,model.canSubmit else { return }
            receipt=next
            let result=try await client.computerSetupContinuation(action:action,requestID:requestID,capabilities:capabilities)
            guard owner==generation,model.connectionGeneration==generation,result.serverID==snapshot.serverID else { return }
            continuation=result;notice=nil
        } catch {
            guard owner==generation,model.connectionGeneration==generation else { return }
            stale=true;notice="The setup request may have completed. Check again to read its status. Nothing will be sent again automatically."
        }
    }
    func discardExpired(_ model:SpikeModel) async {
        guard !busy, let receipt else { return }
        do { try await Self.journal.resolve(receipt);self.receipt=nil;continuation=nil;stale=false;notice=nil }
        catch { notice="The saved setup request could not be cleared." }
    }
}

struct ComputerSetupView:View {
    let model:SpikeModel
    @Environment(\.a0Theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var setup=ComputerSetupModel()
    @State private var browser=true
    @State private var computer=false
    @State private var reset=false
    private let tip=ComputerSetupTip()
    var body:some View {
        ThemeForm {
            Section {
                TipView(tip).tipBackground(theme.panel)
                if let snapshot=setup.snapshot {
                    Text(snapshot.hostLabel ?? "No computer connected yet").font(.headline)
                    if setup.stale { Text("Last known status").font(.caption).foregroundStyle(theme.muted) }
                }
                if let notice=setup.notice { Text(notice).font(.callout).foregroundStyle(theme.muted) }
                Button("Check again",systemImage:"arrow.clockwise") { Task { await setup.load(model) } }.disabled(setup.busy)
            }
            if let snapshot=setup.snapshot {
                ForEach(snapshot.steps) { step in
                    Section {
                        if step.state == "ready" {
                            DisclosureGroup {
                                Text(step.detail).foregroundStyle(theme.muted)
                                Text(step.helpText ?? step.detail).font(.callout).foregroundStyle(theme.muted)
                            } label: { Label(step.title,systemImage:"checkmark.circle").font(.headline) }
                        } else {
                        Label(step.title,systemImage:step.state=="ready" ? "checkmark.circle":"circle").font(.headline)
                        Text(step.detail).foregroundStyle(theme.muted)
                        if step.state != "ready" {
                            Text(step.location=="here" ? "In Agent Zero WebUI":"On \(snapshot.hostLabel ?? "your computer")").font(.caption).foregroundStyle(theme.tint)
                        }
                        DisclosureGroup("Show me how") { Text(step.helpText ?? step.detail).font(.callout).foregroundStyle(theme.muted) }
                        }
                    }
                }
            }
            Section("Continue on my computer") {
                Toggle("Browser",isOn:$browser)
                Toggle("Computer",isOn:$computer)
                Button("Create setup code") { Task { await setup.change("create",model:model,capabilities:(browser ? ["browser"]:[]) + (computer ? ["computer_use"]:[])) } }
                    .disabled(setup.busy || setup.stale || setup.snapshot==nil || setup.receipt != nil || (!browser && !computer))
                if let continuation=setup.continuation {
                    Text(continuation.code).font(.title2.monospaced()).textSelection(.enabled).accessibilityLabel("Setup code \(continuation.code)")
                    Text("In Launcher, sign in to the same server, open the computer icon, and enter this code. It expires after 10 minutes and grants no access.").font(.footnote).foregroundStyle(theme.muted)
                    if let host=continuation.hostLabel { Text("Computer: \(host)") }
                    if continuation.state=="claimed" {
                        Button("Confirm this computer") { Task { await setup.change("confirm",model:model) } }.disabled(setup.busy || setup.stale)
                    }
                    if continuation.state=="confirmed" { Text("Confirmed. Review and allow the selected access in Launcher.").foregroundStyle(theme.muted) }
                    if continuation.state=="cancelled" { Text("Setup request cancelled.").foregroundStyle(theme.muted) }
                    else { Button("Cancel setup request",role:.destructive) { Task { await setup.change("cancel",model:model) } }.disabled(setup.busy || setup.stale) }
                }
                if setup.receipt != nil { Button("Forget this setup code") { reset=true } }
                Link("Get Launcher for your computer",destination:URL(string:"https://github.com/agent0ai/a0-launcher/releases/latest")!)
            }
        }.navigationTitle("Connect your computer").navigationBarTitleDisplayMode(.inline)
        .foregroundStyle(theme.text,theme.muted).tint(theme.tint)
        .task(id:"\(model.connectionGeneration)|\(scenePhase)") {
            guard scenePhase == .active else { setup.clear();return }
            repeat { await setup.load(model);do { try await Task.sleep(for:.seconds(5)) } catch { return } } while !Task.isCancelled
        }
        .onDisappear { setup.clear() }
        .confirmationDialog("Forget this setup request?",isPresented:$reset) {
            Button("Forget code",role:.destructive) { Task { await setup.discardExpired(model) } }
        } message: { Text("This removes its local record. The server request expires automatically. It does not change computer permissions or resume A0.") }
    }
}
