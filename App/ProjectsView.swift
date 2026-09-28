import SwiftUI
import A0Core

struct ProjectsView: View {
    let model:SpikeModel
    var onOpenChat:((String)->Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var workspace = ProjectWorkspace()
    @State private var search = ""
    @State private var editor:ProjectEditorRoute?
    @State private var confirmsResolved = false
    private var filtered:[ProjectSummary] {
        workspace.projects.filter { search.isEmpty || $0.displayTitle.localizedCaseInsensitiveContains(search) || $0.description.localizedCaseInsensitiveContains(search) }
    }
    var body:some View {
        NavigationStack {
            List {
                if let notice = workspace.notice { Section { Text(notice).font(.callout).accessibilityIdentifier("projectsNotice") } }
                if let receipt = workspace.pending {
                    Section("Check the previous action") {
                        Text("\(receipt.title) has an unconfirmed outcome. Check the server before allowing another action. It will not be replayed.")
                        if let context = workspace.createdContext {
                            Button("Check chat",systemImage:"bubble.left") { open(context) }
                        }
                        Button("I checked the outcome") { confirmsResolved = true }
                    }
                }
                Section {
                    ForEach(filtered) { project in
                        NavigationLink {
                            ProjectDetailView(model:model,workspace:workspace,summary:project,onOpenChat:open)
                        } label: {
                            HStack(alignment:.center,spacing:14) {
                                ProjectDot(color:project.color,size:12)
                                VStack(alignment:.leading,spacing:4) {
                                    Text(project.displayTitle).font(.body.weight(.medium)).foregroundStyle(.primary)
                                    if !project.description.isEmpty { Text(project.description).font(.subheadline).foregroundStyle(Color.a0Supporting).lineLimit(2) }
                                }
                                Spacer(minLength:4)
                                if activeName == project.name { Image(systemName:"checkmark.circle.fill").accessibilityLabel("Active in this chat") }
                            }.frame(minHeight:44)
                        }.accessibilityIdentifier("project-"+project.name)
                    }
                }
                if filtered.isEmpty && !workspace.busy {
                    ContentUnavailableView(search.isEmpty ? "No projects yet" : "No matching projects",systemImage:"folder",description:Text(search.isEmpty ? "Keep related chats, instructions and files together. Create a project or clone a repository." : "Try a different project name."))
                        .listRowBackground(Color.clear)
                }
                if workspace.busy { ProgressView("Loading projects…").frame(maxWidth:.infinity).listRowBackground(Color.clear) }
            }
            .scrollContentBackground(.hidden).background(Color("A0Canvas"))
            .navigationTitle("Projects").navigationBarTitleDisplayMode(.inline)
            .searchable(text:$search,prompt:"Find a project")
            .refreshable { await workspace.load(model) }
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement:.primaryAction) {
                    Menu {
                        Button("New project",systemImage:"folder.badge.plus") { editor = .init(clone:false) }
                        Button("Clone repository",systemImage:"arrow.triangle.branch") { editor = .init(clone:true) }
                    } label: { Image(systemName:"plus").frame(minWidth:44,minHeight:44) }
                    .accessibilityLabel("Add project").accessibilityIdentifier("addProject").disabled(!workspace.canMutate || !model.canSubmit)
                }
            }
            .task(id:model.connectionGeneration) { await workspace.load(model) }
            .onChange(of:model.canSubmit) { _,ready in if ready { Task { await workspace.load(model) } } }
            .onChange(of:workspace.busy) { _,busy in if !busy && workspace.needsReload(model) { Task { await workspace.load(model) } } }
            .sheet(item:$editor) { route in ProjectEditor(model:model,workspace:workspace,document:route.document,isNew:true,clone:route.clone) }
            .confirmationDialog("Have you checked the outcome on the server?",isPresented:$confirmsResolved,titleVisibility:.visible) {
                Button("Allow another action") { Task { await workspace.resolve(model) } }
            }
        }
    }
    private var activeName:String? {
        guard let id = model.chat?.selectedContext,let row = model.state.contexts.first(where:{$0["id"]?.string == id}),case .object(let project) = row["project"] else { return nil }
        return project["name"]?.string
    }
    private func open(_ context:String) { dismiss(); onOpenChat?(context) }
}

private struct ProjectEditorRoute:Identifiable {
    let id = UUID()
    let clone:Bool
    var document:ProjectDocument { var item = ProjectDocument(name:"",title:""); item.color = "#06d6a0"; return item }
}

