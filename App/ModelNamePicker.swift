import SwiftUI
import A0Core

/// Suggestions use the same server-side provider discovery as WebUI. Custom IDs remain editable.
struct ModelNamePicker:View {
    let model:SpikeModel
    let slot:ModelSlot
    let provider:String
    let apiBase:String
    @Binding var selection:String
    @State private var enteringCustom = false
    @State private var models:[String] = []
    @State private var query = ""
    @State private var customID = ""
    @State private var loading = false
    @State private var failed = false
    @State private var providerWarning = false
    @State private var reload = 0
    @FocusState private var customFocused:Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private struct RequestIdentity:Hashable {
        let generation:UUID
        let context:String?
        let provider:String
        let apiBase:String
        let slot:ModelSlot
        let reload:Int
    }
    private var identity:RequestIdentity {
        RequestIdentity(generation:model.connectionGeneration,context:model.chat?.selectedContext,provider:provider,apiBase:apiBase,slot:slot,reload:reload)
    }
    private var matching:[String] { query.isEmpty ? models : models.filter { $0.localizedCaseInsensitiveContains(query) } }
    private var trimmedCustomID:String { customID.trimmingCharacters(in:.whitespacesAndNewlines) }
    private var pickerList:some View {
        List {
            Section {
                Button {
                    enteringCustom.toggle()
                } label: {
                    Label(enteringCustom ? "Back to available models" : "Enter a custom model ID",systemImage:enteringCustom ? "list.bullet" : "pencil")
                }.accessibilityIdentifier("customModelShortcut")
            }
            if enteringCustom {
                Section {
                    TextField("Model name or ID",text:$customID)
                        .focused($customFocused)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("customModelID")
                    Button("Use custom model ID",systemImage:"checkmark") { choose(trimmedCustomID) }
                        .disabled(trimmedCustomID.isEmpty || trimmedCustomID.utf8.count > 2048)
                        .accessibilityIdentifier("applyCustomModelID")
                } header: { Text("Custom model") } footer: {
                    Text("Enter an exact model ID if it is not listed. Availability and access are managed by your provider.")
                }
            } else {
                Section {
                    if provider.isEmpty {
                        Text("Choose a provider to see its models.").foregroundStyle(Color.a0Supporting)
                    } else if loading {
                        ProgressView("Loading models…").accessibilityIdentifier("modelSearchLoading")
                    } else if failed {
                        Text("Model suggestions could not be loaded. Retry or enter a custom ID.").foregroundStyle(Color.a0Supporting).accessibilityIdentifier("modelSearchFailure")
                        Button("Retry models",systemImage:"arrow.clockwise") { reload += 1 }.accessibilityIdentifier("retryModels")
                    } else {
                        if providerWarning {
                            Text("The provider could not be reached. These are known models; enter a custom ID if yours is missing.").font(.footnote).foregroundStyle(Color.a0Supporting)
                        }
                        if matching.isEmpty {
                            Text(query.isEmpty ? "No models were returned. You can enter a custom ID." : "No models match your search.")
                                .foregroundStyle(Color.a0Supporting).accessibilityIdentifier("modelSearchEmpty")
                        }
                        ForEach(Array(matching.prefix(300)),id:\.self) { name in
                            Button { choose(name) } label: {
                                HStack(spacing:12) {
                                    Text(name).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                    Spacer(minLength:8)
                                    if name == selection { Image(systemName:"checkmark").foregroundStyle(Color("A0Tint")) }
                                }.frame(minHeight:32)
                            }.accessibilityIdentifier("modelOption-"+name)
                        }
                        if matching.count > 300 { Text("Search to narrow \(matching.count) models.").font(.footnote).foregroundStyle(Color.a0Supporting) }
                    }
                } header: { Text(provider.isEmpty ? "Available models" : "Models · \(provider)") }

            }
        }.accessibilityIdentifier("modelNameList")
    }
    var body:some View {
        pickerList
        .searchable(text:$query,placement:.navigationBarDrawer(displayMode:.always),prompt:"Search provider models")
        .navigationTitle(enteringCustom ? "Custom model" : "Choose model").navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement:.topBarTrailing) {
                Button("Refresh models",systemImage:"arrow.clockwise") { reload += 1 }
                    .disabled(enteringCustom || loading || provider.isEmpty).accessibilityIdentifier("refreshModels")
            }
        }
        .onAppear { customID = selection }
        .task(id:identity) { await load(identity) }
        .onChange(of:scenePhase) { _,phase in if phase == .background { customFocused = false; models = []; customID = ""; query = "" } }
    }
    private func choose(_ name:String) {
        guard scenePhase != .background,model.canSubmit else { return }
        selection = name; dismiss()
    }
    private func load(_ request:RequestIdentity) async {
        models = []; failed = false; providerWarning = false
        guard !provider.isEmpty else { loading = false; return }
        guard let client = model.controlClient,model.canSubmit else { loading = false; failed = true; return }
        loading = true
        do {
            let result = try await client.searchModels(provider:request.provider,slot:request.slot,apiBase:request.apiBase)
            guard !Task.isCancelled,request == identity,scenePhase != .background else { return }
            models = result.models; providerWarning = result.hasProviderError; loading = false
        } catch {
            guard !Task.isCancelled,request == identity,scenePhase != .background else { return }
            loading = false; failed = true
        }
    }
}
