import SwiftUI
import A0Core
import A0GenerativeUI

struct MessageRow: View {
    @Environment(\.a0Theme) private var theme
    let entry: LogEntry
    var jevSelected: GeneratedContent? = nil
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
        let mediaPreviews = ReplyMediaPreview.extract(entry)
        return VStack(alignment:.leading,spacing:12) {
            HStack(spacing:8) {
                if entry.type == "response" {
                    Image("AgentZeroMark").resizable().scaledToFit().frame(width:18,height:26).accessibilityHidden(true)
                } else { Image(systemName:entry.type == "user" ? "person.crop.circle" : presentation.symbol).foregroundStyle(theme.muted).accessibilityHidden(true) }
                VStack(alignment:.leading,spacing:3) {
                    Text(activity ? presentation.title : author).font(.subheadline.weight(.semibold))
                    if activity, let agent = presentation.agentLabel {
                        Text(agent).font(.caption).foregroundStyle(theme.muted)
                    }
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = content; copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy message",systemImage:copied ? "checkmark" : "doc.on.doc")
                        .labelStyle(.iconOnly).frame(width:44,height:44)
                }.accessibilityIdentifier("copyMessage-\(entry.no)").foregroundStyle(theme.muted)
            }
            if entry.type == "user", content != entry.content {
                DisclosureGroup("Rich reply instructions") { Text(GenerativeGuide.capabilities).font(.caption).textSelection(.enabled) }.font(.caption).foregroundStyle(theme.muted)
            }
            if !subtitle.isEmpty && (!activity || presentation.agentLabel == nil || !subtitle.contains(" · ")) {
                HStack(alignment:.firstTextBaseline,spacing:8) {
                    if !activity, let symbol = heading.symbol { Image(systemName:symbol).foregroundStyle(theme.muted).accessibilityHidden(true) }
                    InlineMarkdown(source:subtitle).font(activity ? .caption : .headline).foregroundStyle(activity ? theme.muted : Color.primary)
                }
            }
            if let browserMedia, let screenshot = BrowserScreenshot.extract(entry,context:browserMedia.context) {
                BrowserScreenshotView(screenshot:screenshot,scope:browserMedia,onOpen:onExpand)
            }
            if let candidates = JevCandidates.extract(entry) {
                if let selected = jevSelected {
                    GeneratedReplyView(content:selected,onInteract:onExpand,onDraft:onGeneratedDraft)
                } else {
                    MarkdownView(source:candidates.prose.isEmpty ? "This reply has no readable fallback. Ask Agent Zero to resend it as Markdown." : candidates.prose)
                }
            } else if let generated = GeneratedContent.extract(entry) {
                GeneratedReplyView(content:generated,onInteract:onExpand,onDraft:onGeneratedDraft)
            } else if collapsible && !expanded {
                if activity {
                    Text(presentation.summary).font(.subheadline).foregroundStyle(theme.muted).lineLimit(2)
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
                                        .font(.caption.weight(.semibold)).foregroundStyle(theme.muted)
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
            if !mediaPreviews.isEmpty {
                VStack(alignment:.leading,spacing:12) {
                    ForEach(mediaPreviews) { media in
                        GeneratedMedia(value:media.content,kind:media.kind).id(media.id)
                    }
                }.id(entry.content ?? "")
            }
        }
        .padding(!embedded && (entry.type == "user" || activity) ? 16 : 0)
        .foregroundStyle(theme.messageText)
        .background(!embedded && (entry.type == "user" || activity) ? theme.message : Color.clear,in:RoundedRectangle(cornerRadius:16))
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
    @Environment(\.a0Theme) private var theme
    let group: TranscriptGroup
    var browserMedia: BrowserMediaScope? = nil
    let onExpand: () -> Void
    @State private var expanded = false
    private var agents: [AgentActivitySummary] { AgentActivitySummary.make(group.entries) }
    private var preview: LogEntry? { group.entries.last(where: { $0.type != "util" }) ?? group.entries.last }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Button {
                if !expanded { onExpand() }
                expanded.toggle()
            } label: {
                HStack(spacing:10) {
                    Image(systemName:"point.3.connected.trianglepath.dotted").foregroundStyle(theme.muted)
                    Text("Agent activity").font(.subheadline.weight(.semibold))
                    Spacer(minLength:4)
                    Text("\(group.entries.count) steps").font(.caption.monospacedDigit()).foregroundStyle(theme.muted)
                    Image(systemName:expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                }.frame(minHeight:44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("activityGroup-\(group.id)")
                .accessibilityValue("\(group.entries.count) recorded steps, \(expanded ? "expanded" : "collapsed")")
            if !expanded, let entry = preview {
                let step = ActivityPresentation(entry)
                VStack(alignment:.leading,spacing:6) {
                    Text("Latest recorded step").font(.caption).foregroundStyle(theme.muted)
                    ActivityStepHeading(presentation:step)
                    if step.summary != "Expand to inspect this step" {
                        Text(step.summary).font(.caption).foregroundStyle(theme.muted).lineLimit(2)
                    }
                    if agents.count > 1 {
                        Label(agents.map { "A\($0.agentNumber)" }.joined(separator:" · "),systemImage:"person.2")
                            .font(.caption).foregroundStyle(theme.muted)
                            .accessibilityLabel("Recorded agents: " + agents.map { "Agent \($0.agentNumber)" }.joined(separator:", "))
                    }
                }.padding(.bottom,8)
            }
            if !expanded, let browserMedia {
                let captures = group.entries.compactMap { entry in BrowserScreenshot.extract(entry,context:browserMedia.context).map { (id:String(entry.no) + "|" + $0.id,screenshot:$0) } }
                if !captures.isEmpty {
                    ForEach(Array(captures.suffix(3)),id:\.id) { capture in
                        BrowserScreenshotView(screenshot:capture.screenshot,scope:browserMedia,onOpen:onExpand)
                    }
                    if captures.count > 3 {
                        Text("\(captures.count - 3) earlier captures in activity details").font(.caption).foregroundStyle(theme.muted)
                    }
                }
            }
            if expanded {
                VStack(spacing:0) {
                    ForEach(group.entries,id:\.no) { entry in
                        ActivityTimelineRow(entry:entry,browserMedia:browserMedia,
                                            continues:entry.no != group.entries.last?.no,onExpand:onExpand)
                    }
                }
            }
        }.padding(.horizontal,16).padding(.vertical,8)
            .background(theme.panel,in:RoundedRectangle(cornerRadius:16))
    }
}

/// A compact entry keeps tool arguments out of the reading path until requested.
struct ActivityTimelineRow: View {
    @Environment(\.a0Theme) private var theme
    let entry: LogEntry
    var browserMedia: BrowserMediaScope?
    var continues = false
    var onExpand: () -> Void = {}
    @ScaledMetric(relativeTo:.subheadline) private var iconWidth:CGFloat = 26
    @ScaledMetric(relativeTo:.subheadline) private var iconHeight:CGFloat = 44
    @State private var expanded = false
    @State private var copied = false
    @State private var pendingLink: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        let step = ActivityPresentation(entry)
        HStack(alignment:.top,spacing:10) {
            Image(systemName:step.symbol)
                .font(.subheadline).foregroundStyle(theme.muted)
                .frame(width:iconWidth,height:iconHeight).accessibilityHidden(true)
            VStack(alignment:.leading,spacing:0) {
                Button {
                    if !expanded { onExpand() }
                    expanded.toggle()
                } label: {
                    HStack(alignment:.top,spacing:8) {
                        VStack(alignment:.leading,spacing:5) {
                            ActivityStepHeading(presentation:step,showsSymbol:false)
                            if !expanded, step.summary != "Expand to inspect this step" {
                                Text(step.summary).font(.caption).foregroundStyle(theme.muted).lineLimit(1)
                            }
                        }.frame(maxWidth:.infinity,alignment:.leading)
                        Image(systemName:expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold)).foregroundStyle(theme.muted).padding(.top,3)
                    }.padding(.vertical,12).frame(minHeight:44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("\(expanded ? "collapseMessage" : "expandMessage")-\(entry.no)")
                    .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                    .accessibilityHint(expanded ? "Hide step details" : "Show step details")
                if let browserMedia, let screenshot = BrowserScreenshot.extract(entry,context:browserMedia.context) {
                    BrowserScreenshotView(screenshot:screenshot,scope:browserMedia,onOpen:onExpand).padding(.bottom,12)
                }
                if expanded {
                    VStack(alignment:.leading,spacing:12) {
                        if !step.subtitle.isEmpty && (step.agentLabel == nil || !step.subtitle.contains(" · ")) {
                            InlineMarkdown(source:step.subtitle).font(.caption).foregroundStyle(theme.muted)
                        }
                        if !step.isStructuredContent { MarkdownView(source:entry.content ?? "") }
                        if !step.fields.isEmpty {
                            DisclosureGroup {
                                VStack(alignment:.leading,spacing:12) {
                                    ForEach(step.fields.keys.sorted(),id:\.self) { key in
                                        let heading = LogHeading(key)
                                        VStack(alignment:.leading,spacing:4) {
                                            Label(heading.text.isEmpty ? "Detail" : heading.text.replacingOccurrences(of:"_",with:" ").capitalized,
                                                  systemImage:heading.symbol ?? "text.alignleft")
                                                .font(.caption.weight(.semibold)).foregroundStyle(theme.muted)
                                            Text(step.fields[key]?.displayText ?? "")
                                                .font(.system(.callout,design:.monospaced)).textSelection(.enabled)
                                        }.frame(maxWidth:.infinity,alignment:.leading)
                                    }
                                }.padding(.vertical,8)
                            } label: { Text("Details").frame(minHeight:44).contentShape(Rectangle()) }.font(.subheadline)
                        }
                        if step.isStructuredContent {
                            DisclosureGroup {
                                ScrollView(.horizontal) {
                                    Text(verbatim:entry.content ?? "").font(.system(.caption,design:.monospaced)).textSelection(.enabled)
                                }
                            } label: { Text("Raw event").frame(minHeight:44).contentShape(Rectangle()) }.font(.subheadline).accessibilityIdentifier("rawEvent-\(entry.no)")
                        }
                        Button {
                            UIPasteboard.general.string = entry.content ?? ""; copied = true
                        } label: {
                            Label(copied ? "Copied" : "Copy step",systemImage:copied ? "checkmark" : "doc.on.doc")
                                .font(.caption).frame(minHeight:44)
                        }.foregroundStyle(theme.muted).accessibilityIdentifier("copyMessage-\(entry.no)")
                    }.padding(.bottom,12)
                }
            }
        }
        .background(alignment:.topLeading) {
            if continues {
                Rectangle().fill(theme.muted.opacity(0.2)).frame(width:1)
                    .padding(.top,iconHeight - 6).padding(.leading,iconWidth / 2).accessibilityHidden(true)
            }
        }
        .environment(\.openURL,OpenURLAction { url in
            guard let safe = MessagePresentation.externalURL(url.absoluteString) else { return .discarded }
            pendingLink = safe; return .handled
        })
        .alert("Open external link?",isPresented:Binding(get:{ pendingLink != nil },set:{ if !$0 { pendingLink = nil } })) {
            Button("Open in browser") { if let url = pendingLink { openURL(url) }; pendingLink = nil }
            Button("Cancel",role:.cancel) { pendingLink = nil }
        } message: { Text(pendingLink?.host ?? "") }
    }
}

private struct ActivityStepHeading: View {
    @Environment(\.a0Theme) private var theme
    let presentation: ActivityPresentation
    var showsSymbol = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment:.firstTextBaseline,spacing:8) {
            if showsSymbol {
                Image(systemName:presentation.symbol).foregroundStyle(theme.muted).accessibilityHidden(true)
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment:.leading,spacing:4) { title; agent }
            } else {
                ViewThatFits(in:.horizontal) {
                    HStack(alignment:.firstTextBaseline,spacing:8) { title; agent }
                    VStack(alignment:.leading,spacing:4) { title; agent }
                }
            }
        }
    }
    private var title: some View { Text(presentation.title).font(.subheadline.weight(.medium)) }
    @ViewBuilder private var agent: some View {
        if let label = presentation.agentLabel {
            Text(label).font(.caption).foregroundStyle(theme.muted)
        }
    }
}

/// A read-only view of server-reported agent activity, with no inferred completion.
