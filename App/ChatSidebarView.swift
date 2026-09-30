import SwiftUI
import A0Core

/// Compact navigation drawer; selection belongs to the app's stable route.
struct ChatSidebarView: View {
    @Environment(\.a0Theme) private var theme
    let model:SpikeModel
    let onSelect:(String)->Void
    let onNewChat:()->Void
    var onClose: () -> Void = {}
    @AccessibilityFocusState private var closeFocused: Bool
    @State private var search = ""
    @State private var settings = false
    @State private var projects = false
    @State private var plugins = false
    @State private var workspace = false
    @State private var projectFilter:String?
    private var chats:[SpikeModel.ChatSummary] { model.chatSummaries.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) && (projectFilter == nil || $0.project?.name == projectFilter) } }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image("AgentZeroWordmark").resizable().scaledToFit().frame(maxWidth: 176).frame(height: 34).accessibilityLabel("Agent Zero")
                    Spacer(minLength: 0)
                    Button(action:onClose) { Label("Close sidebar",systemImage:"xmark").labelStyle(.iconOnly).font(.system(size:18,weight:.medium)).frame(width:44,height:44) }
                        .accessibilityIdentifier("sidebarClose").accessibilityFocused($closeFocused)
                }.padding(.horizontal,16).padding(.top,8)
                    .contentShape(Rectangle())
                    .simultaneousGesture(DragGesture(minimumDistance:30).onEnded { value in
                        if value.translation.width < -70 && abs(value.translation.width) > abs(value.translation.height) * 2 { onClose() }
                    })
                HStack(spacing:10) {
                    Image(systemName:"magnifyingglass").foregroundStyle(theme.muted)
                    TextField("Find a conversation",text:$search).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("sidebarSearch")
                }.padding(12).background(theme.panel,in:RoundedRectangle(cornerRadius:12)).padding(.horizontal,16).padding(.vertical,8)
            List {
                Section {
                    Button { onNewChat() } label: { Label("New conversation",systemImage:"square.and.pencil").font(.headline).frame(minHeight:44) }.accessibilityIdentifier("sidebarNewChat")
                }.listRowBackground(Color.clear)
                Section {
                    Button("Projects",systemImage:"folder") { projects = true }.accessibilityIdentifier("sidebarProjects")
                    Button("Plugins",systemImage:"puzzlepiece.extension") { plugins = true }.accessibilityIdentifier("sidebarPlugins")
                    Button("Workspace",systemImage:"sidebar.right") { workspace = true }.disabled(!model.canSubmit || model.demo).accessibilityIdentifier("sidebarWorkspace")
                    ProjectChatFilter(chats:model.chatSummaries,selection:$projectFilter)
                }
                Section("Conversations") {
                    ForEach(chats) { item in
                        Button { onSelect(item.id) } label: {
                            HStack(spacing:12) {
                                ProjectChatLabel(project:item.project)
                                VStack(alignment:.leading,spacing:3) {
                                    Text(item.name).foregroundStyle(theme.text).lineLimit(2)
                                    if let project = item.project { Text(project.displayTitle).font(.caption).foregroundStyle(theme.muted) }
                                }
                                Spacer(minLength:8)
                                if running(item.id) { Image(systemName:"waveform").foregroundStyle(theme.muted).accessibilityLabel("Working") }
                                if item.id == model.chat?.selectedContext { Image(systemName:"checkmark").font(.caption.weight(.semibold)).accessibilityLabel("Selected") }
                            }.frame(minHeight:44)
                        }.accessibilityIdentifier("sidebar-chat-"+item.id)
                            .listRowBackground(item.id == model.chat?.selectedContext ? theme.panel : Color.clear)
                    }
                    if chats.isEmpty {
                        Text(search.isEmpty && projectFilter == nil ? "Your conversations will appear here." : "No matching conversations").foregroundStyle(theme.muted)
                    }
                }
                if !model.state.tasks.isEmpty {
                    Section("Tasks") {
                        ForEach(Array(model.state.tasks.enumerated()),id:\.offset) { _,task in
                            Label(task["name"]?.string ?? task["title"]?.string ?? "Scheduled task",systemImage:"checklist")
                        }
                    }
                }

            }.scrollContentBackground(.hidden).background { ThemeBackdrop() }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
            Divider()
            Button { settings = true } label: { Label("Settings",systemImage:"gearshape").frame(maxWidth:.infinity,alignment:.leading).frame(minHeight:44) }
                .padding(.horizontal,20).padding(.vertical,8)
            }.background { ThemeBackdrop() }
                .toolbar(.hidden,for:.navigationBar)
                .task { closeFocused = true }
                .sheet(isPresented:$settings) { SettingsView(model:model) }
                .fullScreenCover(isPresented:$workspace) { PluginWebScreen(model:model,route:.workspace(contextID:model.chat?.selectedContext)) }
                .sheet(isPresented:$plugins) { PluginsView(model:model) }
                .sheet(isPresented:$projects) { ProjectsView(model:model,onOpenChat:{ id in projects = false; onSelect(id) }) }
        }
    }
    private func running(_ id:String) -> Bool { model.state.contexts.first(where:{$0["id"]?.string == id})?["running"] == .bool(true) }
}
