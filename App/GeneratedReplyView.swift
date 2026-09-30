import SwiftUI
import A0GenerativeUI
import A2UISwiftUI
import A2UISwiftCore

/// A surface has the same lifetime as its reply/log epoch. Draft insertion is
/// delegated to the selected conversation; this view never sends a request.
struct GeneratedReplyView: View {
    @Environment(\.a0Theme) private var theme
    let content: GeneratedContent
    let onInteract: () -> Void
    let onDraft: ((String) -> Void)?
    @State private var session = GeneratedSession()
    @State private var loadedSource: String?
    @State private var failed = false
    @State private var review: ActionReview?
    @State private var added = false
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            if !content.prose.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { MarkdownView(source:content.prose) }
            if !content.complete {
                Label("Receiving interactive reply…",systemImage:"ellipsis.bubble").foregroundStyle(theme.muted)
            } else if failed {
                Label("This interactive reply couldn’t be displayed.",systemImage:"exclamationmark.bubble").font(.subheadline)
                Text("Ask Agent Zero to resend it using the supported format in Settings.").font(.caption).foregroundStyle(theme.muted)
            } else if loadedSource == content.source {
                if let vm = session.viewModel {
                    VStack(alignment:.leading,spacing:12) {
                        Label("Interactive reply",systemImage:"rectangle.and.hand.point.up.left").font(.caption.weight(.medium)).foregroundStyle(theme.muted)
                        A2UISurfaceView(viewModel:vm,catalog:GeneratedCatalog(allowsDraft:onDraft != nil),scrolls:false) { action in
                            Task { @MainActor in
                                guard loadedSource == content.source, onDraft != nil else { return }
                                onInteract()
                                do {
                                    let text = try GeneratedAction.draft(action,surfaceID:session.surfaceID,existing:"")
                                    review = ActionReview(text:text,name:action.name,context:action.context)
                                } catch { failed = true; session.reset() }
                            }
                        }
                        .a2uiCatalogItems(readOnlyControlOverrides)
                        .id(content.source)
                        if added { Label("Added to your draft",systemImage:"text.badge.checkmark").font(.caption).foregroundStyle(theme.muted) }
                    }.padding(12).background(theme.panel,in:RoundedRectangle(cornerRadius:16))
                    .simultaneousGesture(TapGesture().onEnded { onInteract() })
                } else { Text("This interactive reply was removed.").font(.caption).foregroundStyle(theme.muted) }
            } else { ProgressView("Preparing interactive reply…") }
            if content.complete {
                DisclosureGroup("View interface data") {
                    ScrollView(.horizontal) { Text(verbatim:String(content.source.prefix(65_536))).font(.system(.caption,design:.monospaced)).textSelection(.enabled) }
                }.font(.caption).foregroundStyle(theme.muted)
            }
        }
        .task(id:content.source + (content.complete ? "complete" : "pending")) {
            review = nil; failed = false; added = false; loadedSource = nil
            guard content.complete else { session.reset(); return }
            do {
                try session.load(content.source)
                if let vm = session.viewModel {
                    vm.a2uiStyle = A2UIStyle(primaryColor:theme.tint,textStyles:["caption":.init(color:theme.muted)])
                }
                loadedSource = content.source
            } catch { session.reset(); failed = true }
        }
        .onChange(of:theme.tint) { _,_ in
            session.viewModel?.a2uiStyle = A2UIStyle(primaryColor:theme.tint,textStyles:["caption":.init(color:theme.muted)])
        }
        .sheet(item:$review) { item in
            NavigationStack {
                ThemeForm {
                    Section {
                        Text(item.name.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline)
                        Text("Review the values before adding this response to your draft. Send it when you’re ready.").font(.subheadline).foregroundStyle(theme.muted)
                    }
                    Section {
                        ForEach(item.context.keys.sorted(),id:\.self) { key in
                            VStack(alignment:.leading,spacing:6) {
                                Text(key.replacingOccurrences(of:"_",with:" ").capitalized).font(.caption).foregroundStyle(theme.muted)
                                Text(item.context[key].map(Self.display) ?? "").textSelection(.enabled)
                            }
                        }
                    } header: { Text("Response").foregroundStyle(theme.muted) }
                }.navigationTitle("Review response").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge:.bottom) {
                    Button("Add to draft",systemImage:"text.badge.plus") {
                        guard loadedSource == content.source else { review = nil; return }
                        onDraft?(item.text); added = true; review = nil
                    }.frame(maxWidth:.infinity,minHeight:44).buttonStyle(.borderedProminent)
                        .foregroundStyle(theme.onTint).padding().background(.bar)
                        .accessibilityIdentifier("addGeneratedAction")
                }
                .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { review = nil }.accessibilityIdentifier("cancelGeneratedAction") } }
            }.tint(theme.tint)
        }
        .toolbar { ToolbarItemGroup(placement:.keyboard) {
            Spacer()
            Button("Hide keyboard",systemImage:"keyboard.chevron.compact.down") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil)
            }.accessibilityIdentifier("hideGeneratedKeyboard")
        } }
    }
    // Keep passive content usable in Agents while every form/action control is
    // read-only. The action callback above independently checks draft authority.
    private var readOnlyControlOverrides:[CatalogItem] {
        [BuiltinComponentType.button,.checkBox,.choicePicker,.slider].map { type in
            CatalogItem(name:type) { context in
                AnyView(context.buildDefaultView().disabled(onDraft == nil))
            }
        }
    }
    private static func display(_ value: AnyCodable) -> String {
        if let string = value.stringValue { return string }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        return (try? String(decoding:encoder.encode(value),as:UTF8.self)) ?? ""
    }
    private struct ActionReview: Identifiable {
        let id = UUID()
        let text: String
        let name: String
        let context: [String:AnyCodable]
    }
}

struct GenerativeSetupView: View {
    let model: SpikeModel
    @Environment(\.a0Theme) private var theme
    @State private var copied = false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                JevSettingsSection(model:model)
                Label("Interactive replies",systemImage:"rectangle.and.hand.point.up.left").font(.title2.weight(.semibold))
                Text("Agent Zero can present forecasts, image carousels, charts, metrics, tables, timelines, checklists, dashboards and forms. Rich replies advertise the supported format with each message you send. You can also copy the full instructions for a server profile.")
                Text("Form edits stay here until you review an action, add it to your draft and send. Unsubmitted form values aren’t saved when you leave the conversation.").font(.subheadline).foregroundStyle(theme.muted)
                Button(copied ? "Copied" : "Copy agent instructions",systemImage:copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = GenerativeGuide.instructions; copied = true
                }.buttonStyle(.bordered).accessibilityIdentifier("copyGenerativeInstructions")
                DisclosureGroup("Agent instructions") { Text(GenerativeGuide.instructions).font(.callout).textSelection(.enabled) }
                Text("Renderer: A2UI-Swift · A2UI v0.9 / v0.9.1").font(.caption).foregroundStyle(theme.muted)
            }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
        }.background { ThemeBackdrop() }.navigationTitle("Jev & rich replies").navigationBarTitleDisplayMode(.inline)
    }
}
