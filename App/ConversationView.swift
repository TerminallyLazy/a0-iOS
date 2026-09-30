import SwiftUI
import A0Core
import A0GenerativeUI

enum ConversationRoute: Hashable { case draft, chat(String) }

struct ConversationView: View {
    @Environment(\.a0Theme) private var theme
    let model: SpikeModel
    let route: ConversationRoute
    var onSelectChat: ((String) -> Void)?
    var onNewChat: (() -> Void)?
    var onOpenSidebar: (() -> Void)?
    var hidesBackButton = false
    var sidebarOpen = false
    @AccessibilityFocusState private var sidebarButtonFocused: Bool
    @State private var showingWorkspace = false
    @State private var showingTools = false
    @State private var showingAttachments = false
    @State private var showingAgents = false
    @State private var showingProjects = false
    @State private var follow = TranscriptFollowState()
    @State private var dragging = false
    @State private var showingSettings = false
    @AppStorage("groupActivity",store:DisplayPreferences.store) private var groupActivity = true
    @State private var bottomVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var title: String {
        guard let id = model.chat?.selectedContext else { return "New chat" }
        return model.chatSummaries.first { $0.id == id }?.name ?? "Conversation"
    }
    var body: some View {
        VStack(spacing:0) {
            Button { showingProjects = true } label: {
                HStack(spacing:8) {
                    ProjectChatLabel(project:currentProject)
                    Text(currentProject?.displayTitle ?? "No project").font(.subheadline)
                    Image(systemName:"chevron.down").font(.caption2)
                    Spacer()
                }.frame(minHeight:44).padding(.horizontal,20)
            }.buttonStyle(.plain).accessibilityIdentifier("conversationProject")
            if model.state.progressActive || model.state.paused || (model.state.needsFullSync && !model.state.logs.isEmpty) {
                workStatus
            }
            Divider()
            GeometryReader { viewport in
                ScrollViewReader { proxy in
                    ScrollView {
                        // Keep the bottom anchor outside lazy estimation. Tall replies can
                        // otherwise trap scrolling in repeated placement updates.
                        VStack(alignment:.leading,spacing:24) {
                            LazyVStack(alignment:.leading,spacing:24) {
                                if model.state.logs.isEmpty {
                                    emptyConversation
                                }
                                ForEach(TranscriptGroup.make(model.state.logs)) { group in
                                    if groupActivity && group.isActivity && group.entries.count > 1 {
                                        ActivityGroupView(group:group,browserMedia:BrowserMediaScope(model:model)) { follow.beginReading() }
                                            .id("\(model.state.logGUID ?? "pending")-activity-\(group.id)")
                                    } else {
                                        ForEach(group.entries,id:\.no) { entry in
                                            MessageRow(entry:entry,jevSelected:model.jevCoordinator?.selected[entry.no],browserMedia:BrowserMediaScope(model:model),onExpand:{ follow.beginReading() },onGeneratedDraft:{ text in
                                                guard let chat = model.chat else { return }
                                                chat.draft = chat.draft.isEmpty ? text : chat.draft + "\n\n" + text
                                            }).id("\(model.state.logGUID ?? "pending")-\(entry.no)")
                                        }
                                    }
                                }
                            }
                            DeliveryContent(model:model)
                            Color.clear.frame(height:1).id("latest")
                                .background(GeometryReader { geometry in
                                    Color.clear.preference(key:TranscriptBottom.self,value:geometry.frame(in:.named("transcript")).maxY)
                                })
                        }
                        .padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
                    }
                    .coordinateSpace(name:"transcript")
                    .scrollDismissesKeyboard(.interactively)
                    .onPreferenceChange(TranscriptBottom.self) { bottom in
                        bottomVisible = bottom <= viewport.size.height + 40
                        if follow.followsLatest && !dragging && !bottomVisible { proxy.scrollTo("latest",anchor:.bottom) }
                    }
                    .simultaneousGesture(DragGesture().onChanged { _ in dragging = true; follow.beginReading() }
                        .onEnded { _ in dragging = false; follow.observedBottom(bottomVisible) })
                    .onChange(of:model.state.logVersion) { _,_ in
                        if follow.followsLatest { proxy.scrollTo("latest",anchor:.bottom) }
                    }
                    .onChange(of:model.chat?.visibleDeliveries.count) { _,_ in
                        if follow.followsLatest { proxy.scrollTo("latest",anchor:.bottom) }
                    }
                    .onChange(of:model.state.context) { _,_ in follow.jumpToLatest(); proxy.scrollTo("latest",anchor:.bottom) }
                    .overlay(alignment:.bottomTrailing) {
                        if !follow.followsLatest {
                            Button {
                                follow.jumpToLatest()
                                withAnimation(reduceMotion ? nil : .easeOut(duration:0.2)) { proxy.scrollTo("latest",anchor:.bottom) }
                            } label: {
                                Label("Latest", systemImage: "arrow.down").labelStyle(.iconOnly)
                                    .font(.body.weight(.semibold)).frame(width: 36, height: 36)
                                    .foregroundStyle(theme.onTint).background(theme.tint, in: Circle())
                                    .frame(width: 44, height: 44).contentShape(Circle())
                            }.buttonStyle(.plain).padding(12)
                                .accessibilityLabel("Jump to latest reply")
                                .accessibilityIdentifier("jumpToLatest")
                        }
                    }
                }
                .overlay(alignment:.topTrailing) {
                    if !sidebarOpen {
                        WorkspaceEdgeTab(availableHeight:viewport.size.height) { showingWorkspace = true }
                            .disabled(!model.canSubmit || model.demo)
                    }
                }
            }
        }
        .background { ThemeBackdrop() }
        .sheet(isPresented:$showingSettings) { SettingsView(model:model) }
        .sheet(isPresented:$showingAgents) { AgentActivitySheet(logs:model.state.logs,browserMedia:BrowserMediaScope(model:model)) }
        .sheet(isPresented:$showingProjects) { ProjectsView(model:model,onOpenChat:{ id in showingProjects = false; onSelectChat?(id) }) }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .modifier(ThemeNavigationChrome())
        .navigationBarBackButtonHidden(hidesBackButton)
        .onChange(of:sidebarOpen) { _,open in if !open { sidebarButtonFocused = true } }
        .fullScreenCover(isPresented:$showingWorkspace) { PluginWebScreen(model:model,route:.workspace(contextID:model.chat?.selectedContext)) }
        .toolbar {
            if let onOpenSidebar {
                ToolbarItem(placement:.topBarLeading) {
                    Button(action:onOpenSidebar) {
                        Label("Open sidebar",systemImage:"sidebar.left").labelStyle(.iconOnly).font(.system(size:20)).frame(width:44,height:44)
                    }.accessibilityIdentifier("openSidebar").accessibilityFocused($sidebarButtonFocused)
                }
            }
            ToolbarItem(placement:.topBarTrailing) {
                Button { showingAgents = true } label: {
                    Label("Agents",systemImage:"person.2").labelStyle(.iconOnly).frame(width:44,height:44)
                }.accessibilityIdentifier("agentActivity")
            }
            ToolbarItem(placement:.topBarTrailing) {
                Menu {
                    if onSelectChat != nil {
                        Button("Chats",systemImage:"sidebar.left") { onOpenSidebar?() }
                    }
                    Button("Chat tools",systemImage:"slider.horizontal.3") { showingTools = true }
                    Button("Settings",systemImage:"gearshape") { showingSettings = true }
                    Button("Disconnect",systemImage:"network.slash",role:.destructive) { model.disconnect() }
                } label: { Label("Conversation options",systemImage:"ellipsis").foregroundStyle(theme.text).frame(minWidth:44,minHeight:44) }
                .accessibilityIdentifier("conversationOptions")
            }
        }
        .safeAreaInset(edge:.bottom,spacing:0) {
            if let chat = model.chat {
                ChatComposer(chat:chat, connectionReady:model.canSubmit, contextModel:model, onTools:{ showingTools = true },
                             conversationID:model.chat?.selectedContext ?? "draft", latestReply:latestReply) { await model.send() }
                    .attachmentPicker(chat:chat,isPresented:$showingAttachments)
                    .popover(isPresented:$showingTools,attachmentAnchor:.point(UnitPoint(x:0.08,y:0.5)),arrowEdge:.bottom) {
                        ServerToolsView(model:model,onAttach:{ showingTools = false; showingAttachments = true }).presentationCompactAdaptation(.popover)
                    }
            }
        }
    }
    private var currentProject:ProjectSummary? { model.chatSummaries.first(where:{$0.id == model.chat?.selectedContext})?.project }
    private var latestReply: String? {
        guard let entry = model.state.logs.last(where: { $0.type == "response" }) else { return nil }
        let prose = JevCandidates.extract(entry)?.prose ?? GeneratedContent.extract(entry)?.prose ?? entry.content ?? ""
        return MarkdownDocument.parse(prose).compactMap { block -> String? in
            let text: String
            switch block {
            case .heading(_,let value), .paragraph(let value), .listItem(_,let value), .quote(let value): text = value
            case .table(let rows): text = rows.map { $0.joined(separator:", ") }.joined(separator:". ")
            case .code, .divider: return nil
            }
            return (try? AttributedString(markdown:text)).map { String($0.characters) } ?? text
        }.joined(separator:"\n")
    }
    private var workStatus: some View {
        let status = AgentWorkPresentation(progress:model.state.progress, active:model.state.progressActive,
                                           paused:model.state.paused, synchronizing:model.state.needsFullSync)
        return HStack(alignment:.top,spacing:10) {
            if status.isWorking || model.state.needsFullSync { ProgressView().controlSize(.small).padding(.top,2) }
            else { Image(systemName:status.symbol).accessibilityHidden(true) }
            Text(status.title).font(.subheadline.weight(.medium)).fixedSize(horizontal:false,vertical:true)
            Spacer(minLength:0)
        }.padding(.horizontal,20).padding(.bottom,12).accessibilityElement(children:.combine)
            .accessibilityIdentifier("agentWorkStatus")
    }
    private var emptyConversation: some View {
        VStack(spacing:16) {
            Image("AgentZeroMark").resizable().scaledToFit().frame(width:48,height:72).foregroundStyle(theme.muted).accessibilityHidden(true)
            if model.state.needsFullSync && !model.demo {
                ProgressView("Loading conversation…")
            } else {
                Text(model.chat?.selectedContext == nil ? "What would you like to do?" : "No messages yet").font(.title2.weight(.semibold))
                Text("Send a message to Agent Zero.").font(.subheadline).foregroundStyle(theme.muted)
            }
        }.frame(maxWidth:.infinity).padding(.vertical,48)
    }
}
private struct TranscriptBottom: PreferenceKey {
    static let defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat,nextValue:()->CGFloat) { value = nextValue() }
}
struct ConnectionStatusView: View {
    @Environment(\.a0Theme) private var theme
    let model: SpikeModel
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:8) {
                Image(systemName:model.state.needsFullSync ? "arrow.triangle.2.circlepath" : "circle.fill")
                    .font(.caption2).foregroundStyle(model.state.needsFullSync ? Color.secondary : Color.green)
                Text(model.status).font(.caption.weight(.medium))
                Spacer()
                if model.state.paused { Label("Paused",systemImage:"pause.fill").font(.caption) }
                if model.recoveryStopped { Button { model.retrySync() } label: { Text("Retry sync").font(.caption).frame(minHeight:44) } }
            }
            if model.recoveryStopped || model.status == "Reconnecting" || model.detail.hasPrefix("Realtime retry") {
                Text(model.detail).font(.caption).foregroundStyle(theme.muted)
            }
        }.padding(.horizontal,20).padding(.vertical,10)
    }
}
struct DeliveryContent: View {
    @Environment(\.a0Theme) private var theme
    let model: SpikeModel
    var body: some View {
        if let chat = model.chat {
            ForEach(chat.visibleDeliveries) { delivery in
                VStack(alignment:.leading,spacing:8) {
                    if !delivery.text.isEmpty { Text(delivery.text).textSelection(.enabled) }
                    if let ids = delivery.attachmentIDs, !ids.isEmpty {
                        Label("\(ids.count) \(ids.count == 1 ? "attachment" : "attachments")",systemImage:"paperclip").font(.caption)
                    }
                    Label(deliveryLabel(delivery.status),systemImage:delivery.status == .uncertain ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.caption).foregroundStyle(theme.muted)
                    if delivery.status == .uncertain {
                        Text("The server may have received this message. Your draft is kept; sending is blocked until a matching server receipt arrives.")
                            .font(.caption).foregroundStyle(theme.muted)
                    }
                }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
                    .background(theme.panel,in:RoundedRectangle(cornerRadius:16))
            }
        }
    }
}

