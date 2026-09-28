import SwiftUI
import A0Core
import A0GenerativeUI

struct MessageRow: View {
    let entry: LogEntry
    var browserMedia: BrowserMediaScope? = nil
    var onExpand: () -> Void = {}
    var embedded = false
    var onGeneratedDraft: ((String) -> Void)? = nil
    @AppStorage("collapseLongMessages",store:DisplayPreferences.store) private var collapseLongMessages = true
    @State private var expanded = false
    @State private var copied = false
    @State private var pendingLink: URL?
    @Environment(\.openURL) private var openURL
    private var content: String { entry.type == "user" ? GenerativeChatAPI.visibleText(entry.content ?? "") : entry.content ?? "" }
    private var collapsible: Bool { activity || (collapseLongMessages && MessagePresentation.collapses(type:entry.type,content:content)) }
    private var activity: Bool { MessagePresentation.isActivity(entry.type) }
    private var author: String {
        if entry.type == "user" { return "You" }
        if entry.type == "response" { return ActivityPresentation.agentNumber(for:entry).map { $0 == 0 ? "Agent Zero" : "Agent \($0)" } ?? "Agent Zero" }
        return entry.type.replacingOccurrences(of:"_",with:" ").capitalized
    }
    var body: some View {
        let presentation = ActivityPresentation(entry)
        let heading = LogHeading(entry.heading ?? "")
        let subtitle = activity ? presentation.subtitle : heading.text
        return VStack(alignment:.leading,spacing:12) {
            HStack(spacing:8) {
                if entry.type == "response" {
                    Image("AgentZeroMark").resizable().scaledToFit().frame(width:18,height:26).accessibilityHidden(true)
                } else { Image(systemName:entry.type == "user" ? "person.crop.circle" : presentation.symbol).foregroundStyle(Color.a0Supporting).accessibilityHidden(true) }
                VStack(alignment:.leading,spacing:3) {
                    Text(activity ? presentation.title : author).font(.subheadline.weight(.semibold))
                    if activity, let agent = presentation.agentLabel {
                        Text(agent).font(.caption).foregroundStyle(Color.a0Supporting)
                    }
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = content; copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy message",systemImage:copied ? "checkmark" : "doc.on.doc")
                        .labelStyle(.iconOnly).frame(width:44,height:44)
                }.accessibilityIdentifier("copyMessage-\(entry.no)").foregroundStyle(Color.a0Supporting)
            }
            if entry.type == "user", content != entry.content {
                DisclosureGroup("Rich reply instructions") { Text(GenerativeGuide.capabilities).font(.caption).textSelection(.enabled) }.font(.caption).foregroundStyle(Color.a0Supporting)
            }
            if !subtitle.isEmpty && (!activity || presentation.agentLabel == nil || !subtitle.contains(" · ")) {
                HStack(alignment:.firstTextBaseline,spacing:8) {
                    if !activity, let symbol = heading.symbol { Image(systemName:symbol).foregroundStyle(Color.a0Supporting).accessibilityHidden(true) }
                    InlineMarkdown(source:subtitle).font(activity ? .caption : .headline).foregroundStyle(activity ? Color.a0Supporting : Color.primary)
                }
            }
            if let browserMedia, let screenshot = BrowserScreenshot.extract(entry,context:browserMedia.context) {
                BrowserScreenshotView(screenshot:screenshot,scope:browserMedia,onOpen:onExpand)
            }
            if let generated = GeneratedContent.extract(entry) {
                GeneratedReplyView(content:generated,onInteract:onExpand,onDraft:onGeneratedDraft)
            } else if collapsible && !expanded {
                if activity {
                    Text(presentation.summary).font(.subheadline).foregroundStyle(Color.a0Supporting).lineLimit(2)
                } else {
                    InlineMarkdown(source:String(content.prefix(300)).replacingOccurrences(of:"(?m)^#{1,6} ",with:"",options:.regularExpression)).lineLimit(5).clipped()
                }
                Button { onExpand(); expanded = true } label: {
                    Label(activity ? "Show activity" : "Show more",systemImage:"chevron.down")
                        .font(.subheadline.weight(.medium)).frame(minHeight:44)
                }
                    .accessibilityIdentifier("expandMessage-\(entry.no)")
            } else {
                if !activity || !presentation.isStructuredContent { MarkdownView(source:content) }
                if expanded, !presentation.fields.isEmpty {
                    DisclosureGroup("Details") {
                        VStack(alignment:.leading,spacing:12) {
                            ForEach(presentation.fields.keys.sorted(),id:\.self) { key in
                                VStack(alignment:.leading,spacing:4) {
                                    let fieldHeading = LogHeading(key)
                                    Label(fieldHeading.text.isEmpty ? "Detail" : fieldHeading.text.replacingOccurrences(of:"_",with:" ").capitalized,
                                          systemImage:fieldHeading.symbol ?? "text.alignleft")
                                        .font(.caption.weight(.semibold)).foregroundStyle(Color.a0Supporting)
                                    Text(presentation.fields[key]?.displayText ?? "").font(.system(.callout,design:.monospaced)).textSelection(.enabled)
                                }.frame(maxWidth:.infinity,alignment:.leading)
                            }
                        }.padding(.vertical,8)
                    }
                }
                if expanded, activity, presentation.isStructuredContent {
                    DisclosureGroup("Raw event") {
                        ScrollView(.horizontal) { Text(verbatim:content).font(.system(.caption,design:.monospaced)).textSelection(.enabled) }
                    }.font(.subheadline).accessibilityIdentifier("rawEvent-\(entry.no)")
                }
                if collapsible {
                    Button { expanded = false } label: {
                        Label("Show less",systemImage:"chevron.up").font(.subheadline.weight(.medium)).frame(minHeight:44)
                    }
                        .accessibilityIdentifier("collapseMessage-\(entry.no)")
                }
            }
        }
        .padding(!embedded && (entry.type == "user" || activity) ? 16 : 0)
        .background(!embedded && (entry.type == "user" || activity) ? Color("A0Panel") : Color.clear,in:RoundedRectangle(cornerRadius:16))
        .environment(\.openURL,OpenURLAction { url in
            guard let safe = MessagePresentation.externalURL(url.absoluteString) else { return .discarded }
            pendingLink = safe; return .handled
        })
        .alert("Open external link?",isPresented:Binding(get:{ pendingLink != nil },set:{ if !$0 { pendingLink = nil } })) {
            Button("Open in browser") { if let url = pendingLink { openURL(url) }; pendingLink = nil }
            Button("Cancel",role:.cancel) { pendingLink = nil }
        } message: { Text(pendingLink?.host ?? "") }
        .padding(.leading,entry.type == "user" ? 24 : 0)
        .frame(maxWidth:.infinity,alignment:.leading)
    }
}

