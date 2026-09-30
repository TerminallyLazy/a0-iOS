import SwiftUI
import A0Core
import AVFoundation

/// Owns only composer interaction state; draft and storage state belong to the session.
struct ChatComposer: View {
    @Environment(\.a0Theme) private var theme
    @Bindable var chat: ChatSession
    var connectionReady = true
    var contextModel:SpikeModel?
    var onTools: () -> Void = {}
    var conversationID = "draft"
    var latestReply: String?
    let send: @MainActor () async -> Void
    @State private var confirmsClear = false
    @FocusState private var composerFocused: Bool
    @AppStorage("continuousVoice", store: DisplayPreferences.store) private var continuousVoice = false
    @State private var voice = VoiceController()
    @State private var voiceInsertion: VoiceDraftInsertion?
    @State private var voiceScope: VoiceScope?
    @State private var voiceStartTask: Task<Void, Never>?
    @State private var hasUsedVoice = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            storageStatus
            AttachmentTray(chat:chat)
            if let notice = contextModel?.stopNotice {
                Text(notice).font(.caption).foregroundStyle(theme.muted)
                    .accessibilityIdentifier("stopNotice")
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 0) {
                    TextField("Message Agent Zero", text: $chat.draft, prompt: Text("Message Agent Zero").foregroundStyle(theme.muted), axis: .vertical)
                        .lineLimit(1...6)
                        .focused($composerFocused)
                        .textFieldStyle(.plain)
                        .padding(.leading, 14).padding(.top, 14).padding(.bottom, 4)
                        .padding(.trailing, contextModel == nil ? 14 : 0)
                        .accessibilityLabel("Message")
                        .accessibilityIdentifier("messageDraft")
                    if let contextModel {
                        ConnectionStatusButton(model:contextModel)
                            .padding(.top, 2).padding(.trailing, 6)
                    }
                }
                if hasUsedVoice || voice.speaking {
                    Label(voice.status, systemImage: voice.listening ? "mic.fill" : voice.speaking ? "speaker.wave.2.fill" : "waveform")
                        .font(.caption).foregroundStyle(theme.muted)
                        .lineLimit(3).padding(.horizontal, 14)
                        .accessibilityIdentifier("voiceStatus")
                }
                HStack(spacing: 8) {
                    Button { composerFocused = false; onTools() } label: {
                        Label("Chat tools", systemImage: "plus")
                            .labelStyle(.iconOnly).font(.system(size: 20, weight: .medium))
                            .frame(width: 44, height: 44)
                    }.accessibilityIdentifier("chatTools")
                    Spacer(minLength: 0)
                    VoiceControls(controller: voice, draft: $chat.draft, continuous: $continuousVoice, reply: latestReply, toggleListening: toggleVoice)
                        .id(currentVoiceScope)
                    submissionControl
                }.padding(.horizontal, 6).padding(.bottom, 4)
            }
            .background(composerFocused ? theme.inputFocus : theme.input, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(composerFocused ? theme.tint : theme.border, lineWidth: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("messageInputCard")

        }
        .padding(.horizontal,16).padding(.vertical,10).background(theme.isActive ? AnyShapeStyle(theme.panel) : AnyShapeStyle(.bar))
        .confirmationDialog("Clear this draft?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Clear saved draft", role: .destructive) { stopVoice(); chat.draft = ""; chat.attachments.map(\.id).forEach { chat.removeAttachment($0) } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes the draft text and staged files from this device. It does not cancel a message already submitted to the server; its delivery record is kept to prevent duplicate sends.")
        }
        .onChange(of: voice.buffer.text) { _, _ in applyVoiceTranscript() }
        .onChange(of: chat.draft) { _, text in
            if let insertion = voiceInsertion, text != insertion.lastApplied { stopVoice() }
        }
        .onChange(of: currentVoiceScope) { _, _ in stopVoice(); hasUsedVoice = false; voice = VoiceController(); contextModel?.stopNotice = nil }
        .onChange(of: scenePhase) { _, phase in if phase == .background { stopVoice() } }
        .onDisappear { stopVoice() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            if voice.listening || voice.requestingPermission || voice.speaking { stopVoice(); voice.interrupted() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable {
                stopVoice(); voice.interrupted()
            }
        }
    }

    // A draft always keeps the ordinary Send path available, even while the agent works.
    // Stop shares that control through its menu, so stopping never requires clearing a draft.
    private var hasDraftContent: Bool {
        !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !chat.attachments.isEmpty
    }
    private var hasWorkToStop: Bool {
        guard let model = contextModel, let context = chat.selectedContext else { return false }
        let queued = model.state.contexts.first { $0["id"]?.string == context }?["message_queue"]
        if case .array(let items) = queued, !items.isEmpty { return true }
        return model.stoppingAgent || model.agentIsRunning || (model.state.context == context && model.state.paused)
    }
    private var canStop: Bool {
        guard let model = contextModel else { return false }
        return connectionReady && !model.demo && !model.stoppingAgent
            && !chat.deliveries.contains { $0.status == .sending || $0.status == .creating }
    }
    private var isWorking: Bool {
        contextModel?.agentIsRunning == true && contextModel?.state.paused != true
    }
    private func stopAgent() {
        stopVoice(); composerFocused = false
        Task { await contextModel?.stopAgent() }
    }
    @ViewBuilder private var submissionControl: some View {
        if contextModel?.stoppingAgent == true || (hasWorkToStop && !hasDraftContent) {
            Button(action: stopAgent) {
                Group {
                    if contextModel?.stoppingAgent == true { ProgressView().tint(theme.onTint) }
                    else { Image(systemName: "stop.fill").font(.system(size: 15, weight: .semibold)) }
                }
                .frame(width: 36, height: 36)
                .foregroundStyle(canStop ? theme.onTint : theme.muted)
                .background(canStop ? theme.tint : theme.border, in: Circle())
                .overlay { if isWorking { WorkingSendRing() } }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain).disabled(!canStop)
            .accessibilityLabel("Stop agent and clear queue")
            .accessibilityHint("Stops this chat and its subagents, clears queued follow-ups, and keeps your draft.")
            .accessibilityIdentifier("stopAgent")
        } else {
            HStack(spacing: 0) {
                Button { stopVoice(); composerFocused = false; Task { await send() } } label: {
                    Image(systemName: "arrow.up").font(.system(size: 18, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(canSend ? theme.onTint : theme.muted)
                        .background(canSend ? theme.tint : Color.clear, in: Circle())
                        .overlay { if isWorking { WorkingSendRing() } }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
                .accessibilityHint(hasWorkToStop ? "Uses your follow-up preference. More actions includes Stop." : "Send your message.")
                .accessibilityValue(contextModel?.agentIsRunning == true ? "Agent working" : "Ready")
                .accessibilityIdentifier("sendMessage")
                if hasWorkToStop {
                    Rectangle().fill(theme.border).frame(width: 1, height: 22).accessibilityHidden(true)
                    Menu {
                        Button(role: .destructive, action: stopAgent) {
                            Label("Stop agent and clear queue", systemImage: "stop.fill")
                        }.disabled(!canStop).accessibilityIdentifier("stopAgent")
                    } label: {
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.text).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Send and stop actions")
                    .accessibilityHint("Stop the agent without sending or clearing your draft.")
                    .accessibilityIdentifier("composerSendActions")
                }
            }
            .buttonStyle(.plain)
            .background(hasWorkToStop ? theme.panel : Color.clear, in: Capsule())
            .overlay { if hasWorkToStop { Capsule().strokeBorder(theme.border, lineWidth: 1).allowsHitTesting(false) } }
        }
    }

    private func toggleVoice() {
        if voice.listening || voice.requestingPermission || voice.speaking { stopVoice(); return }
        composerFocused = false
        voice.clearTranscript()
        voiceInsertion = VoiceDraftInsertion(draft: chat.draft)
        voiceScope = currentVoiceScope; hasUsedVoice = true
        voiceStartTask?.cancel()
        let scope = currentVoiceScope
        let controller = voice
        voiceStartTask = Task {
            guard !Task.isCancelled, voiceScope == scope, currentVoiceScope == scope else { return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--synthetic-voice-input") {
                await controller.previewTranscription(holdsFirstSnapshot: ProcessInfo.processInfo.arguments.contains("--synthetic-voice-edit"))
                return
            }
            #endif
            await controller.start(continuous: continuousVoice)
        }
    }
    private func applyVoiceTranscript() {
        guard voiceScope == currentVoiceScope, var insertion = voiceInsertion else { return }
        guard let updated = insertion.apply(voice.buffer.text, to: chat.draft) else {
            voiceInsertion = nil; voiceStartTask?.cancel(); voice.stop(); return
        }
        voiceInsertion = insertion
        if updated != chat.draft { chat.draft = updated }
    }
    private func stopVoice() {
        applyVoiceTranscript()
        voiceStartTask?.cancel(); voiceStartTask = nil
        voice.stop(); voiceInsertion = nil; voiceScope = nil
    }

    private struct VoiceScope: Hashable {
        let generation: UUID?
        let session: ObjectIdentifier
        let context: String
    }
    private var currentVoiceScope: VoiceScope {
        VoiceScope(generation: contextModel?.connectionGeneration, session: ObjectIdentifier(chat), context: conversationID)
    }

    private var canSend: Bool { connectionReady && chat.canSend && chat.storageState != .failed }

    private var storageStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let contextModel { ModelPresetPicker(model:contextModel) }
                Spacer(minLength: 8)
                if let contextModel { ContextUsageButton(model:contextModel) }
                if composerFocused {
                    Button { composerFocused = false } label: {
                        Label("Hide keyboard",systemImage:"keyboard.chevron.compact.down")
                            .labelStyle(.iconOnly).frame(width:44,height:44)
                    }.accessibilityIdentifier("dismissKeyboard")
                }
                Menu {
                    Button("Clear draft", role: .destructive) { confirmsClear = true }
                        .disabled(chat.draft.isEmpty && chat.attachments.isEmpty)
                    Text("Drafts stay on this device until cleared. Disconnecting keeps drafts. Passwords are saved only if you opt in on the connection screen.")
                } label: {
                    Label("Draft options", systemImage: "ellipsis.circle").labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }.accessibilityIdentifier("draftOptions").accessibilityValue(statusText)
            }
            if chat.storageState == .failed {
                storageLabel
                Text("Your text is still here, but could be lost if the app closes. Unlock the device or free up space, then retry.")
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
                Button { Task { await chat.retrySave() } } label: { Text("Retry saving").font(.subheadline).frame(minHeight:44) }
            }
        }
    }
    private var storageLabel:some View {
        Label(statusText,systemImage:statusSymbol).font(.caption)
            .foregroundStyle(chat.storageState == .failed ? Color.primary : theme.muted)
            .accessibilityIdentifier("draftStorageStatus")
    }
    private var statusText: String {
        switch chat.storageState {
        case .memoryOnly: "Preview • not saved"
        case .saving: "Saving on this device…"
        case .saved: "Saved on this device"
        case .failed: "Draft not saved"
        }
    }
    private var statusSymbol: String {
        switch chat.storageState {
        case .memoryOnly: "eye"
        case .saving: "arrow.triangle.2.circlepath"
        case .saved: "checkmark.shield"
        case .failed: "exclamationmark.triangle"
        }
    }
}


private struct WorkingSendRing: View {
    @Environment(\.a0Theme) private var theme
    @State private var rotating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Circle().trim(from:0.08,to:0.8)
            .stroke(theme.tint,style:StrokeStyle(lineWidth:1.5,lineCap:.round))
            .frame(width:42,height:42)
            .rotationEffect(.degrees(rotating && !reduceMotion ? 360 : 0))
            .onAppear { rotating = true }
            .animation(reduceMotion ? nil : .linear(duration:1.1).repeatForever(autoreverses:false),value:rotating)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .accessibilityIdentifier("agentWorkingSendRing")
    }
}