/// Stays attached to the physical edge without changing the transcript's layout.
private struct WorkspaceEdgeTab: View {
    @Environment(\.a0Theme) private var theme
    let availableHeight: CGFloat
    let open: () -> Void
    @AppStorage("workspaceTabPosition",store:DisplayPreferences.store) private var position = 0.5
    @GestureState private var translation: CGFloat = 0
    private var travel: CGFloat { max(0,availableHeight - 72) }
    private var offset: CGFloat { 8 + min(travel,max(0,CGFloat(position) * travel + translation)) }
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius:16,bottomLeadingRadius:16)
    }
    var body: some View {
        Button(action:open) {
            Image("AgentZeroMark").resizable().scaledToFit()
                .frame(width:26,height:42).foregroundStyle(theme.text)
                .frame(width:44,height:56)
                .background(theme.isActive ? AnyShapeStyle(theme.panel) : AnyShapeStyle(.regularMaterial),in:shape)
                .overlay { shape.strokeBorder(theme.border,lineWidth:0.5) }
                .shadow(color:.black.opacity(0.12),radius:4,x:-2,y:1)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .highPriorityGesture(DragGesture(minimumDistance:8,coordinateSpace:.global)
            .updating($translation) { value,state,_ in state = value.translation.height }
            .onEnded { value in
                guard travel > 0 else { return }
                position = min(1,max(0,position + Double(value.translation.height / travel)))
            })
        .offset(y:offset)
        .accessibilityLabel("Open Workspace")
        .accessibilityHint("Open server tools and plugin panels. Drag up or down to reposition.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: position = min(1,position + 0.15)
            case .decrement: position = max(0,position - 0.15)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("openWorkspace")
    }
}
