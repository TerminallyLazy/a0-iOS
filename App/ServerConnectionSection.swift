import SwiftUI
import A0Core

struct ServerConnectionSection: View {
    @Bindable var model: SpikeModel
    @State private var removing: SavedProfile?
    var body: some View {
        if !model.profiles.isEmpty {
            Section("Saved servers") {
                ForEach(model.profiles) { profile in
                    HStack {
                        Button { Task { await model.selectProfile(profile) } } label: {
                            VStack(alignment:.leading) {
                                Text(profile.name).font(.headline)
                                Text(profile.identity.origin).font(.subheadline)
                                Text(profile.identity.username).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }.accessibilityIdentifier("savedProfile")
                        Menu {
                            Button("Remove saved server",role:.destructive) { removing = profile }
                        } label: {
                            Label("Server options",systemImage:"ellipsis.circle").labelStyle(.iconOnly).frame(minWidth:44,minHeight:44)
                        }.accessibilityIdentifier("profileOptions")
                    }
                }
            }.disabled(model.profileBusy || model.connecting)
        }
        Section {
            TextField("Profile name",text:$model.profileName)
            TextField("https://your-agent-zero.example",text:Binding(get:{ model.origin },set:{ model.editOrigin($0) }))
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("serverOrigin")
            #if DEBUG
            Toggle("Local development (loopback only)",isOn:$model.localDevelopment)
            #endif
            TextField("Username",text:Binding(get:{ model.username },set:{ model.editUsername($0) }))
                .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("Password",text:$model.password).textContentType(.password)
                .submitLabel(.go)
                .onSubmit { if model.canConnect { model.connect() } }
            Toggle("Remember password on this device",isOn:$model.rememberPassword).accessibilityIdentifier("rememberPassword")
            if model.credentialLoaded {
                Label("Password loaded from Keychain",systemImage:"key").font(.caption).foregroundStyle(.secondary)
                Button("Forget saved password") { Task { await model.forgetPassword() } }
            }
        } header: { Text("Your server") } footer: {
            Text("Server details are saved after sign-in. Password saving is optional and applies after successful sign-in; use Forget saved password to remove it now. Drafts remain on this device when you disconnect.")
        }.disabled(model.connecting || model.profileBusy)
        .confirmationDialog("Remove this saved server?",isPresented:Binding(get:{ removing != nil },set:{ if !$0 { removing = nil } }),titleVisibility:.visible) {
            if let profile = removing {
                Button("Remove server",role:.destructive) { removing = nil; Task { await model.removeProfile(profile) } }
                Button("Cancel",role:.cancel) { removing = nil }
            }
        } message: { Text("Removes these connection details and saved password. Local drafts and pending delivery records are kept. Nothing is deleted on the server.") }
    }
}
