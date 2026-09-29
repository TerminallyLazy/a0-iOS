import SwiftUI
import A0Core

private struct PresetDraft:Identifiable {
    let id = UUID()
    let originalName:String?
    var document:ModelPresetDocument
}

struct ModelPresetEditor:View {
    let model:SpikeModel
    let workspace:ModelPresetWorkspace
    private let baseline:[ModelPresetDocument]
    @State private var drafts:[PresetDraft]
    @State private var catalog:ModelProviderCatalog?
    @State private var catalogLoading = false
    @State private var catalogFailed = false
    @State private var catalogReload = 0
    @State private var deletion:UUID?
    @State private var confirmsDelete = false
    @State private var confirmsReset = false
    @State private var confirmsWeb = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    init(model:SpikeModel,workspace:ModelPresetWorkspace) {
        self.model = model; self.workspace = workspace; baseline = workspace.presets
        _drafts = State(initialValue:workspace.presets.map { PresetDraft(originalName:$0.name,document:$0) })
    }
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Text("Preset definitions are shared across Agent Zero. Saving changes affects every chat and project that uses these presets.").font(.callout).foregroundStyle(Color.a0Supporting)
                }
                Section("Presets") {
                    ForEach($drafts) { $draft in
                        NavigationLink {
                            ModelPresetFields(document:$draft.document,isDefault:draft.originalName == "Default",model:model,catalog:catalog,catalogLoading:catalogLoading,catalogFailed:catalogFailed,reloadCatalog:{ catalogReload += 1 })
                        } label: {
                            ModelPresetSummary(preset:draft.document,defaultPreset:drafts.first(where:{$0.document.name == "Default"})?.document)
                                .padding(.vertical,8)
                        }.accessibilityIdentifier("editPreset-"+(draft.originalName ?? draft.document.name))
                            .swipeActions(edge:.trailing,allowsFullSwipe:false) {
                                if draft.originalName != "Default" {
                                    Button("Delete",role:.destructive) { deletion = draft.id; confirmsDelete = true }
                                }
                            }
                    }
                    Button("Add preset",systemImage:"plus") { addPreset() }.accessibilityIdentifier("addModelPreset")
                }
                Section {
                    Button("Manage provider credentials in WebUI",systemImage:"key") { confirmsWeb = true }
                    Text("API keys and OAuth connections stay in Agent Zero’s provider settings. They are never stored in preset definitions.").font(.footnote).foregroundStyle(Color.a0Supporting)
                    Button("Reset presets to bundled defaults…",systemImage:"arrow.counterclockwise") { confirmsReset = true }.disabled(!workspace.canMutate)
                }
                if !validNames { Text("Each preset needs a unique name. Default must keep its name.").foregroundStyle(.red).font(.callout) }
                if let notice = workspace.notice { Text(notice).font(.callout).accessibilityIdentifier("presetEditorNotice") }
            }
            .accessibilityIdentifier("modelPresetEditorList")
            .navigationTitle("Edit presets").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() }.disabled(workspace.busy) }
            }
            .safeAreaInset(edge:.bottom) {
                Button { save() } label: {
                    HStack { if workspace.busy { ProgressView() }; Text("Save shared presets").fontWeight(.semibold) }.frame(maxWidth:.infinity,minHeight:46)
                }.buttonStyle(.borderedProminent).tint(Color("A0Tint")).foregroundStyle(Color("A0Canvas"))
                    .disabled(!validNames || !workspace.canMutate || !model.canSubmit).accessibilityIdentifier("saveModelPresets")
                    .padding(.horizontal,20).padding(.vertical,10).background(Color("A0Canvas"))
            }
            .interactiveDismissDisabled(workspace.busy)
            .confirmationDialog("Remove this preset?",isPresented:$confirmsDelete,titleVisibility:.visible) {
                Button("Remove from editor",role:.destructive) { drafts.removeAll { $0.id == deletion }; deletion = nil }
            } message: { Text("The preset is deleted when you save shared presets. Chats and projects that reference it fall back to Default.") }
            .confirmationDialog("Reset all shared presets?",isPresented:$confirmsReset,titleVisibility:.visible) {
                Button("Reset presets",role:.destructive) { reset() }
            } message: { Text("This replaces the server’s preset definitions with bundled defaults, affecting chats and projects that use them. Unsaved edits will be discarded.") }
            .confirmationDialog("Open provider settings in your browser?",isPresented:$confirmsWeb,titleVisibility:.visible) {
                Button("Open WebUI") { if let url = URL(string:model.origin),url.scheme == "https" { openURL(url) } }
            } message: { Text("\(model.origin)\nOpen Settings → Models to manage provider keys and connections.") }
            .onChange(of:scenePhase) { _,phase in if phase == .background { drafts = []; catalog = nil; dismiss() } }
            .onChange(of:model.connectionGeneration) { _,_ in drafts = []; catalog = nil; dismiss() }
            .onChange(of:model.chat?.selectedContext) { _,_ in drafts = []; catalog = nil; dismiss() }
        }
        .task(id:catalogReload) { await loadCatalog() }
    }
    private func loadCatalog() async {
        let generation = model.connectionGeneration, context = model.chat?.selectedContext
        guard let client = model.controlClient,model.canSubmit else { catalogFailed = true; return }
        catalogLoading = true; catalogFailed = false
        do {
            let result = try await client.modelProviderCatalog()
            guard !Task.isCancelled,generation == model.connectionGeneration,context == model.chat?.selectedContext,scenePhase != .background else { return }
            catalog = result; catalogLoading = false
        } catch {
            guard !Task.isCancelled,generation == model.connectionGeneration,context == model.chat?.selectedContext,scenePhase != .background else { return }
            catalogLoading = false; catalogFailed = true
        }
    }
    private var validNames:Bool {
        let names = drafts.map { $0.document.name.trimmingCharacters(in:.whitespacesAndNewlines) }
        return !names.contains("") && Set(names.map {$0.lowercased()}).count == names.count && drafts.contains { $0.originalName == "Default" && $0.document.name == "Default" }
    }
    private func addPreset() {
        let names = Set(drafts.map { $0.document.name.lowercased() })
        var name = "New preset", index = 2
        while names.contains(name.lowercased()) { name = "New preset \(index)"; index += 1 }
        drafts.append(PresetDraft(originalName:nil,document:ModelPresetDocument(name:name)))
    }
    private func save() {
        guard validNames else { return }
        let generation = model.connectionGeneration, context = model.chat?.selectedContext
        let documents = drafts.map { item -> ModelPresetDocument in var doc = item.document; doc.name = doc.name.trimmingCharacters(in:.whitespacesAndNewlines); return doc }
        let renames = drafts.compactMap { row -> ModelPresetRename? in
            guard let old = row.originalName,old != row.document.name.trimmingCharacters(in:.whitespacesAndNewlines) else { return nil }
            return ModelPresetRename(from:old,to:row.document.name.trimmingCharacters(in:.whitespacesAndNewlines))
        }
        Task {
            guard generation == model.connectionGeneration,context == model.chat?.selectedContext else { return }
            if await workspace.mutate(.save(documents,renames:renames),model:model,baseline:baseline) { dismiss() }
        }
    }
    private func reset() {
        let generation = model.connectionGeneration, context = model.chat?.selectedContext
        Task {
            guard generation == model.connectionGeneration,context == model.chat?.selectedContext else { return }
            if await workspace.mutate(.reset,model:model,baseline:baseline) { dismiss() }
        }
    }
}

