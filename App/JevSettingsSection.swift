import SwiftUI
import A0Core
import A0GenerativeUI

struct JevSettingsSection: View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.scenePhase) private var phase
    let model:SpikeModel
    @State private var key = ""
    @State private var status = JevSettingsStatus(configured:false,enabled:false)
    @State private var busy = false
    @State private var notice:String?
    @State private var generation = UUID()
    @FocusState private var editing:Bool
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Label("Jev presentation selection",systemImage:"rectangle.3.group").font(.headline)
            Text("Jev helps choose how to present rich replies. Your key stays in this device’s Keychain for the selected server profile.")
                .font(.subheadline).foregroundStyle(theme.muted)
            SecureField("TYPESAFE_API_KEY",text:$key)
                .textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                .textFieldStyle(.plain).padding(12).foregroundStyle(theme.text)
                .background(theme.input,in:RoundedRectangle(cornerRadius:10)).focused($editing).accessibilityIdentifier("jevAPIKey")
                .disabled(busy || model.jevProfile == nil)
            HStack {
                Button(status.configured ? "Replace key" : "Save key") {
                    let submitted = key; key = ""; editing = false
                    mutate { store,profile in try await store.saveKey(submitted,for:profile) }
                }.buttonStyle(.borderedProminent).foregroundStyle(theme.onTint).accessibilityIdentifier("jevSaveKey")
                    .disabled(busy || key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || model.jevProfile == nil)
                if status.configured {
                    Button("Remove key",role:.destructive) {
                        key = ""; editing = false
                        mutate { store,profile in try await store.remove(profile) }
                    }.accessibilityIdentifier("jevRemoveKey").disabled(busy)
                }
            }.frame(minHeight:44)
            Text(status.configured ? "Key saved on this device" : "No key saved").font(.caption).foregroundStyle(theme.muted)
            Toggle("Use Jev",isOn:Binding(get:{status.enabled},set:{enabled in
                mutate { store,profile in try await store.setEnabled(enabled,for:profile) }
            })).accessibilityIdentifier("jevEnabled").disabled(busy || !status.configured || model.jevProfile == nil)
            Text("When enabled, future rich replies can send limited presentation intent and candidate descriptions directly to TypeSafe using your API quota. Descriptions can contain private information. Full chats, display values, images and form entries are not sent. Saving a key alone does not enable Jev. If selection fails, the readable reply remains available.")
                .font(.footnote).foregroundStyle(theme.muted)
            if model.jevProfile == nil { Text("Connect to a saved server to configure Jev.").font(.footnote).foregroundStyle(theme.muted) }
            if let notice { Text(notice).font(.footnote).foregroundStyle(theme.muted).accessibilityIdentifier("jevNotice") }
        }.padding(16).background(theme.panel,in:RoundedRectangle(cornerRadius:16))
            .task(id:model.jevProfile) { await reload() }
            .onChange(of:phase) { _,value in if value != .active { clear() } else { Task { await reload() } } }
            .onDisappear { clear() }
    }
    private func clear() { generation = UUID(); key = ""; editing = false; busy = false }
    private func reload() async {
        clear(); status = .init(configured:false,enabled:false)
        guard let profile = model.jevProfile else { return }
        let token = generation
        do {
            let value = try await model.jevSettingsStore().status(for:profile)
            guard token == generation, profile == model.jevProfile else { return }
            status = value; notice = nil
        } catch { if token == generation { notice = "Key status unavailable. Unlock the device and try again." } }
    }
    private func mutate(_ operation:@escaping @Sendable (JevSettingsStore,ProfileIdentity) async throws -> Void) {
        guard !busy, let profile = model.jevProfile else { return }
        busy = true; notice = nil; model.invalidateJev()
        let token = generation, store = model.jevSettingsStore()
        Task {
            do {
                try await operation(store,profile)
                let value = try await store.status(for:profile)
                guard token == generation, profile == model.jevProfile else { return }
                status = value
            } catch {
                guard token == generation, profile == model.jevProfile else { return }
                notice = "The change could not be saved securely. Unlock the device and try again."
            }
            if token == generation { busy = false }
        }
    }
}

#if DEBUG
/// Never sends synthetic UI fixture credentials over the network.
actor JevPreviewChooser: JevChoosing {
    func choose(_ batch:JevBatch,key:String) async throws -> JevChoice {
        if ProcessInfo.processInfo.arguments.contains("--synthetic-jev-failure") { throw JevError.unavailable }
        return JevChoice(candidateID:batch.candidates.first?.id ?? "Markdown",model:"synthetic-ui-fixture")
    }
}
#endif
