import SwiftUI
@preconcurrency import Speech
@preconcurrency import AVFoundation
import A0Core

/// Foreground-only microphone ownership; no audio files, network client or Send callback.
@MainActor @Observable final class VoiceController: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var buffer = VoiceDraftBuffer()
    private(set) var listening = false
    private(set) var requestingPermission = false
    private(set) var speaking = false
    private(set) var status = "Ready to listen on this device"
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var generation = UUID()
    private var segment = UUID()
    private var continuous = false
    private var startedAt = Date()
    private var rollover: Task<Void, Never>?
    private var sessionDeadline: Task<Void, Never>?
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var ownedAudioActive = false

    override init() { super.init(); synthesizer.delegate = self }

    func start(continuous: Bool) async {
        stop()
        let token = UUID(); generation = token
        requestingPermission = true
        status = "Checking microphone and speech access…"
        let authorized = await VoicePermissionBridge.request { @Sendable completion in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                completion(status == .authorized)
            }
        }
        guard token == generation else { return }
        guard authorized else { requestingPermission = false; status = "Allow Speech Recognition in iOS Settings to dictate."; return }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard token == generation else { return }
        requestingPermission = false
        guard microphone else { status = "Allow Microphone access in iOS Settings to dictate."; return }
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.supportsOnDeviceRecognition else {
            status = "On-device speech recognition is unavailable for this device or language. You can still type."; return
        }
        guard recognizer.isAvailable else { status = "Speech recognition is temporarily unavailable. Try again later."; return }
        self.recognizer = recognizer
        self.continuous = continuous
        startedAt = Date()
        sessionDeadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(300))
            guard !Task.isCancelled, let self, self.generation == token else { return }
            self.stop()
            self.status = "Five-minute listening limit reached. Your transcript is ready."
        }
        beginSegment()
    }

    #if DEBUG
    /// Synthetic recognition snapshots for UI verification; no permission or audio API.
    func previewTranscription(holdsFirstSnapshot: Bool = false) async {
        stop()
        let token = UUID(); generation = token
        buffer = VoiceDraftBuffer(); listening = true
        status = "Listening · synthetic preview"
        buffer.update("weather")
        try? await Task.sleep(for: .seconds(holdsFirstSnapshot ? 8 : 2))
        guard !Task.isCancelled, generation == token else { return }
        buffer.update("weather tomorrow")
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, generation == token else { return }
        stop()
    }
    #endif

    private func beginSegment() {
        guard let recognizer else { return }
        do {
            if !ownedAudioActive {
                let audio = AVAudioSession.sharedInstance()
                try audio.setCategory(.record, mode: .measurement, options: [.duckOthers])
                try audio.setActive(true)
                ownedAudioActive = true
            }
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            let format = engine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                stop(); status = "No microphone is available. Check your audio input."; return
            }
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in request.append(buffer) }
            self.engine = engine; self.request = request
            let token = generation, segmentToken = UUID(); segment = segmentToken
            recognition = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                // Copy immutable values before crossing the callback's executor.
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                let failed = error != nil
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token, self.segment == segmentToken else { return }
                    if let text { self.buffer.update(text) }
                    if self.buffer.text.count >= VoiceDraftBuffer.limit {
                        self.stop(); self.status = "Dictation limit reached. Your text is ready in Message."; return
                    }
                    if failed { self.stop(); self.status = "Listening stopped. Your draft is preserved; tap the microphone to retry." }
                    else if final { self.finishSegment() }
                }
            }
            engine.prepare(); try engine.start()
            listening = true
            status = continuous ? "Listening continuously · on device" : "Listening · on device"
            rollover = Task { [weak self] in
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled, let self, self.segment == segmentToken else { return }
                self.finishSegment()
            }
        } catch { stop(); status = "Could not start the microphone. Check your audio input and try again." }
    }

    private func finishSegment() {
        endSegment()
        if continuous && Date().timeIntervalSince(startedAt) < 300 {
            beginSegment()
        } else {
            continuous = false
            sessionDeadline?.cancel(); sessionDeadline = nil
            status = "Dictation ready in Message"
            deactivateAudio()
        }
    }
    private func endSegment() {
        segment = UUID()
        rollover?.cancel(); rollover = nil
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
        buffer.finishSegment(); listening = false
    }
    func stop() {
        sessionDeadline?.cancel(); sessionDeadline = nil
        generation = UUID(); requestingPermission = false; continuous = false
        endSegment()
        if speaking { synthesizer.stopSpeaking(at: .immediate) }
        currentUtterance = nil; speaking = false
        deactivateAudio()
        status = buffer.text.isEmpty ? "Ready to listen on this device" : "Dictation ready in Message"
    }
    func clearTranscript() { stop(); buffer = VoiceDraftBuffer(); status = "Ready to listen on this device" }
    func interrupted() { stop(); status = "Audio paused. Tap the microphone when you’re ready." }
    func read(_ text: String) {
        stop()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audio.setActive(true)
            ownedAudioActive = true
            let utterance = AVSpeechUtterance(string: String(text.prefix(12_000)))
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            currentUtterance = utterance; speaking = true; status = "Reading reply aloud"
            synthesizer.speak(utterance)
        } catch { status = "Speech playback is unavailable. You can still read the reply." }
    }
    private func deactivateAudio() {
        // Passive navigation/permission cancellation must not change shared audio state.
        guard ownedAudioActive else { return }
        ownedAudioActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance.map(ObjectIdentifier.init) == utteranceID else { return }
            self.currentUtterance = nil; self.speaking = false; self.status = "Finished reading"; self.deactivateAudio()
        }
    }
}