private struct ModelPresetFields:View {
    @Binding var document:ModelPresetDocument
    let isDefault:Bool
    let model:SpikeModel
    let catalog:ModelProviderCatalog?
    let catalogLoading:Bool
    let catalogFailed:Bool
    let reloadCatalog:() -> Void
    @FocusState private var focused:Bool
    var body:some View {
        Form {
            Section("Name") {
                TextField("Preset name",text:$document.name).disabled(isDefault).focused($focused).accessibilityIdentifier("modelPresetName")
                if isDefault { Text("Default supplies the inherited Main, Utility and Embed settings.").font(.footnote).foregroundStyle(Color.a0Supporting) }
            }
            if catalogLoading { ProgressView("Loading providers…") }
            if catalogFailed {
                Section {
                    Text("Providers could not be loaded from Agent Zero. Your existing selections are unchanged.").font(.callout).foregroundStyle(Color.a0Supporting)
                    Button("Retry providers",systemImage:"arrow.clockwise",action:reloadCatalog)
                }
            }
            ModelSlotFields(document:$document,slot:.chat,title:"Main",isDefault:isDefault,model:model,catalog:catalog)
            ModelSlotFields(document:$document,slot:.vision,title:"Separate Vision",isDefault:false,model:model,catalog:catalog)
            ModelSlotFields(document:$document,slot:.utility,title:"Utility",isDefault:isDefault,model:model,catalog:catalog)
            ModelSlotFields(document:$document,slot:.embedding,title:"Embed",isDefault:isDefault,model:model,catalog:catalog)
        }
        .accessibilityIdentifier("modelPresetFields")
        .navigationTitle(document.name).navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement:.keyboard) { Spacer(); Button("Hide keyboard",systemImage:"keyboard.chevron.compact.down") { focused = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil) }.labelStyle(.iconOnly) } }
    }
}

