import SwiftUI
import AVKit
import A0GenerativeUI

struct GeneratedMedia:View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.scenePhase) private var phase
    let value:MediaContent
    let kind:MediaKind
    @State private var requested = false
    @State private var failed = false
    @State private var playback:GeneratedPlayback?
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Label(value.title,systemImage:kind == .audio ? "waveform":"play.rectangle").font(.headline)
            Text(URL(string:value.url)?.host ?? "Media").font(.caption).foregroundStyle(theme.muted)
            if let playback {
                InlineGeneratedPlayer(playback:playback,kind:kind,onUnload:clear)
                    .accessibilityElement(children:.contain)
                    .accessibilityIdentifier("inlineGeneratedMedia")
            } else if requested {
                HStack { ProgressView("Loading \(kind.rawValue)…"); Button("Cancel") { requested = false } }
            } else {
                Button("Load " + kind.rawValue,systemImage:"play.circle") { failed = false; requested = true }.frame(minHeight:44)
            }
            if failed { Text("This media couldn’t be played. Check that the link is a supported direct file, then try again.").font(.caption).foregroundStyle(theme.muted) }
            if let transcript = value.transcript, !transcript.isEmpty {
                DisclosureGroup("Transcript / description") { Text(transcript).textSelection(.enabled) }
            }
            if let url = value.sourceURL { sourceLink(url) }
        }.padding(.vertical,12)
        .task(id:requested) {
            guard requested, phase == .active else { return }
            do {
                let ready:GeneratedPlayback
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--synthetic-charts-media") {
                    ready = try await GeneratedPlayback.fixture(kind:kind)
                } else {
                    ready = GeneratedPlayback(file:try await MediaDownloads.shared.load(value.url,kind:kind))
                }
                #else
                ready = GeneratedPlayback(file:try await MediaDownloads.shared.load(value.url,kind:kind))
                #endif
                try await ready.prepare(kind:kind)
                try Task.checkCancellation()
                guard requested, phase == .active else { ready.stop(); return }
                playback = ready
            } catch {
                if !Task.isCancelled { requested = false; failed = true }
            }
        }
        .onChange(of:phase) { _,new in if new != .active { clear() } }
        .onDisappear { clear() }
    }
    private func clear() { playback?.stop(); playback = nil; requested = false }
}

@MainActor @Observable final class GeneratedPlayback:Identifiable,NativeAudioParticipant {
    let id = UUID()
    let player:AVPlayer
    private let file:MediaFile?
    private let fixtureURL:URL?
    var playing = false
    var failed = false
    private var audioSessionActive = false
    var duration:Double = 0
    var position:Double = 0
    var captionOptions:[AVMediaSelectionOption] = []
    var selectedCaption:AVMediaSelectionOption?
    private var captionGroup:AVMediaSelectionGroup?
    init(file:MediaFile) {
        self.file = file; fixtureURL = nil
        player = AVPlayer(playerItem:AVPlayerItem(asset:AVURLAsset(url:file.url,options:[
            AVURLAssetReferenceRestrictionsKey:AVAssetReferenceRestrictions.forbidAll.rawValue,
            AVURLAssetOverrideMIMETypeKey:file.mimeType
        ])))
        player.allowsExternalPlayback = false
    }
    #if DEBUG
    init(fixtureURL:URL) {
        file = nil; self.fixtureURL = fixtureURL
        player = AVPlayer(url:fixtureURL); player.allowsExternalPlayback = false
    }
    #endif
    func prepare(kind:MediaKind) async throws {
        guard let asset = player.currentItem?.asset, try await asset.load(.isPlayable),
              !(try await asset.loadTracks(withMediaType:kind == .audio ? .audio:.video)).isEmpty else { throw URLError(.cannotDecodeContentData) }
        let seconds = try await asset.load(.duration).seconds
        guard seconds.isFinite, seconds > 0 else { throw URLError(.cannotDecodeContentData) }
        duration = seconds
        if kind == .video, let group = try await asset.loadMediaSelectionGroup(for:.legible) {
            captionGroup = group; captionOptions = Array(group.options.prefix(32))
        }
    }
    func toggle() {
        if player.rate > 0 { player.pause(); playing = false }
        else {
            do {
                try activateAudio()
                if position >= duration - 0.1 { seek(0) }
                player.play()
                playing = true
            } catch { failed = true }
        }
    }
    private func activateAudio() throws {
        guard !audioSessionActive || !NativeAudioOwnership.owns(self) else { return }
        NativeAudioOwnership.claim(self)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioSessionActive = true
        } catch { deactivateAudio(); throw error }
    }
    func rateChanged(_:Float) {
        // KVO can deliver an older positive rate after another card has paused us.
        playing = player.rate > 0
        if playing {
            do { try activateAudio() } catch { failed = true; player.pause() }
        }
    }
    func selectCaption(_ option:AVMediaSelectionOption?) {
        guard let captionGroup else { return }
        player.currentItem?.select(option,in:captionGroup); selectedCaption = option
    }
    func seek(_ seconds:Double) { player.seek(to:CMTime(seconds:seconds,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero) }
    func stop() {
        player.pause(); player.replaceCurrentItem(with:nil)
        deactivateAudio()
        playing = false
    }
    func relinquishAudio() {
        player.pause(); playing = false
        deactivateAudio()
    }
    private func deactivateAudio() {
        let owns = NativeAudioOwnership.release(self)
        if owns && audioSessionActive { try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation) }
        audioSessionActive = false
    }
    func interrupted() {
        player.pause(); playing = false
        NativeAudioOwnership.release(self); audioSessionActive = false
    }
    deinit { if let fixtureURL { try? FileManager.default.removeItem(at:fixtureURL) } }
}

