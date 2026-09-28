# Voice authorization crash repair

## Device evidence

Read-only retrieval from the paired iPhone 15 running iOS 18.7.3 found two AgentZeroSpike crash reports dated September 28, 2026 at 18:08:37 and 18:09:05. Both report the same triggered stack:

```text
EXC_BREAKPOINT / SIGTRAP
queue: com.apple.root.default-qos
_dispatch_assert_queue_fail
swift_task_isCurrentExecutorWithFlagsImpl
closure #1 in closure #1 in VoiceController.start(continuous:)
thunk for SFSpeechRecognizerAuthorizationStatus callback
__TCCAccessRequest_block_invoke_8
```

The most recent physical build's Info.plist contains both NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription. The crash is an executor assertion in the Speech permission callback, not a missing usage-description termination. Raw reports remain outside the project; this receipt includes only the relevant sanitized symbols.

## Correction

The legacy Speech callback implicitly inherited MainActor from VoiceController.start while Apple's TCC service invoked it on a background queue. VoicePermissionBridge makes both registration and completion explicitly Sendable and nonisolated. The Speech authorization closure is explicitly Sendable as well. Only the Bool authorization result crosses into the async caller, which resumes on MainActor. Existing generation checks after each permission await continue to reject cancellation, background and dismissed-sheet results before microphone activation.

## Verification

A standalone Swift 6 executable used the production bridge from a MainActor entry point, delivered both granted and denied results on DispatchQueue.global, and passed both outcomes without executor assertions. VoiceController and the bridge typecheck against the iOS 17 simulator target with Swift 6. Two matching Swift Testing regressions are in VoicePermissionBridgeTests.swift for the integrated core run. No xcodebuild or microphone activation was performed in the isolated investigation.

This confirms the captured permission-callback failure mechanism and its correction. Physical voice recording, transcription quality and continuous-listening behavior still require a user-activated check after the repaired app is installed.

## Owner confirmation

After the repaired Release build was installed and launched outside XCTest on September 28, the owner confirmed: the app stays open and transcribes. This establishes one successful physical dictation session after the callback repair. The owner also requested that transcription move into the composer and that the continuous-listening preference survive closing the controls; those are subsequent UI changes, not additional crash symptoms. Sustained rollover and optional text-cleanup quality remain unverified.
