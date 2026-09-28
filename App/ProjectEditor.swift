import SwiftUI
import A0Core

struct ProjectEditor:View {
    let model:SpikeModel
    let workspace:ProjectWorkspace
    @State var document:ProjectDocument
    let isNew:Bool
    let clone:Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var gitToken = ""
    @State private var editsSecrets = false
    @State private var secretsDraft = ""
    @State private var filePreview:String?
    @State private var showsPreview = false
    @State private var saveNotice:String?
    @State private var initialMCP:String?
    @FocusState private var editingText:Bool
    private var title:String { isNew ? (clone ? "Clone repository" : "New project") : "Edit project" }
    var body:some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Title",text:$document.title).focused($editingText).accessibilityIdentifier("projectTitle")
                    TextField("Folder name",text:$document.name).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(!isNew).focused($editingText).accessibilityIdentifier("projectName")
                    TextField("Description",text:$document.description,axis:.vertical).lineLimit(2...5).focused($editingText).accessibilityIdentifier("projectDescription")
                }
                Section("Color") {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:44),spacing:8)],spacing:8) {
                        ForEach(ProjectSummary.colors,id:\.self) { value in
                            Button { document.color = value } label: {
                                ZStack {
                                    ProjectDot(color:value,size:24)
                                    if document.color.lowercased() == value.lowercased() {
                                        Circle().strokeBorder(Color.primary,lineWidth:2).frame(width:34,height:34)
                                    }
                                }.frame(width:44,height:44)
                            }.buttonStyle(.plain).accessibilityLabel("Project color \(value)").accessibilityAddTraits(document.color.lowercased() == value.lowercased() ? .isSelected : [])
                        }
                    }
                    HStack { ProjectDot(color:document.color); TextField("Hex color",text:$document.color).textInputAutocapitalization(.never).autocorrectionDisabled().focused($editingText).accessibilityIdentifier("projectColor") }
                }
                if clone {
                    Section {
                        TextField("HTTPS Git repository URL",text:$document.gitURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().focused($editingText).accessibilityIdentifier("projectGitURL")
                        SecureField("Access token (optional)",text:$gitToken).textInputAutocapitalization(.never).autocorrectionDisabled().focused($editingText).privacySensitive()
                    } header: { Text("Repository") } footer: { Text("The server clones this repository. A token is sent only for this request and is not saved on this device. Enter a URL without embedded credentials.") }
                }
                Section("Instructions") {
                    TextEditor(text:$document.instructions).frame(minHeight:150).focused($editingText).accessibilityLabel("Project instructions").accessibilityIdentifier("projectInstructions")
                    Toggle("Include AGENTS.md",isOn:$document.includeAgentsMD)
                }
                DisclosureGroup("File structure in context") {
                    Toggle("Include file structure",isOn:structureEnabled)
                    Stepper("Depth: \(integer("max_depth",fallback:5))",value:structureNumber("max_depth",fallback:5),in:1...50)
                    Stepper("Files per folder: \(integer("max_files",fallback:20))",value:structureNumber("max_files",fallback:20),in:1...1000)
                    Stepper("Folders per level: \(integer("max_folders",fallback:20))",value:structureNumber("max_folders",fallback:20),in:1...1000)
                    Stepper("Maximum lines: \(integer("max_lines",fallback:250))",value:structureNumber("max_lines",fallback:250),in:1...5000)
                    Text("Ignored paths (.gitignore syntax)").font(.subheadline)
                    TextEditor(text:structureIgnore).font(.system(.body,design:.monospaced)).frame(minHeight:100).focused($editingText).accessibilityLabel("Ignored paths")
                    if !isNew {
                        Button("Preview file structure",systemImage:"list.bullet.indent") {
                            Task {
                                if case .fileStructure(let text) = await workspace.execute(.fileStructure(name:document.name,settings:document.fileStructure),model:model) { filePreview = text; showsPreview = true }
                            }
                        }.disabled(workspace.busy)
                    }
                }
                if !isNew {
                    DisclosureGroup("Variables") {
                        Text("Project environment variables, one KEY=value per line.").font(.footnote).foregroundStyle(Color.a0Supporting)
                        TextEditor(text:$document.variables).font(.system(.body,design:.monospaced)).frame(minHeight:140).focused($editingText).privacySensitive().accessibilityLabel("Project variables")
                    }
                    DisclosureGroup("MCP servers") {
                        Text("Project MCP configuration as JSON. Existing settings remain unchanged until you save.").font(.footnote).foregroundStyle(Color.a0Supporting)
                        TextEditor(text:$document.mcpServers).font(.system(.body,design:.monospaced)).frame(minHeight:180).focused($editingText).privacySensitive().accessibilityLabel("Project MCP configuration")
                    }
                    DisclosureGroup("Secrets") {
                        Toggle("Edit project secrets",isOn:$editsSecrets).onChange(of:editsSecrets) { _,value in secretsDraft = value ? document.secrets : "" }
                        if editsSecrets {
                            Text("Existing values stay masked. Use KEY=value lines to replace values. These edits are sent to Agent Zero only when you save.").font(.footnote).foregroundStyle(Color.a0Supporting)
                            TextEditor(text:$secretsDraft).font(.system(.body,design:.monospaced)).frame(minHeight:120).focused($editingText).privacySensitive().accessibilityLabel("Project secrets")
                        }
                    }
                }
                if let notice = saveNotice ?? workspace.notice { Section { Text(notice).font(.callout).accessibilityIdentifier("projectEditorNotice") } }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel") { clearSecrets(); dismiss() }.disabled(workspace.busy) }
                ToolbarItemGroup(placement:.keyboard) { Spacer(); Button("Hide keyboard",systemImage:"keyboard.chevron.compact.down") { editingText = false }.labelStyle(.iconOnly) }
            }
            .safeAreaInset(edge:.bottom) {
                Button { save() } label: {
                    HStack { if workspace.busy { ProgressView() }; Text(isNew ? (clone ? "Clone repository" : "Create project") : "Save changes").fontWeight(.semibold) }.frame(maxWidth:.infinity,minHeight:46)
                }.buttonStyle(.borderedProminent).tint(Color("A0Tint")).foregroundStyle(Color("A0Canvas"))
                    .disabled(!valid || !workspace.canMutate || !model.canSubmit).accessibilityIdentifier("saveProject")
                    .padding(.horizontal,20).padding(.vertical,10).background(Color("A0Canvas"))
            }
            .interactiveDismissDisabled(workspace.busy)
            .onAppear { if initialMCP == nil { initialMCP = document.mcpServers } }
            .onChange(of:scenePhase) { _,phase in
                if phase != .active { clearSecrets() }
                if phase == .background { document = ProjectDocument(name:"",title:""); initialMCP = nil; filePreview = nil; dismiss() }
            }
            .onChange(of:model.connectionGeneration) { _,_ in clearSecrets(); document = ProjectDocument(name:"",title:""); initialMCP = nil; filePreview = nil; dismiss() }
            .sheet(isPresented:$showsPreview) {
                NavigationStack {
                    ScrollView { Text(filePreview ?? "").font(.system(.footnote,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding() }
                        .navigationTitle("File structure").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { showsPreview = false } } }
                }
            }
        }
    }
    private var valid:Bool {
        let name = document.name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty,name != ".",name != "..",!name.contains("/"),!name.contains("\\"),name.rangeOfCharacter(from:.controlCharacters) == nil,!document.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return false }
        if clone { guard let url = URL(string:document.gitURL),url.scheme == "https",url.host != nil,url.user == nil,url.password == nil,url.query == nil,url.fragment == nil else { return false } }
        return true
    }
    private func save() {
        guard valid,workspace.canMutate else { return }
        saveNotice = nil
        var updated = document
        updated.name = document.name.trimmingCharacters(in:.whitespacesAndNewlines)
        if !isNew {
            if document.mcpServers != initialMCP && !document.mcpServers.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                guard let data = document.mcpServers.data(using:.utf8),let value = try? JSONSerialization.jsonObject(with:data),value is [String:Any] else { saveNotice = "MCP configuration must be a JSON object. Check its format before saving."; return }
            }
            if editsSecrets { updated.secrets = secretsDraft }
        }
        let token = gitToken, generation = model.connectionGeneration
        clearSecrets(); editingText = false
        Task {
            guard generation == model.connectionGeneration else { return }
            let operation:ProjectOperation = isNew ? (clone ? .clone(updated,gitToken:token) : .create(updated)) : .update(updated)
            if await workspace.execute(operation,model:model) != nil { dismiss() }
        }
    }
    private func clearSecrets() { gitToken = ""; secretsDraft = ""; editsSecrets = false }
    private var structureEnabled:Binding<Bool> {
        Binding(get:{ document.fileStructure["enabled"] != .bool(false) },set:{ document.fileStructure["enabled"] = .bool($0) })
    }
    private var structureIgnore:Binding<String> {
        Binding(get:{ document.fileStructure["gitignore"]?.string ?? "" },set:{ document.fileStructure["gitignore"] = .string($0) })
    }
    private func integer(_ key:String,fallback:Int) -> Int { if case .number(let n) = document.fileStructure[key],n.isFinite,n >= 0,n < 100_000 { return Int(n) }; return fallback }
    private func structureNumber(_ key:String,fallback:Int) -> Binding<Int> {
        Binding(get:{ integer(key,fallback:fallback) },set:{ document.fileStructure[key] = .number(Double($0)) })
    }
}