private struct ModelSlotFields:View {
    @Binding var document:ModelPresetDocument
    let slot:ModelSlot
    let title:String
    let isDefault:Bool
    let model:SpikeModel
    let catalog:ModelProviderCatalog?
    @State private var parameters = false
    private var key:String { String(describing:slot) }
    private var values:[String:JSONValue] { document.slot(slot) }
    var body:some View {
        Section {
            if !isDefault {
                Toggle(slot == .vision ? "Use separate Vision model" : "Customize \(title) model",isOn:enabled)
            }
            if isDefault || !values.isEmpty {
                Picker("Provider",selection:provider) {
                    Text("Choose provider").tag("")
                    if !provider.wrappedValue.isEmpty,!providers.contains(where: { $0.id == provider.wrappedValue }) {
                        Text(provider.wrappedValue).tag(provider.wrappedValue)
                    }
                    ForEach(providers) { item in Text(item.label).tag(item.id) }
                }.pickerStyle(.navigationLink).disabled(catalog == nil).accessibilityIdentifier("preset-\(key)-provider")
                NavigationLink {
                    ModelNamePicker(model:model,slot:slot,provider:searchProvider,apiBase:searchAPIBase,selection:text("name"))
                } label: {
                    LabeledContent("Model") {
                        Text(values["name"]?.string.flatMap { $0.isEmpty ? nil : $0 } ?? "Choose model")
                            .foregroundStyle(Color.a0Supporting).multilineTextAlignment(.trailing).lineLimit(2)
                    }
                }.accessibilityIdentifier("preset-\(key)-model")
                if slot == .chat { Toggle("Supports vision",isOn:flag("vision")) }
                if slot == .vision { Toggle("Override Main’s native vision",isOn:flag("override_main")) }
                if slot == .chat || slot == .utility { number("Context window",key:"ctx_length",fallback:128000) }
                DisclosureGroup("Advanced settings") {
                    TextField("API base URL (optional)",text:text("api_base")).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if slot == .chat {
                        number("History fraction",key:"ctx_history",fallback:0.7)
                        number("Maximum image attachments",key:"max_embeds",fallback:10)
                    }
                    if slot == .utility { number("Input fraction",key:"ctx_input",fallback:0.7) }
                    if slot == .vision {
                        number("Timeout (seconds)",key:"timeout",fallback:120)
                        number("Maximum output tokens",key:"max_tokens",fallback:4096)
                    }
                    number("Requests per minute",key:"rl_requests",fallback:0)
                    number("Input tokens per minute",key:"rl_input",fallback:0)
                    if slot != .embedding { number("Output tokens per minute",key:"rl_output",fallback:0) }
                    Text("Zero rate limits mean unlimited.").font(.footnote).foregroundStyle(Color.a0Supporting)
                    Button("Additional parameters (JSON)",systemImage:"curlybraces") { parameters = true }
                }
            } else {
                Text(slot == .vision ? "This preset has no separate Vision model. Vision is never inherited from Default." : "Uses Default’s \(title) settings.").font(.footnote).foregroundStyle(Color.a0Supporting)
            }
        } header: { Text(title) } footer: {
            if slot == .vision && !values.isEmpty { Text("Main’s native vision takes precedence unless override is enabled. Vision call limits live in this preset.") }
        }
        .sheet(isPresented:$parameters) { ModelParametersEditor(values:Binding(get:{ values["kwargs"] ?? .object([:]) },set:{ set("kwargs",$0) })) }
    }
    private var providers:[ModelProvider] { catalog?.providers(for:slot) ?? [] }
    private var searchProvider:String {
        let own = values["provider"]?.string ?? ""
        return slot == .utility && own.isEmpty ? document.slot(.chat)["provider"]?.string ?? "" : own
    }
    private var searchAPIBase:String {
        let own = values["api_base"]?.string ?? ""
        return slot == .utility && own.isEmpty ? document.slot(.chat)["api_base"]?.string ?? "" : own
    }
    private var enabled:Binding<Bool> {
        Binding(get:{ !values.isEmpty },set:{ value in
            document.setSlot(slot,values:value ? ["provider":.string(""),"name":.string(""),"kwargs":.object([:])] : [:])
        })
    }
    private var provider:Binding<String> {
        Binding(get:{ values["provider"]?.string ?? "" },set:{ value in
            var current = values
            if current["provider"]?.string != value { current["api_base"] = .string(""); current["kwargs"] = .object([:]) }
            current["provider"] = .string(value); document.setSlot(slot,values:current)
        })
    }
    private func text(_ name:String) -> Binding<String> { Binding(get:{ values[name]?.string ?? "" },set:{ set(name,.string($0)) }) }
    private func flag(_ name:String) -> Binding<Bool> { Binding(get:{ values[name] == .bool(true) },set:{ set(name,.bool($0)) }) }
    private func set(_ name:String,_ value:JSONValue) { var current = values; current[name] = value; document.setSlot(slot,values:current) }
    private func number(_ label:String,key:String,fallback:Double) -> some View {
        LabeledContent(label) {
            TextField(label,value:Binding(get:{ if case .number(let number) = values[key] { return number }; return fallback },set:{ if $0.isFinite && $0 >= 0 { set(key,.number($0)) } }),format:.number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(minWidth:70)
        }
    }
}

private struct ModelParametersEditor:View {
    @Binding var values:JSONValue
    @State private var text = ""
    @State private var notice:String?
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            Form {
                Text("Provider-specific parameters as a JSON object. Keep API keys in provider settings.").font(.callout).foregroundStyle(Color.a0Supporting)
                TextEditor(text:$text).font(.system(.body,design:.monospaced)).frame(minHeight:240).privacySensitive().accessibilityLabel("Model parameters JSON")
                if let notice { Text(notice).foregroundStyle(.red) }
            }.navigationTitle("Additional parameters").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement:.confirmationAction) { Button("Apply") { apply() } }
                }
                .onAppear { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; text = (try? encoder.encode(values)).flatMap { String(data:$0,encoding:.utf8) } ?? "{}" }
        }
    }
    private func apply() {
        guard let data = text.data(using:.utf8),data.count <= 65_536,let value = try? JSONDecoder().decode(JSONValue.self,from:data),case .object = value else { notice = "Enter a valid JSON object of up to 64 KB."; return }
        values = value; dismiss()
    }
}
