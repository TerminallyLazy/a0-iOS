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
            if requested && playback == nil {
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
        .sheet(item:$playback,onDismiss:{ requested = false }) { item in
            GeneratedPlayerScreen(playback:item,title:value.title,kind:kind)
        }
        .onChange(of:phase) { _,new in if new != .active { clear() } }
        .onDisappear { clear() }
    }
    private func clear() { playback?.stop(); playback = nil; requested = false }
}

@MainActor @Observable final class GeneratedPlayback:Identifiable {
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
        if player.rate > 0 { player.pause() }
        else {
            do {
                try activateAudio()
                if position >= duration - 0.1 { seek(0) }
                player.play()
            } catch { failed = true }
        }
    }
    private func activateAudio() throws {
        guard !audioSessionActive else { return }
        try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default)
        try AVAudioSession.sharedInstance().setActive(true)
        audioSessionActive = true
    }
    func rateChanged(_ rate:Float) {
        playing = rate > 0
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
        if audioSessionActive { try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation) }; audioSessionActive = false
        playing = false
    }
    deinit { if let fixtureURL { try? FileManager.default.removeItem(at:fixtureURL) } }
}

private struct GeneratedPlayerScreen:View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.a0Theme) private var theme
    let playback:GeneratedPlayback
    let title:String
    let kind:MediaKind
    @State private var seeking = false
    private func timeLabel(_ seconds:Double)->String {
        let total = Int(max(0,min(seconds,8640000)))
        return String(format:"%d:%02d",total / 60,total % 60)
    }
    var body:some View {
        NavigationStack {
            VStack(spacing:20) {
                if kind == .video { NativeMediaController(player:playback.player).accessibilityIdentifier("generatedVideoPlayer").frame(maxHeight:.infinity) }
                else { Image(systemName:"waveform.circle.fill").font(.system(size:80)).foregroundStyle(theme.tint).accessibilityHidden(true) }
                Text(playback.failed ? "Media unavailable" : playback.playing ? "Playing":"Ready to play").font(.headline)
                HStack {
                    Button(playback.playing ? "Pause media":"Play media",systemImage:playback.playing ? "pause.fill":"play.fill") { playback.toggle() }
                        .buttonStyle(.bordered).disabled(playback.failed)
                    Text(timeLabel(playback.position) + " / " + timeLabel(playback.duration))
                        .font(.caption).monospacedDigit()
                }
                Slider(value:Binding(get:{playback.position},set:{playback.position = $0; playback.seek($0)}),in:0...max(1,playback.duration),onEditingChanged:{ seeking = $0 })
                    .accessibilityLabel("Playback position").accessibilityValue(timeLabel(playback.position) + " of " + timeLabel(playback.duration)).disabled(playback.failed)
                if !playback.captionOptions.isEmpty {
                    Menu("Captions") {
                        Button("Off") { playback.selectCaption(nil) }
                        ForEach(Array(playback.captionOptions.enumerated()),id:\.offset) { _,option in
                            Button(option.displayName) { playback.selectCaption(option) }
                        }
                    }.frame(minHeight:44)
                }
            }.padding(20).frame(maxWidth:.infinity,maxHeight:.infinity).background(theme.canvas).foregroundStyle(theme.text)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .modifier(ThemeNavigationChrome())
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { playback.stop(); dismiss() }.accessibilityIdentifier("closeGeneratedMedia") } }
        }
        .onReceive(playback.player.publisher(for:\.rate)) { rate in playback.rateChanged(rate) }
        .onReceive(NotificationCenter.default.publisher(for:.AVPlayerItemFailedToPlayToEndTime)) { note in
            if let item = note.object as? AVPlayerItem, item === playback.player.currentItem { playback.failed = true; playback.player.pause() }
        }
        .onReceive(NotificationCenter.default.publisher(for:AVAudioSession.interruptionNotification)) { _ in playback.player.pause() }
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
