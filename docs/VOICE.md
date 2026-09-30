# On-device voice

## Inline dictation

The composer microphone starts Dictate message directly; there is no separate Voice sheet or Add transcript step. Activation explicitly requests system permissions and uses recognition in the device's current language. The Speech recognizer must support on-device recognition, and each request requires it. Unsupported or denied access leaves a visible explanation and typing available. There is no cloud recognition fallback, audio file, upload or automatic Send.

Live speech snapshots appear in the existing Message field. VoiceDraftInsertion preserves the text present when recording starts and replaces only its own in-progress transcript; cumulative partial results do not duplicate earlier words. Manual draft changes end the insertion instead of being overwritten. Dictated text now follows ordinary protected draft persistence. Raw audio and the recognizer's transient buffer are not archived.

The microphone changes to Stop voice during permission requests, recording or reply playback. Status appears inside the composer after voice use. Send stops voice before submitting; Clear draft stops before clearing. Backgrounding, conversation/account/session changes, disappearance, interruption and loss of the audio route stop capture. The insertion scope includes connection generation, ChatSession identity and context, so delayed snapshots cannot enter another draft.

## Options and review

Voice options contains Continuous listening, Read reply and supported on-device cleanup. Continuous listening is a local `continuousVoice` preference in DisplayPreferences.store, default off, with isolated test storage. It survives relaunch but never starts capture automatically. Changing it is disabled while voice is active. Continuous mode rolls recognition segments at 45 seconds, stops after five minutes in the foreground and retains the existing 12,000-character transcript bound.

Read reply uses Apple's system speech synthesizer and the latest assistant prose, excluding code. Reading, recording and inline media playback share `NativeAudioOwnership`. Starting voice pauses a playing clip; starting a clip synchronously stops dictation/read-aloud and invalidates pending permission callbacks while retaining the draft. Only the current owner can deactivate the shared audio session. No prior activity resumes automatically. It starts only from the menu, and stops on background or leaving/changing the conversation.

Polish draft on device uses FoundationModels only on eligible iOS 26 devices and accepts up to 1,500 characters. It works on the current draft, including typed and dictated text. Review suggestion shows Original and Suggested edit with Keep original and an explicit Use suggestion action. Any intervening draft change invalidates the proposal. Applying never sends; unavailable cleanup leaves the draft unchanged. No cloud fallback, supplied model asset or third-party speech runtime is added.

Normal saving/saved text no longer occupies the composer. Draft options retains the storage status as an accessibility value; a failed save still displays Draft not saved, explanation and Retry saving. Removing the routine label does not remove persistence or failure handling.

## Ownership and validation

- `App/NativeAudioOwnership.swift`: weak, synchronous foreground audio handoff between voice and inline media.
- `App/VoiceController.swift`: generation-fenced recognizer/audio lifecycle, foreground limits and speech output.
- `App/ChatComposer.swift`: recording ownership, scoped snapshot insertion, direct draft integration and persisted continuous preference.
- `App/VoiceControls.swift`: inline microphone/stop action, options and draft-cleanup review.
- `App/VoiceTranscriptAssistant.swift`: availability-gated bounded on-device cleanup.
- `Sources/A0Core/VoicePermissionBridge.swift`: Sendable, nonisolated boundary for Speech/TCC completion queues; the repaired executor assertion is documented in `docs/tdd/voice/permission-crash.md`.
- `Sources/A0Core/VoiceDraftBuffer.swift`: partial/final segment accumulation and bounds.
- `Sources/A0Core/VoiceDraftInsertion.swift`: preserves the starting draft, replaces cumulative speech snapshots and rejects concurrent edits.
- Source and UI fixtures cover draft insertion, lifecycle isolation, permission denial and preference behavior; exact executed counts belong in the current TDD/acceptance receipt.

The owner confirmed working dictation on the physical iPhone before the move into the composer. That is real microphone evidence for the prior interaction, not acceptance of this new inline flow. New inline physical-device acceptance, extended continuous audio and FoundationModels cleanup quality remain distinct checks. Synthetic transcription and denial tests do not establish those results.

## References

Goose's [VoiceInputManager](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/VoiceInputManager.swift), [VoiceOutputManager](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/VoiceOutputManager.swift), [ContinuousVoiceManager](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/ContinuousVoiceManager.swift) and [EnhancedVoiceManager](https://github.com/aaif-goose/goose-mobile/blob/main/goose-ios/Goose/EnhancedVoiceManager.swift) informed separate input/output ownership and visible listening states. Source was reviewed, not copied; Goose's silence-based automatic submission is not adopted.

Apple references: [on-device support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition), [required local recognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition), [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession).
