import SwiftUI
import A0Core

/// Live related conversations and current-chat historical activity stay distinct.
struct AgentActivitySheet: View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let model: SpikeModel
    var onSelectChat: ((String) -> Void)? = nil
    @State private var selectedAgent: Int?
    private var logs: [LogEntry] { model.state.logs }
    private var agents: [AgentActivitySummary] { AgentActivitySummary.make(logs) }
    private var context: String? { model.chat?.selectedContext }
    private var children: [SubagentRelationships.Conversation] { context.map { model.subagentRelationships.children(of:$0) } ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    if !children.isEmpty {
                        Text("Related conversations").font(.headline)
                        ForEach(children) { child in
                            childCard(child)
                        }
                    }
                    if agents.isEmpty && children.isEmpty {
                        ContentUnavailableView("No agent activity yet",systemImage:"person.2",description:Text("Agent steps and related conversations will appear here when the server reports them."))
                    } else if !agents.isEmpty {
                        Text("Latest recorded steps").font(.subheadline).foregroundStyle(theme.muted)
                        ForEach(agents) { agent in
                            activity(agent)
                            Divider()
                        }
                    }
                }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
                    .id("\(model.connectionGeneration.uuidString)-\(context ?? "draft")-\(model.state.logGUID ?? "pending")")
            }
            .foregroundStyle(theme.text)
            .background { ThemeBackdrop() }
            .navigationTitle("Agents").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
            .modifier(ThemeNavigationChrome())
        }
    }

    private func childCard(_ child: SubagentRelationships.Conversation) -> some View {
        let isNew = context.map { model.newSubagents(in:$0).contains(child.id) } ?? false
        return Button {
            // A sheet can remain open while a fresh collection removes or reparents a child.
            guard let current = context,
                  model.subagentRelationships.parent(of:child.id)?.id == current,
                  !model.state.needsFullSync else { return }
            onSelectChat?(child.id)
        } label: {
            HStack(alignment:.top,spacing:12) {
                Image(systemName:"person.crop.circle").font(.title3).foregroundStyle(theme.tint).padding(.top,2)
                VStack(alignment:.leading,spacing:6) {
                    Text(child.name).font(.headline).foregroundStyle(theme.text).fixedSize(horizontal:false,vertical:true)
                    if let profile = child.profile { Text(profile).font(.caption).foregroundStyle(theme.muted) }
                    if isNew { Text("New").font(.caption.weight(.semibold)).foregroundStyle(theme.tint) }
                    switch child.status {
                    case .working: Label("Working",systemImage:"circle.dotted").font(.caption).foregroundStyle(theme.muted)
                    case .paused: Label("Paused",systemImage:"pause.circle").font(.caption).foregroundStyle(theme.muted)
                    case .unspecified: EmptyView()
                    }
                    Text("Open chat").font(.subheadline.weight(.medium)).foregroundStyle(theme.tint)
                }
                Spacer(minLength:0)
                Image(systemName:"chevron.right").font(.caption.weight(.semibold)).foregroundStyle(theme.muted).padding(.top,5)
            }.padding(14).frame(maxWidth:.infinity,alignment:.leading).frame(minHeight:44)
                .background(theme.panel,in:RoundedRectangle(cornerRadius:16))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(onSelectChat == nil || model.state.needsFullSync)
            .accessibilityIdentifier("agentConversation-\(child.id)")
    }

    private func activity(_ agent: AgentActivitySummary) -> some View {
        let step = ActivityPresentation(agent.latest)
        return DisclosureGroup(isExpanded:Binding(get:{ selectedAgent == agent.agentNumber },set:{ selectedAgent = $0 ? agent.agentNumber : nil })) {
            ForEach(logs.filter { ActivityPresentation.agentNumber(for:$0) == agent.agentNumber },id:\.no) { entry in
                if MessagePresentation.isActivity(entry.type) {
                    ActivityTimelineRow(entry:entry,browserMedia:BrowserMediaScope(model:model))
                } else {
                    MessageRow(entry:entry,browserMedia:BrowserMediaScope(model:model),embedded:true).padding(.vertical,8)
                }
                Divider()
            }
        } label: {
            HStack(alignment:.top,spacing:12) {
                Image(systemName:agent.agentNumber == 0 ? "person.crop.circle" : "person.2").foregroundStyle(theme.muted)
                VStack(alignment:.leading,spacing:5) {
                    Text(agent.agentNumber == 0 ? "Agent Zero" : "Agent \(agent.agentNumber)").font(.headline)
                    Label(step.title,systemImage:step.symbol).font(.subheadline)
                    Text(step.summary == "Expand to inspect this step" ? "\(agent.count) recorded steps" : step.summary)
                        .font(.caption).foregroundStyle(theme.muted).lineLimit(3)
                }
            }.padding(.vertical,8)
        }.accessibilityIdentifier("agentDetails-\(agent.agentNumber)")
    }
}
