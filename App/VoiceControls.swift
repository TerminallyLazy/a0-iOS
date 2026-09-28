import SwiftUI
import A0Core

/// Inline recording action plus persistent preferences; transcript lives in Message.
struct VoiceControls: View {
    let controller: VoiceController
    @Binding var draft: String
    @Binding var continuous: Bool
    var reply: String?
    let toggleListening: () -> Void
    @State private var review: VoiceCleanupReview?
    @State private var cleanupTask: Task<Void, Never>?
    @State private var cleaning = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var cleanupError: String?

    private var active: Bool { controller.listening || controller.requestingPermission || controller.speaking }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: toggleListening) {
                Label(active ? "Stop voice" : "Dictate message", systemImage: active ? "stop.fill" : "mic")
                    .labelStyle(.iconOnly).font(.system(size: 20, weight: .medium))
                    .foregroundStyle(active ? Color("A0Canvas") : Color.primary)
                    .frame(width: 36, height: 36)
                    .background(active ? Color("A0Tint") : Color.clear, in: Circle())
                    .frame(width: 44, height: 44)
            }.accessibilityIdentifier("voiceControls")
                .accessibilityValue(active ? "Active" : "Stopped")
            Menu {
                Button(continuous ? "Continuous listening: On" : "Continuous listening: Off", systemImage: continuous ? "checkmark.circle.fill" : "circle") {
                    continuous.toggle()
                }.accessibilityIdentifier("continuousVoice").disabled(active)
                if let reply, !reply.isEmpty {
                    Button("Read reply", systemImage: "speaker.wave.2") { controller.read(reply) }
                        .disabled(active).accessibilityIdentifier("readReply")
                }
                if let reason = VoiceTranscriptAssistant.unavailableReason {
                    Text(reason)
                } else {
                    Button(cleaning ? "Preparing suggestion…" : "Polish draft on device", systemImage: "text.badge.checkmark") { clean() }
                        .disabled(active || cleaning || draft.isEmpty || draft.count > 1_500)
                }
                Text("Dictation stays on device and never sends automatically. Continuous listening stops after five minutes or when you leave the app.")
            } label: {
                Label("Voice options", systemImage: "chevron.down")
                    .labelStyle(.iconOnly).font(.system(size: 12, weight: .semibold)).frame(width: 44, height: 44)
            }.accessibilityIdentifier("voiceOptions")
                .accessibilityValue(continuous ? "Continuous listening on" : "Continuous listening off")
        }
        .sheet(item: $review) { suggestion in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Original").font(.headline)
                        Text(suggestion.original).textSelection(.enabled)
                        Divider()
                        Text("Suggested edit").font(.headline)
                        Text(suggestion.proposed).textSelection(.enabled)
                        Text("Review the wording before replacing your draft. Nothing is sent.")
                            .font(.caption).foregroundStyle(Color.a0Supporting)
                    }.padding(20)
                }
                .navigationTitle("Review suggestion").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep original") { review = nil } } }
                .safeAreaInset(edge: .bottom) {
                    Button("Use suggestion") {
                        guard draft == suggestion.original else { return }
                        draft = suggestion.proposed; review = nil
                    }.buttonStyle(.borderedProminent).foregroundStyle(Color("A0Canvas"))
                        .disabled(draft != suggestion.original).padding().frame(maxWidth: .infinity).background(.bar)
                }
            }
        }
        .alert("On-device cleanup", isPresented: Binding(get: { cleanupError != nil }, set: { if !$0 { cleanupError = nil } })) {
            Button("OK") { cleanupError = nil }
        } message: { Text(cleanupError ?? "") }
        .onDisappear { cleanupTask?.cancel(); cleanupTask = nil; cleaning = false }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { cleanupTask?.cancel(); cleanupTask = nil; cleaning = false; review = nil }
        }
        .onChange(of: draft) { _, value in
            if let review, value != review.original { self.review = nil }
        }
    }
    private func clean() {
        let original = draft
        cleaning = true
        cleanupTask = Task {
            do {
                let proposed = try await VoiceTranscriptAssistant.clean(original)
                guard !Task.isCancelled, draft == original else { cleaning = false; return }
                review = VoiceCleanupReview(original: original, proposed: proposed)
            } catch {
                if !Task.isCancelled { cleanupError = "Cleanup isn’t available right now. Your original draft is preserved." }
            }
            cleaning = false
        }
    }
}

private struct VoiceCleanupReview: Identifiable {
    let id = UUID()
    let original: String
    let proposed: String
}
