import SwiftUI
import A0Core

@main struct AgentZeroSpikeApp: App {
    @State private var model = SpikeModel()
    @State private var importingQR = false
    @State private var showingSettings = false
    @State private var showingProjects = false
    @State private var projectFilter: String?
    @AppStorage("appearance",store:DisplayPreferences.store) private var appearance = "system"
    @State private var path: [ConversationRoute] = []
    @State private var search = ""
    @State private var startupFinished = false
    @State private var showingDrawer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var launchesIntoConversation: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--synthetic-launch-chat") || !args.contains(where: { $0.hasPrefix("--synthetic-") })
        #else
        return true
        #endif
    }
    private func closeDrawer() { withAnimation(reduceMotion ? nil : .easeOut(duration:0.22)) { showingDrawer = false } }
    private func selectChat(_ id: String) { closeDrawer(); model.select(id); path = [.chat(id)] }
    private func newChat() { closeDrawer(); model.select(nil); path = [.draft] }
    private func showDrawer() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil)
        withAnimation(reduceMotion ? nil : .easeOut(duration:0.22)) { showingDrawer = true }
    }
    @Environment(\.scenePhase) private var scenePhase
    private var chats: [SpikeModel.ChatSummary] {
        model.chatSummaries.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) && (projectFilter == nil || $0.project?.name == projectFilter) }
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack(path:$path) {
                List {
                    Section {
                        Image("AgentZeroWordmark").resizable().scaledToFit().frame(width:200,height:40)
                            .foregroundStyle(.primary).accessibilityLabel("Agent Zero").accessibilityIdentifier("agentZeroWordmark")
                        if model.connected || model.demo { ConnectionStatusView(model:model) }
                        else {
                            Text(model.status).font(.headline)
                            Text(model.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.listRowBackground(Color.clear)
                    if let notice = model.profileNotice { Section { Text(notice).font(.subheadline) } }
                    if !model.connected && !model.demo {
                        ServerConnectionSection(model:model)
                        Section { Button("Explore synthetic preview") { model.loadDemo() }.accessibilityIdentifier("syntheticPreview") }
                    } else {
                        Section {
                            Button {
                                model.select(nil); path = [.draft]
                            } label: {
                                Label("New chat",systemImage:"square.and.pencil").font(.headline).frame(minHeight:44)
                            }.accessibilityIdentifier("newChat")
                            if let chat = model.chat, !chat.draft.isEmpty || !chat.visibleDeliveries.isEmpty {
                                Button("Continue draft",systemImage:"text.bubble") {
                                    path = [chat.selectedContext.map(ConversationRoute.chat) ?? .draft]
                                }.accessibilityIdentifier("resumeConversation")
                            }
                        }
                        Section {
                            Button("Projects",systemImage:"folder") { showingProjects = true }.accessibilityIdentifier("openProjects")
                            ProjectChatFilter(chats:model.chatSummaries,selection:$projectFilter)
                        }
                        Section("Chats") {
                            ForEach(chats) { context in
                                Button {
                                    model.select(context.id); path = [.chat(context.id)]
                                } label: {
                                    HStack(spacing:12) {
                                        ProjectChatLabel(project:context.project)
                                        VStack(alignment:.leading,spacing:3) {
                                            Text(context.name).foregroundStyle(.primary).lineLimit(2)
                                            if let project = context.project { Text(project.displayTitle).font(.caption).foregroundStyle(Color.a0Supporting) }
                                        }
                                        Spacer(minLength:8)
                                        Image(systemName:"chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }.frame(minHeight:44)
                                }.accessibilityLabel(context.name).accessibilityValue(context.project.map { "Project: " + $0.displayTitle } ?? "No project")
                            }
                            if chats.isEmpty { Text(search.isEmpty ? "No chats yet. Start a new conversation." : "No matching chats").foregroundStyle(.secondary) }
                        }
                        Section { Button("Disconnect",role:.destructive) { model.disconnect() } }
                    }
                }
                .scrollContentBackground(.hidden).background(Color("A0Canvas"))
                .navigationTitle(model.connected || model.demo ? "Chats" : "Connect")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text:$search,prompt:"Search chats")
                .navigationDestination(for:ConversationRoute.self) { route in ConversationView(model:model,route:route,onSelectChat:selectChat,onNewChat:newChat,onOpenSidebar:showDrawer,hidesBackButton:launchesIntoConversation,sidebarOpen:showingDrawer).id(route) }
                .toolbar {
                    ToolbarItem(placement:.topBarTrailing) {
                        Button("Settings",systemImage:"gearshape") { showingSettings = true }.accessibilityIdentifier("openSettings")
                    }
                    if !model.connected && !model.demo {
                        ToolbarItem(placement:.topBarTrailing) {
                            Button("Scan server QR",systemImage:"qrcode.viewfinder") { importingQR = true }.disabled(model.connecting || model.profileBusy)
                        }
                    }
                }
                .sheet(isPresented:$showingSettings) { SettingsView(model:model) }
                .sheet(isPresented:$showingProjects) { ProjectsView(model:model,onOpenChat:{ id in showingProjects = false; model.select(id); path = [.chat(id)] }) }
                .sheet(isPresented:$importingQR) { QRImportView(model:model) }
                .safeAreaInset(edge:.bottom) {
                    if !model.connected && !model.demo { ConnectionActionBar(model:model) }
                }
            }
            .tint(Color("A0Tint"))
            .preferredColorScheme(DisplayPreferences.colorScheme(appearance))
            .accessibilityHidden(showingDrawer || !startupFinished)
            .overlay {
                if showingDrawer {
                    ConversationDrawer(model:model,onClose:closeDrawer,onSelect:selectChat,onNewChat:newChat)
                }
                if !startupFinished { LaunchSplashView(status:model.status) }
            }
            .task {
                guard !startupFinished else { return }
                defer { startupFinished = true }
                await model.loadProfiles()
                await model.restoreSession()
                if launchesIntoConversation && model.connected && model.chat != nil && path.isEmpty { newChat() }
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--synthetic-preview") { model.loadDemo() }
                #if DEBUG
                if args.contains("--synthetic-http-preview") && !args.contains("--synthetic-session-restore") {
                    model.origin = "https://fixture.agentzero.invalid"; model.username = "fixture"; model.password = "fixture"; model.connect()
                }
                if let index = args.firstIndex(of:"--loopback-probe"),args.indices.contains(index + 1) {
                    model.origin = args[index + 1]; model.localDevelopment = true; model.connect()
                }
                #endif
            }
            .onChange(of:model.connected) { _,connected in
                if !connected { path = []; projectFilter = nil; showingDrawer = false }
                else if launchesIntoConversation, model.chat != nil { newChat() }
                else if model.restoredSession, let id = model.chat?.selectedContext { path = [.chat(id)] }
            }
            .onChange(of:model.demo) { _,demo in
                if demo && launchesIntoConversation && model.chat != nil { newChat() }
            }
            .onChange(of:scenePhase) { _,phase in if phase == .background { model.suspend() } else if phase == .active { model.resume() } }
        }
    }
}
func deliveryLabel(_ status: Delivery.Status) -> String {
    switch status {
    case .creating: "Creating chat"
    case .sending: "Sending"
    case .accepted: "Accepted by server"
    case .queued: "Queued on server"
    case .cancelled: "Removed from queue"
    case .uncertain: "Outcome unknown"
    case .failed: "Not sent — edit and try again"
    }
}
