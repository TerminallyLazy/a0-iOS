# Inline playback amendment

The user requested audio and video in the reply instead of a separate player screen. The download/validation boundary is unchanged: explicit Load, then Play, no autoplay, credential-free bounded direct files, no redirects or generic embeds.

## Test-first sequence

`ChartMediaUITests.testAudioAndVideoPlayInlineWithoutLeavingConversation` failed against the sheet implementation: no inline player, composer not hittable, and the separate close control remained visible (`/tmp/a0-inline-media-red.xcresult`).

`GeneratedMedia` now embeds compact controls and a bounded 16:9 video frame; Unload replaces the sheet's Done action. Source/background/disappearance lifetime is retained. A clip-to-clip handoff pauses the prior clip, and unloading an inactive card cannot deactivate current playback.

The first focused iPhone run passed all seven selected cases in 184.4 seconds (`/tmp/a0-inline-media-phone-green.xcresult`): inline audio/video and composer access, play/seek/background cleanup, failure/cancellation, ordinary direct-link previews, read-only Agents playback, reply-source replacement, and multiple-card handoff. Fixtures are local synthetic media; no external hosts or owner microphone were accessed.

Review additionally identified shared audio-session ownership with composer dictation/read-aloud. The dedicated handoff regression failed with media still playing after synthetic dictation began (`/tmp/a0-inline-media-voice-red.xcresult`). `NativeAudioOwnership` now synchronously transfers a weak ownership reference: media pauses while retaining its file; voice stops capture/synthesis and invalidates pending permission callbacks. Only the current owner can deactivate the shared session. Review approved this correction.

The initial large-text native test swiped at a fixed screen fraction occupied by the composer at that text size, opening Model presets instead of scrolling the transcript. The test now derives swipe coordinates from the actual transcript area; that failure is harness evidence, not a product defect. Final verification follows below.

Screenshots: [inline audio](../../evidence/agents-media-theme/phone-inline-audio.png), [inline video](../../evidence/agents-media-theme/phone-inline-video.png). Gray video frames and silent audio are intentional fixture content.

## Final phone verification

After shared audio ownership was added, six focused iPhone 14 Plus / iOS 26.5 dark tests passed in 129.4 seconds (`/tmp/a0-inline-media-phone-final.xcresult`): media/dictation handoff, multiple-card handoff, playback/seek/background release, largest-text video controls, existing synthetic dictation draft insertion, and existing background dictation shutdown. Across the two passing inline runs, 11 distinct native cases passed. The earlier seven-case run predates shared voice ownership; the final run specifically covers that amendment and its regression boundaries.

Large-text swiping uses the measured transcript band. Review approved the final weak synchronous audio coordinator, including stale permission/synthesis callbacks and inactive-card cleanup. Signed Release build and strict signature verification passed. Four final iPad Pro 13-inch (M5) / iOS 26.5 light cases passed in 100.3 seconds (`/tmp/a0-inline-media-ipad-final.xcresult`): inline audio/video with reachable composer, largest-text video controls, dictation handoff, and source replacement in read-only Agents. [iPad inline video](../../evidence/agents-media-theme/ipad-inline-video.png) preserves the synthetic layout evidence.

Direct installation and ordinary launch succeeded on the paired physical iPhone 15 / iOS 27.2, version 0.1.0 (5), without fixture arguments. This proves delivery, not live media-host or hardware microphone/audio acceptance. No commit, push or TestFlight upload occurred. Task-owned DerivedData, result bundles, exports and tool test products were removed after retaining these receipts and screenshots.
