# Native Agents, media and theme acceptance

All fixtures are DEBUG-only synthetic data. No live server chat, API credential or external media host is accessed. Tests use an isolated preference suite and locally generated playback files.

## RED evidence

`AgentsMediaUITests` was authored before native production changes. A first build failure caused by a fixture block in the wrong switch branch was corrected; it is not behavioral RED evidence.

The corrected native run (`/tmp/a0-agents-media-ui-red2.xcresult`, temporary local evidence) demonstrated:

- `testAgentsSheetChromeUsesServerTheme`: after confirming Matching Catalog Ocean in Settings, the Agents header retained system RGB `[28,28,30]` instead of the themed panel.
- `testPlainReplyOffersExplicitAudioAndVideoLoading`: the ordinary response lacked Load audio/video controls.
- `testNewSubagentDiscoveryPreservesParentDraftAndAttachment`: the compact subagent control was missing.

The read-only test initially had an ambiguous query because the underlying chat and Agents sheet both contained Load audio. After scoping to the sheet control, `testReadOnlyAgentsStillAllowsExplicitMediaLoading` failed at the enabled-state assertion (`/tmp/a0-agents-media-readonly-red.xcresult`). That is the valid regression evidence for the blanket generated-view disabling bug.

## Authored native acceptance

- Ordinary assistant MP4/MP3 links retain prose, offer two explicit Load controls and open the existing native player only after selection.
- Passive media remains usable from the read-only Agents sheet; draft-producing generated actions remain separately gated.
- Theme checks sample the actual header after theme readiness and the phone's bottom safe area; screenshots preserve visual evidence.
- A historical child is present initially, while a new child arrives through a later synthetic poll. The compact control signals newness without navigation, the child opens explicitly, and returning preserves the parent's draft and staged attachment.
- Existing-child navigation and parent return stay reachable at accessibility text sizes.

## GREEN and limitations

The first native implementation run passed four flows: themed Agents chrome, ordinary audio/video links, passive media with disabled draft actions in read-only Agents, and accessibility-size child navigation. The parent-roundtrip test tapped Return while the child's first full snapshot was still pending; it now waits for that intentionally disabled control to become enabled before tapping.

Review added two lifecycle regressions:

- New-subagent badges must survive Home → foreground within the same authenticated session. This failed behaviorally before the discovery-scope correction.
- An open read-only player must close when its response source changes while media URL/node ID remain identical. The first replacement fixture changed content without increasing `log_version`, so the reducer correctly ignored it; that run is not source-lifecycle bug evidence. The corrected fixture increments the version once with the title change. It still failed with the old player open (`/tmp/a0-agents-media-source-check.xcresult`), establishing behavioral RED. `A2UISurfaceView` now has explicit source identity so a changed response deterministically tears down its previous native component state. Identical source snapshots preserve it.

Before the inline-playback amendment, iPhone 14 Plus simulator verification (iOS 26.5) passed all **10 tests in 260.9 seconds**: all seven `AgentsMediaUITests` flows plus existing native playback/background teardown, Queue/Steer and Stop regressions. The temporary local result was `/tmp/a0-agents-media-phone-final.xcresult`. Selected compact screenshots are retained under `docs/evidence/agents-media-theme/`. Both newly discovered lifecycle regressions passed after their corrections. iPad verification is recorded separately when complete.

## Inline-playback amendment

The user subsequently requested playback directly inside the reply. The new `ChartMediaUITests/testAudioAndVideoPlayInlineWithoutLeavingConversation` failed against the old sheet implementation: the inline player was missing, the composer was inaccessible and the separate screen remained present (`/tmp/a0-inline-media-red.xcresult`).

`GeneratedMedia` now embeds the native player: a constrained 16:9 video and compact audio controls, explicit Load then Play, seek/captions, and Unload. Tests now target inline unload/teardown rather than closing a separate screen. A focused two-card test checks that starting video pauses audio and unloading the earlier audio leaves video playing; its local synthetic files are 32 seconds only in that fixture.

Review found that composer dictation/read-aloud shares AVAudioSession with these now-inline players. A new native regression failed when starting synthetic dictation left media playing (`/tmp/a0-inline-media-voice-red.xcresult`). The shared weak main-actor ownership coordinator now pauses a preceding media player or stops preceding composer voice, fences pending permission callbacks through the existing voice generation and lets only the current participant deactivate the system session. The test also checks the reverse handoff preserves dictated draft text. Synthetic dictation exercises coordination without microphone access; actual recording/speech playback remains separate device acceptance.

The first large-text inline test accidentally opened Model presets: its fixed screen-coordinate swipe crossed the enlarged composer. Both media test scroll helpers now use the measured transcript band above the composer. That failure was a test gesture error, not evidence of a playback failure. Inline GREEN verification is pending.

Unit/transport tests and code review own proof of zero automatic network requests and untrusted URL handling; absence of a player sheet alone does not prove zero requests. Synthetic playback does not prove real media hosts, live model A2UI generation or physical-device acceptance.

Final iPad Pro 13-inch (M5) / iOS 26.5 light run passed all seven `AgentsMediaUITests` in 184.9 seconds with zero failures (`/tmp/a0-agents-media-ipad-final.xcresult`). Header pixel assertions and screenshot inspection verify the light sheet palette; the phone run verifies dark header and bottom safe area. Synthetic images are retained under `docs/evidence/agents-media-theme/`.