private struct ProjectDetailView:View {
    let model:SpikeModel
    let workspace:ProjectWorkspace
    let summary:ProjectSummary
    let onOpenChat:(String)->Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var document:ProjectDocument?
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var confirmingWeb = false
    @State private var deletionName = ""
    var body:some View {
        List {
            Section {
                HStack(spacing:12) {
                    ProjectDot(color:document?.color ?? summary.color,size:14)
                    Text(document?.title.isEmpty == false ? document!.title : summary.displayTitle).font(.headline)
                }
                if let description = document?.description, !description.isEmpty { Text(description).foregroundStyle(Color.a0Supporting) }
                LabeledContent("Folder",value:summary.name).font(.caption).foregroundStyle(Color.a0Supporting)
            }
            Section("Conversations") {
                Button("New chat in project",systemImage:"square.and.pencil") {
                    Task { if let context = await workspace.newChat(project:summary.name,model:model) { onOpenChat(context) } }
                }.accessibilityIdentifier("newProjectChat").disabled(!canMutate)
                if let context = model.chat?.selectedContext {
                    Button("Use in current chat",systemImage:"checkmark.circle") {
                        Task { _ = await workspace.execute(.activate(name:summary.name,context:context),model:model) }
                    }.accessibilityIdentifier("activateProject").disabled(!canMutate)
                    if activeName == summary.name {
                        Button("Remove from current chat",systemImage:"minus.circle") {
                            Task { _ = await workspace.execute(.deactivate(context:context),model:model) }
                        }.accessibilityIdentifier("deactivateProject").disabled(!canMutate)
                    }
                }
            }
            if !projectChats.isEmpty {
                Section("Project chats") {
                    ForEach(projectChats) { chat in
                        Button { onOpenChat(chat.id) } label: {
                            Label(chat.name,systemImage:"bubble.left").foregroundStyle(.primary).frame(minHeight:44)
                        }.accessibilityIdentifier("project-chat-"+chat.id)
                    }
                }
            }
            Section("Project settings") {
                Button("Edit project",systemImage:"slider.horizontal.3") { editing = true }.disabled(document == nil || !canMutate).accessibilityIdentifier("editProject")
                if let document {
                    LabeledContent("Instruction files",value:count(document.fields["instruction_files_count"]))
                    LabeledContent("Knowledge files",value:count(document.fields["knowledge_files_count"]))
                }
                Button("Open project tools in WebUI",systemImage:"safari") { confirmingWeb = true }
                Text("Manage project files, knowledge, memory, skills and model presets in the WebUI. Your browser may ask you to sign in.").font(.footnote).foregroundStyle(Color.a0Supporting)
            }
            if workspace.busy { ProgressView("Contacting Agent Zero…") }
            if let notice = workspace.notice { Text(notice).font(.callout).accessibilityIdentifier("projectDetailNotice") }
            if let context = workspace.createdContext,workspace.pending != nil { Button("Check chat",systemImage:"bubble.left") { onOpenChat(context) } }
            Section { Button("Delete project…",role:.destructive) { deletionName = ""; confirmingDelete = true }.disabled(!canMutate).accessibilityIdentifier("deleteProject") }
        }
        .navigationTitle("Project").navigationBarTitleDisplayMode(.inline)
        .task(id:summary.name) { await load() }
        .onChange(of:model.connectionGeneration) { _,_ in document = nil }
        .onChange(of:scenePhase) { _,phase in if phase == .background { document = nil } }
        .onChange(of:model.canSubmit) { _,ready in if ready { Task { await load() } } }
        .refreshable { await load() }
        .sheet(isPresented:$editing,onDismiss:{ Task { await load() } }) {
            if let document { ProjectEditor(model:model,workspace:workspace,document:document,isNew:false,clone:false) }
        }
        .sheet(isPresented:$confirmingDelete) {
            NavigationStack {
                Form {
                    Section {
                        Label("Delete all project files",systemImage:"trash").font(.headline)
                        Text("This permanently deletes the entire project folder on Agent Zero, including its files, instructions, knowledge and settings. It also removes this project from every chat. This cannot be undone.")
                        Text("Type “\(summary.name)” to confirm.").font(.subheadline)
                        TextField("Project folder name",text:$deletionName).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("deleteProjectName")
                    }
                    if let notice = workspace.notice { Text(notice) }
                }
                .accessibilityIdentifier("projectDeleteForm")
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Delete project").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge:.bottom) {
                    Button(role:.destructive) {
                        Task {
                            if await workspace.execute(.delete(name:summary.name),model:model) != nil { confirmingDelete = false; dismiss() }
                        }
                    } label: {
                        Text("Permanently delete project").fontWeight(.semibold).frame(maxWidth:.infinity,minHeight:46)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(deletionName != summary.name || !canMutate).accessibilityIdentifier("confirmDeleteProject")
                    .padding(.horizontal,20).padding(.vertical,10).background(Color("A0Canvas"))
                }
                .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { confirmingDelete = false } } }
            }.interactiveDismissDisabled(workspace.busy)
        }
        .confirmationDialog("Open Agent Zero project tools in your browser?",isPresented:$confirmingWeb,titleVisibility:.visible) {
            Button("Open WebUI") { if let url = URL(string:model.origin),url.scheme == "https" { openURL(url) } }
        } message: { Text("\(model.origin)\nChoose Projects, then \(summary.displayTitle).") }
    }
    private var projectChats:[SpikeModel.ChatSummary] {
        let ids = Set(model.state.contexts.compactMap { row -> String? in
            guard ProjectSummary(context:row)?.name == summary.name else { return nil }
            return row["id"]?.string
        })
        return model.chatSummaries.filter { ids.contains($0.id) }
    }
    private var canMutate:Bool { workspace.canMutate && model.canSubmit }
    private var activeName:String? {
        guard let id = model.chat?.selectedContext,let row = model.state.contexts.first(where:{$0["id"]?.string == id}),case .object(let project) = row["project"] else { return nil }
        return project["name"]?.string
    }
    private func load() async {
        if case .document(let data) = await workspace.execute(.load(name:summary.name),model:model) { document = data }
    }
    private func count(_ value:JSONValue?) -> String { if case .number(let n) = value,n.isFinite,n >= 0,n < 1_000_000_000 { return String(Int(n)) }; return "—" }
}