private extension JSONValue {
    var displayText: String {
        if case .string(let value) = self { return value }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        return (try? String(decoding:encoder.encode(self),as:UTF8.self)) ?? ""
    }
}

struct ActivityGroupView: View {
    let group: TranscriptGroup
    var browserMedia: BrowserMediaScope? = nil
    let onExpand: () -> Void
    @State private var expanded = false
    private var agents: [AgentActivitySummary] { AgentActivitySummary.make(group.entries) }
    private var preview: [LogEntry] { Array(group.entries.filter { $0.type != "util" }.suffix(2)) }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Button {
                if !expanded { onExpand() }
                expanded.toggle()
            } label: {
                HStack(spacing:10) {
                    Image(systemName:"point.3.connected.trianglepath.dotted").foregroundStyle(Color.a0Supporting)
                    Text("Agent activity").font(.subheadline.weight(.semibold))
                    Spacer(minLength:4)
                    Text("\(group.entries.count)").font(.caption.monospacedDigit()).foregroundStyle(Color.a0Supporting)
                    Image(systemName:expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                }.frame(minHeight:44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("activityGroup-\(group.id)")
                .accessibilityValue("\(group.entries.count) recorded steps, \(expanded ? "expanded" : "collapsed")")
            if !expanded {
                let steps = preview.isEmpty ? Array(group.entries.suffix(1)) : preview
                ForEach(steps,id:\.no) { entry in
                    let step = ActivityPresentation(entry)
                    HStack(alignment:.top,spacing:12) {
                        Image(systemName:step.symbol).font(.system(size:18)).foregroundStyle(Color.a0Supporting).frame(width:28, height:24)
                        VStack(alignment:.leading,spacing:4) {
                            Text(step.title).font(.subheadline.weight(.medium))
                            if let agent = step.agentLabel { Text(agent).font(.caption).foregroundStyle(Color.a0Supporting) }
                            if step.summary != "Expand to inspect this step" {
                                Text(step.summary).font(.caption).foregroundStyle(Color.a0Supporting).lineLimit(2)
                            }
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }.padding(.bottom,4)
                }
                if agents.count > 1 {
                    Label(agents.map { "A\($0.agentNumber)" }.joined(separator:" · "),systemImage:"person.2")
                        .font(.caption).foregroundStyle(Color.a0Supporting)
                        .accessibilityLabel("Recorded agents: " + agents.map { "Agent \($0.agentNumber)" }.joined(separator:", "))
                }
            }
            if !expanded, let browserMedia {
                let captures = group.entries.compactMap { entry in BrowserScreenshot.extract(entry,context:browserMedia.context).map { (id:String(entry.no) + "|" + $0.id,screenshot:$0) } }
                if !captures.isEmpty {
                    ForEach(Array(captures.suffix(3)),id:\.id) { capture in
                        BrowserScreenshotView(screenshot:capture.screenshot,scope:browserMedia,onOpen:onExpand)
                    }
                    if captures.count > 3 {
                        Text("\(captures.count - 3) earlier captures in activity details").font(.caption).foregroundStyle(Color.a0Supporting)
                    }
                }
            }
            if expanded {
                ForEach(group.entries,id:\.no) { entry in
                    HStack(alignment:.top,spacing:12) {
                        VStack(spacing:0) {
                            Circle().fill(Color.a0Supporting).frame(width:5,height:5).padding(.top,20)
                            Rectangle().fill(Color.a0Supporting.opacity(0.25)).frame(width:1)
                        }.frame(width:8).accessibilityHidden(true)
                        MessageRow(entry:entry,browserMedia:browserMedia,onExpand:onExpand,embedded:true).padding(.bottom,12)
                    }
                }
            }
        }.padding(.horizontal,16).padding(.vertical,8)
            .background(Color("A0Panel"),in:RoundedRectangle(cornerRadius:16))
    }
}

/// A read-only view of server-reported agent activity, with no inferred completion.
struct AgentActivitySheet: View {
    let logs: [LogEntry]
    var browserMedia: BrowserMediaScope? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAgent: Int?
    private var agents: [AgentActivitySummary] { AgentActivitySummary.make(logs) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    if agents.isEmpty {
                        ContentUnavailableView("No agent activity yet",systemImage:"person.2",description:Text("Agent steps will appear here when the server reports them."))
                    } else {
                        Text("Latest recorded steps").font(.subheadline).foregroundStyle(Color.a0Supporting)
                        ForEach(agents) { agent in
                            let step = ActivityPresentation(agent.latest)
                            DisclosureGroup(isExpanded:Binding(get:{ selectedAgent == agent.agentNumber },set:{ selectedAgent = $0 ? agent.agentNumber : nil })) {
                                ForEach(logs.filter { ActivityPresentation.agentNumber(for:$0) == agent.agentNumber },id:\.no) { entry in
                                    MessageRow(entry:entry,browserMedia:browserMedia,embedded:true).padding(.vertical,8)
                                    Divider()
                                }
                            } label: {
                                HStack(alignment:.top,spacing:12) {
                                    Image(systemName:agent.agentNumber == 0 ? "person.crop.circle" : "person.crop.circle").foregroundStyle(Color.a0Supporting)
                                    VStack(alignment:.leading,spacing:5) {
                                        Text(agent.agentNumber == 0 ? "Agent Zero" : "Agent \(agent.agentNumber)").font(.headline)
                                        Label(step.title,systemImage:step.symbol).font(.subheadline)
                                        Text(step.summary == "Expand to inspect this step" ? "\(agent.count) recorded steps" : step.summary)
                                            .font(.caption).foregroundStyle(Color.a0Supporting).lineLimit(3)
                                    }
                                }.padding(.vertical,8)
                            }.accessibilityIdentifier("agentDetails-\(agent.agentNumber)")
                            Divider()
                        }
                    }
                }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
            }.background(Color("A0Canvas"))
                .navigationTitle("Agents").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