private struct InlineGeneratedPlayer:View {
    @Environment(\.a0Theme) private var theme
    let playback:GeneratedPlayback
    let kind:MediaKind
    let onUnload:()->Void
    @State private var seeking = false
    private func timeLabel(_ seconds:Double)->String {
        let total = Int(max(0,min(seconds,8640000)))
        return String(format:"%d:%02d",total / 60,total % 60)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
                if kind == .video {
                    Color.black.aspectRatio(16.0/9.0,contentMode:.fit)
                        .overlay { NativeMediaController(player:playback.player).accessibilityIdentifier("generatedVideoPlayer") }
                        .clipShape(RoundedRectangle(cornerRadius:12))
                }
                Text(playback.failed ? "Media unavailable" : playback.playing ? "Playing":"Ready to play").font(.subheadline)
                ViewThatFits(in:.horizontal) {
                    HStack {
                        playbackButton
                        Spacer(minLength:12)
                        elapsedTime
                    }
                    VStack(alignment:.leading,spacing:8) { playbackButton; elapsedTime }
                }
                Slider(value:Binding(get:{playback.position},set:{playback.position = $0; playback.seek($0)}),in:0...max(1,playback.duration),onEditingChanged:{ seeking = $0 })
                    .accessibilityLabel("Playback position").accessibilityValue(timeLabel(playback.position) + " of " + timeLabel(playback.duration)).disabled(playback.failed)
                HStack {
                    if !playback.captionOptions.isEmpty {
                        Menu("Captions") {
                            Button("Off") { playback.selectCaption(nil) }
                            ForEach(Array(playback.captionOptions.enumerated()),id:\.offset) { _,option in
                                Button(option.displayName) { playback.selectCaption(option) }
                            }
                        }.frame(minHeight:44)
                    }
                    Spacer(minLength:0)
                    Button("Unload " + kind.rawValue,systemImage:"xmark.circle",action:onUnload)
                        .frame(minHeight:44)
                        .accessibilityIdentifier(kind == .audio ? "unloadGeneratedAudio":"unloadGeneratedVideo")
                }
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
            .background(theme.panel,in:RoundedRectangle(cornerRadius:14)).foregroundStyle(theme.text)
        .onReceive(playback.player.publisher(for:\.rate)) { rate in playback.rateChanged(rate) }
        .onReceive(NotificationCenter.default.publisher(for:.AVPlayerItemFailedToPlayToEndTime)) { note in
            if let item = note.object as? AVPlayerItem, item === playback.player.currentItem { playback.failed = true; playback.player.pause() }
        }
        .onReceive(NotificationCenter.default.publisher(for:AVAudioSession.interruptionNotification)) { _ in playback.interrupted() }
        .task {
            while !Task.isCancelled {
                let seconds = playback.player.currentTime().seconds
                if seconds.isFinite && !seeking { playback.position = max(0,seconds) }
                if playback.player.currentItem?.status == .failed { playback.failed = true }
                do { try await Task.sleep(for:.milliseconds(250)) } catch { return }
            }
        }
        .onDisappear { playback.stop() }
    }
    private var playbackButton:some View {
                    Button(playback.playing ? "Pause media":"Play media",systemImage:playback.playing ? "pause.fill":"play.fill") { playback.toggle() }
                        .buttonStyle(.bordered).frame(minHeight:44).disabled(playback.failed)
                        .accessibilityIdentifier(kind == .audio ? "playGeneratedAudio":"playGeneratedVideo")
    }
    private var elapsedTime:some View {
        Text(timeLabel(playback.position) + " / " + timeLabel(playback.duration)).font(.caption).monospacedDigit()
    }
}
private struct NativeMediaController:UIViewControllerRepresentable {
    let player:AVPlayer
    func makeUIViewController(context:Context)->AVPlayerViewController {
        let view = AVPlayerViewController(); view.player = player
        // Use the themed, consistently accessible native transport controls below.
        view.showsPlaybackControls = false; view.allowsPictureInPicturePlayback = false
        return view
    }
    func updateUIViewController(_ controller:AVPlayerViewController,context:Context) { if controller.player !== player { controller.player = player } }
    static func dismantleUIViewController(_ controller:AVPlayerViewController,coordinator:()) { controller.player?.pause(); controller.player = nil }
}
