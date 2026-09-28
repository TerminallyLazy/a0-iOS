import SwiftUI
import A0Core

/// Local UI preferences contain no account data; synthetic tests use a separate suite.
@MainActor enum DisplayPreferences {
    static var store: UserDefaults {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of:"--persistence-test-id"), arguments.indices.contains(index + 1),
           let id = UUID(uuidString:arguments[index + 1]), let suite = UserDefaults(suiteName:"AgentZero.UI.Tests.\(id.uuidString)") {
            return suite
        }
        #endif
        return .standard
    }
    static func colorScheme(_ appearance: String) -> ColorScheme? {
        switch appearance { case "light": .light; case "dark": .dark; default: nil }
    }
}

struct SettingsView: View {
    let model: SpikeModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance",store:DisplayPreferences.store) private var appearance = "system"
    @AppStorage("collapseLongMessages",store:DisplayPreferences.store) private var collapseLongMessages = true
    @AppStorage("groupActivity",store:DisplayPreferences.store) private var groupActivity = true
    @AppStorage("richReplies",store:DisplayPreferences.store) private var richReplies = true
    @AppStorage("sendMode",store:DisplayPreferences.store) private var sendMode = SendMode.queue.rawValue
    @State private var confirmsChangeServer = false
    private static let thirdPartyNotices: String = {
        guard let url = Bundle.main.url(forResource:"ThirdPartyNotices",withExtension:"txt"),
              let value = try? String(contentsOf:url,encoding:.utf8) else { return "Acknowledgments are unavailable." }
        return value
    }()
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection:$appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    } label: { Label("Appearance",systemImage:"circle.lefthalf.filled") }
                    .accessibilityIdentifier("appearancePreference")
                    Toggle(isOn:$collapseLongMessages) {
                        Label("Collapse long messages",systemImage:"text.alignleft")
                    }.accessibilityIdentifier("collapseLongMessages")
                    Toggle(isOn:$groupActivity) {
                        Label("Group agent activity",systemImage:"square.stack.3d.up")
                    }.accessibilityIdentifier("groupActivity")
                } header: { Text("Reading").foregroundStyle(Color.a0Supporting) } footer: {
                    Text("Changes apply immediately. Tool details stay expandable. Text size follows your device settings.").foregroundStyle(Color.a0Supporting)
                }
                Section {
                    Picker(selection:$sendMode) {
                        Text("Queue").tag(SendMode.queue.rawValue)
                        Text("Steer").tag(SendMode.steer.rawValue)
                    } label: { Label("Follow-up messages",systemImage:"text.bubble") }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("sendModePreference")
                } header: { Text("While the agent works").foregroundStyle(Color.a0Supporting) } footer: {
                    Text("Queue holds new messages until the agent is ready. Steer sends immediately to guide the current work. Changing this setting does not move messages already queued.").foregroundStyle(Color.a0Supporting)
                }
                Section {
                    Toggle(isOn:$richReplies) { Label("Rich replies",systemImage:"rectangle.3.group") }
                        .accessibilityIdentifier("richReplies")
                    NavigationLink { GenerativeSetupView() } label: {
                        Label("Generative UI",systemImage:"rectangle.and.hand.point.up.left")
                    }.accessibilityIdentifier("generativeUISetup")
                }
                Section {
                    LabeledContent { Text(model.demo ? "Synthetic preview" : URL(string:model.origin)?.host ?? "Not selected").foregroundStyle(Color.a0Supporting).textSelection(.enabled) }
                        label: { Label("Server",systemImage:"server.rack") }
                    LabeledContent { Text(model.status).foregroundStyle(Color.a0Supporting) } label: { Label("Connection",systemImage:"network") }
                    if model.connected || model.demo {
                        Button { confirmsChangeServer = true } label: {
                            Label("Change server",systemImage:"arrow.triangle.2.circlepath").frame(minHeight:44)
                        }.accessibilityIdentifier("changeServer")
                    } else {
                        Text("Choose a saved server or scan its QR code on the Connect screen.").font(.footnote).foregroundStyle(Color.a0Supporting)
                    }
                } header: { Text("Connection").foregroundStyle(Color.a0Supporting) } footer: {
                    Text("Changing servers disconnects this session. Your drafts and pending delivery records stay on this device.").foregroundStyle(Color.a0Supporting)
                }
                Section {
                    Label("Drafts stay on this device",systemImage:"iphone")
                    Label("Saved passwords use Keychain",systemImage:"key.horizontal")
                    Label("Stay signed in on this device",systemImage:"lock.shield")
                    Text("Your session is restored after reopening. Disconnect removes the saved session. Agent Zero keeps working on your server while this app is closed.").font(.footnote).foregroundStyle(Color.a0Supporting)
                    Text("Password saving is optional. Manage saved servers and passwords from the Connect screen.")
                        .font(.footnote).foregroundStyle(Color.a0Supporting)
                } header: { Text("Privacy & storage").foregroundStyle(Color.a0Supporting) }
                Section {
                    HStack(spacing:12) {
                        Image("AgentZeroMark").resizable().scaledToFit().frame(width:24,height:32).accessibilityHidden(true)
                        VStack(alignment:.leading,spacing:4) {
                            Text("Agent Zero").font(.headline)
                            Text("Native companion · Beta").font(.caption).foregroundStyle(Color.a0Supporting)
                        }
                    }
                    LabeledContent { Text(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "—").foregroundStyle(Color.a0Supporting) } label: { Text("Version") }
                    LabeledContent("Build", value: Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "—")
                    NavigationLink {
                        ScrollView {
                            Text(Self.thirdPartyNotices).font(.footnote).textSelection(.enabled)
                                .frame(maxWidth:.infinity,alignment:.leading).padding()
                        }.navigationTitle("Acknowledgments").navigationBarTitleDisplayMode(.inline)
                    } label: { Label("Acknowledgments",systemImage:"doc.text") }
                } header: { Text("About").foregroundStyle(Color.a0Supporting) }
            }
            .scrollContentBackground(.hidden).background(Color("A0Canvas"))
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) {
                Button("Done",systemImage:"checkmark") { dismiss() }.accessibilityIdentifier("settingsDone")
            } }
            .alert("Change server?",isPresented:$confirmsChangeServer) {
                Button("Disconnect and choose server") { model.disconnect(); dismiss() }
                Button("Cancel",role:.cancel) { }
            } message: { Text("Your current draft is kept. Choose and sign in to a server on the Connect screen.") }
        }.tint(Color("A0Tint")).preferredColorScheme(DisplayPreferences.colorScheme(appearance))
    }
}


extension Color {
    /// Opaque supporting ink on light panels; retain UIKit's adaptive secondary
    /// label treatment in dark appearance rather than changing that palette.
    static var a0Supporting: Color {
        Color(uiColor:UIColor { traits in
            traits.userInterfaceStyle == .dark ? .secondaryLabel : UIColor(red:0.34,green:0.34,blue:0.36,alpha:1)
        })
    }
}
