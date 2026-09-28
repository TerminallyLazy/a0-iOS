# Milestone 0 acceptance — September 28, 2026

**Current status: local interoperability and authenticated HTTPS/full Socket.IO state observed on a physical iPhone; full milestone security/recovery gates remain open. Historical slice results below retain their original scope.**

## Current acceptance map

| Gate | Current evidence | Remaining work |
| --- | --- | --- |
| Remote session login and state | HTTPS login and full Socket.IO state observed on iPhone 15 / iOS 18.7.3 | Corrected manual harness passes; wrong credentials, authenticated CSRF/Origin rejection and runtime rotation remain separate checks |
| Connection UI and Keychain | Keyboard-visible Connect and opted-in credential restoration pass on physical iPhone and simulator | Locked-device credential accessibility remains unverified |
| Camera onboarding | Physical QR capture, destination review and origin application observed | System permission denial and interruption still need physical evidence |
| Persistence and recovery | Six distinct synthetic hardware flows verified across bounded runs | Lock/unlock, actual network outage, cellular handoff and server restart remain unverified |
| Commands and release | Synthetic command/reconciliation tests and development installation | No live command execution, TestFlight or distribution acceptance |

The sections below are historical slice receipts. Later results supersede earlier pending items only for the specific checks listed above.

## Passed

- Xcode 27.0 (27A266a), Swift 6.4: iOS Simulator app build.
- Swift Package release build; Debug-only HTTP loopback entry point excluded from Release.
- 20 Swift tests, including parameterized URL/sequence cases: request wire shape, form encoding, bad-login HTML, redirects, missing session cookies, CSRF invalidation without replay, profile isolation, actual URLSession request handling, malformed JSON, null/empty collection behavior, streaming replacement, stale generations, GUID changes, ack errors, and push/poll state parity.
- Live Swift probe against the user-designated `http://localhost:49805`: CSRF bootstrap, HTTP snapshot decoding, `/ws` state-request acknowledgement (sequence base 1), and full state push applied (sequence 2). Only status/counts were logged; no conversation bodies or credentials saved.
- Native iOS 27 simulator (`Agent Zero Transport Spike`, iPhone 18 Pro): live UI reported **Socket.IO state is current** against that same instance. No chat was selected.
- Synthetic preview visually checked; screenshot in `simulator-preview.jpg`. It is UI evidence only.
- Existing backend contract/security suite run in a temporary network-disabled container, using `/opt/venv-a0/bin/python` (framework runtime), current source mounted read-only and fresh `usr`/`tmp`: **47 passed, 2 failed**. The container was removed automatically.

## Backend failures retained, not hidden

`tests/test_http_auth_csrf.py::test_http_auth_enforced_when_configured` and `::test_auth_redirect_includes_original_path_and_query` return 500 because their test Flask app has no `serve_index` route, which the current redirect helper resolves. These are existing fixture failures outside the native-app change. No backend source/test was changed to make the suite green.

The image lacked pytest-asyncio. The bounded run used `scripts/async_pytest.py` to execute the selected coroutine tests with `asyncio.run`; no async fixtures were supplied or emulated. Initially missing isolated `usr/plugins` was provisioned before the final run. Do not describe this as an unmodified full-suite pass.

## Remaining gates

- The designated instance permits unauthenticated bootstrap and uses HTTP. It cannot prove the real-server form-login or remote TLS path. Those paths currently have deterministic client tests only.
- The physical iPhone was unavailable to Xcode during inventory. Device-level connection, lock/unlock, Wi-Fi/cellular transitions, and certificate behavior remain unverified.
- Polling fallback is implemented and reducer parity is tested; deliberate real network-failure/foreground recovery exercises are still pending.
- No production changes, server restarts, messages, agent actions, signing, TestFlight upload, Git commits, or pushes were performed.
- Milestone 0 was verified as a read-only spike. A subsequent TDD slice now implements text creation/sending and busy-chat queue submission; live mutation acceptance remains unverified. Attachments, queue editing, Keychain and protected draft persistence, automatic foreground restoration, notifications, and administration remain pending.

## Next acceptance action

Run the same app against an authenticated HTTPS origin on a connected iPhone. Enter credentials directly in the app. Verify correct/wrong login, reconnect/runtime rotation, rejected certificate/CSRF/Origin, and foreground recovery before declaring Milestone 0 complete. No server authentication or certificate settings were weakened for this spike.


## Milestone 1 text slice — TDD follow-up

Native create/send, queue routing, per-chat in-memory drafts, delivery receipts, and uncertain-outcome protection are implemented. Drafts survive an in-process reconnect, scoped by server origin and username. Backgrounding invalidates in-flight completion; no automatic resend occurs. A matching log or queue receipt can resolve uncertainty. If no receipt appears, submission stays blocked; this slice does not offer a potentially duplicating retry override.

See [the TDD report](tdd/chat-slice.tdd.md) for exact tests and coverage. The latest read-only Swift probe again passed against `http://localhost:49805`. Synthetic send success is not live mutation, authenticated HTTPS, physical-device, or agent-completion acceptance. This remains a development preview, not a completed Milestone 1 release.


## Persistence/recovery slice — September 28 follow-up

The memory-only limitation of the earlier text slice is now addressed for drafts, selected context, and unresolved delivery receipts. After signing back into the same origin/username, drafts survive process termination and interrupted sends restore as uncertain. File writes precede mutating network requests. Corrupt/future-version archives fail visibly rather than being replaced. Storage failure prevents dispatch, preserves text in memory, and exposes a save-only retry. The composer offers a confirmed clear-draft action that retains unresolved delivery receipts.

57 core tests and 7 simulator flows pass. Coverage: A0Core 93.3%; app target 93.5%. Debug and unsigned Release simulator builds and SwiftPM Release build pass. iPhone iOS 27 and iPad iOS 26.5 saved-state layouts inspected. See [persistence evidence](tdd/persistence/persistence-slice.tdd.md).

Physical-device lock/unlock data-protection behavior, sudden power-loss durability, authenticated HTTPS, and live message mutation remain unverified. No credentials were persisted; Keychain/profile onboarding and automatic reconnection remain pending. No Agent Zero server mutations or source changes were made in this slice.


## Saved profiles / Keychain slice — September 28 follow-up

Saved server metadata and optional device-local Keychain passwords are now implemented. Metadata is saved after authentication, password saving defaults off, and selecting a saved server requires an explicit Connect. Origin/username edits clear the loaded password. Backgrounding clears typed/loaded passwords even before connecting. Forgetting a password preserves the server entry; removing a server confirms deletion of its metadata/credential while keeping drafts and uncertain delivery records. Credential-store failure leaves errors visible and never falls back to plaintext.

**64 core tests and 11 simulator flows pass.** The latter includes a real simulator Keychain round trip across termination with synthetic authentication, opt-out, identity edits, forgetting/removing, background clearing, and all prior chat/recovery flows. A0Core coverage is 93.8%; app-target coverage is 94.9%. SwiftPM Release and unsigned iOS Release simulator builds pass; the existing realtime weak-self capture warning remains. The iPhone profile form was visually inspected; no additional iPad or physical-device acceptance is claimed. See [profile TDD evidence](tdd/profiles/profiles-slice.tdd.md).

This supersedes the earlier pending Keychain/profile-storage items above. QR onboarding, automatic reconnect, real authenticated HTTPS, physical-device locked/unlocked Keychain behavior, and live message mutation remain unverified or unimplemented as described in the plan. No server modifications, new dependencies, commits, pushes, or distribution occurred.


## QR onboarding slice — September 28 follow-up

QR onboarding is implemented with a native VisionKit scanner and a shared HTTPS-origin validator/review flow. The user reviews the destination before applying it, then supplies credentials and explicitly connects. Confirmation clears old form credentials. Cancel preserves the connection form; invalid payloads do not echo sensitive values. Duplicate/stale scan results are ignored, and backgrounding/dismissal cancels camera work. Denied/unavailable cameras retain manual entry. No credential lookup, network connection, or persistence occurs during import.

**70 core tests and all 15 iPhone simulator flows pass**, plus the selected confirmation flow on iPad iOS 26.5. Core coverage: 94.2%; app-target coverage: 90.3%. SwiftPM Release and unsigned iOS Release simulator builds pass. iPhone/iPad review layouts were inspected together. See [QR TDD evidence](tdd/qr/qr-slice.tdd.md) for RED/GREEN logs, screenshots, source/API references, and remaining build warnings.

This supersedes earlier pending QR implementation items. Physical camera recognition, actual system camera-permission denial/interruption, authenticated HTTPS, and physical-device acceptance remain pending. Simulator camera-denied/unavailable flows use explicit isolated Debug overrides; they are not proof of camera capture. Automatic reconnect and the other milestone features remain pending. No live server action or source change, dependency installation, signing, distribution, commit, or push occurred.


## Foreground polling recovery — September 28 follow-up

Foreground snapshot reads now recover from selected transient failures with four bounded, jittered retries. Drafts remain visible/editable; sending is disabled until full current state returns. Exhaustion offers an explicit Retry sync action. Certificate/authentication/CSRF/protocol failures stop; backgrounding cancels recovery and still requires explicit sign-in on return. Commands and uncertain sends are never replayed. Last displayed state is retained while cursors/generations are invalidated for resynchronization.

**78 core tests pass** (94.4% core coverage). Full simulator regression recorded 18 of 19 flows passing; the existing send/reconnect test needed to wait for the newly gated Send control. After adding that readiness assertion and visible synchronization status, all eight chat/recovery flows passed. This verifies all 19 distinct flows across the full and focused runs, with no skipped tests. The selected recovery flow also passes on iPad. Both layouts were inspected, and SwiftPM/unsigned iOS Release simulator builds pass. See [recovery evidence](tdd/recovery/recovery-slice.tdd.md) for exact run boundaries, the reporting timeout, coverage, and known build warnings.

The new evidence is synthetic HTTP/coordinator recovery. Real network loss, runtime rotation, authenticated HTTPS, physical-device lock/unlock, automatic Socket.IO promotion, and automatic foreground reauthentication remain pending. No live server outage, task, message, server edit, dependency installation, signing, distribution, commit, or push was performed.


## Controlled realtime recovery — September 28 follow-up

Healthy foreground polling now attempts Socket.IO recovery at 30/60/120-second intervals, capped at 120 seconds. Each attempt refreshes the existing session without submitting credentials. Polling owns visible state until a validated handshake and full snapshot match the current context/generation and collection baseline. A delayed candidate cannot roll back polling versions or collection resets. Polling is canceled and fenced before socket state is published. Missing full socket state times out after 20 seconds; context changes, network recovery, backgrounding, and disconnect cancel the candidate. Drafts remain editable, and no command is automatically replayed.

**88 core tests pass**, with **95.0% core coverage**. All **24 distinct iPhone flows** are verified across regression groups and the final five-flow promotion rerun. One assertion in the first group expected the wrong existing composer placeholder; its correction passes. App source coverage across the runs is **86.5%** using a reproducible union of executable source lines. The selected handoff flow passes on iPad in Dark Mode with XXXL text, and both iPhone/iPad layouts were inspected. SwiftPM Release and unsigned iOS Release simulator builds pass. The iPad orientation warning and a Release linker diagnostic remain documented. See [promotion evidence](tdd/promotion/promotion-slice.tdd.md) for exact run boundaries, RED/GREEN receipts, coverage method, and screenshots.

This supersedes earlier pending automatic Socket.IO-promotion implementation items. The handoff tests use synthetic HTTP and realtime callbacks with accelerated timing; actual Socket.IO reconnection during a network outage, server restart, authenticated HTTPS, and physical-device behavior remain unverified. Background-to-foreground automatic sign-in remains unimplemented. No live server mutation, dependency installation, signing, distribution, commit, or push occurred.


## Physical iPhone and visible Connect action — September 28 follow-up

Development signing/install succeeded on iPhone 15 / iOS 18.7.3 using the existing authorized identity. Six distinct synthetic hardware flows passed across initial/corrected/background runs: draft persistence/clearing, uncertain delivery without replay, opted-in Keychain restoration with explicit Connect, QR review/credential clearing, realtime promotion with draft retention, and cancellation after a verified background transition. These are not a single all-green run.

The owner-assisted physical camera scan reached destination review and applied the designated HTTPS origin. The first sign-in wait timed out at Not connected; the owner reported no visible Connect button. Connect now occupies the bottom safe area above the keyboard, with a password-keyboard Go action and unchanged authentication gating. The placement test failed before implementation (195.333-point bottom gap); three focused simulator checks now pass. The new action bar has 100% executable-line coverage. Unsigned Release simulator and development Debug builds pass.

The post-fix physical automated run passed QR confirmation and button placement, but connection did not reach Polling and another test failed keyboard focus. Those failures remain unresolved hardware-automation evidence. The separate owner-assisted retry reached Live on the physical iPhone, establishing authenticated HTTPS and applied Socket.IO state. Its result bundle still failed a subsequent Disconnect-element assertion; the manual harness now checks visible full-state confirmation before reporting success. That harness correction is build-checked, not owner-rerun. See [the device report](tdd/device/device-slice.md) for exact bundles and limits. No chat command, backend edit, dependency installation, commit/push, or distribution was performed. Live network interruption, locked-device protection, and full milestone acceptance remain open.


## Physical keyboard regression closure — September 28 follow-up

Both previously failing physical checks now pass on iPhone 15 / iOS 18.7.3, and the same two checks pass on the iOS 27 simulator. Failure captures showed XCTest aiming at Username underneath the fixed bottom action bar. The test helper now scrolls the field into the visible form before typing; production UI and authentication behavior are unchanged. See `connect-device-recheck.xcresult` for reproduction, `connect-device-scroll.xcresult` for physical GREEN, and `connect-scroll-simulator.xcresult` for simulator GREEN in the [device evidence directory](tdd/device/device-slice.md).

Unauthenticated HTTPS CSRF-bootstrap and poll requests still redirect to same-origin sign-in. The corrected owner-assisted authenticated live test also passes: one test, zero failures in `iphone-live-confirmed.xcresult`, observing both Live and full Socket.IO state confirmation after owner sign-in. No chat command was submitted. This supersedes the earlier build-only status of that harness correction. No fresh full-suite, locked-device, network-outage, or authenticated CSRF/Origin-negative result is claimed by these focused checks.


The owner saw chats after the passing live check, then reported app closure. XCTest teardown occurred immediately after the success observation; no app-named device crash report was found. The app has been relaunched outside XCTest. The owner then confirmed that sign-in outside XCTest stays open with chats visible. The same process remained running and no new app-named crash report appeared. This supports test teardown as the explanation; the successful bounded transport check and owner observation are not sustained-session stability testing.


## Existing-chat navigation correction

Selecting an existing chat now opens a dedicated conversation screen rather than leaving the transcript below the chat list. Stable context IDs preserve row identity, state updates keep the screen open, Back retains drafts, and disconnect clears navigation. Two new flows pass on iPhone simulator and physical iPhone; the switching/draft flow also passes on iPad. Four existing chat-command/reconnect tests also pass after the final lifecycle change. Focused conversation source coverage is 83.2%; unsigned Release and development builds pass. See [the correction report](tdd/conversation/conversation-fix.md). The owner is checking their live chats outside XCTest; no live content was captured or message submitted.


## Branded chat UI and reading behavior — September 28

The owner reports existing live chats now open and support sending/receiving. New-chat navigation now uses a persistent draft route. Agent Zero branding, native Markdown, long-message collapse, consecutive activity grouping, message/code copy and explicit Latest navigation are implemented. See [chat UI evidence](tdd/chat-ui/chat-ui.tdd.md) and [Goose reference decisions](GOOSE-REFERENCES.md).

Verification: **97 core tests**, **27 existing native regression flows across two simulator runs**, **five focused physical iPhone flows**, and light/dark/maximum-text iPad checks pass. The final unsigned iOS Release build succeeds. Earlier failures are retained with causes and correction receipts; this is not a single fresh all-target test run. Automated checks are synthetic and never send a task to the owner's live server. The refreshed app is launched normally after XCTest; owner confirmation of live new-chat creation and the updated reading interface remains pending. Voice, sidebar/favorites, attachments, management and complete WebUI parity remain planned.


## Tool presentation, keyboard and Settings — September 28

The owner's screenshots identified raw `icon://` headings, hard-to-read tool activity, persistent keyboard focus and missing Settings. The native client now maps heading tokens to SF Symbols, summarizes structured activity, keeps raw JSON under disclosure, provides a keyboard-dismiss button, and exposes local appearance/reading/connection Settings. Existing account and credential protections are preserved.

**100 core tests pass**, including presentation tests. **Five focused physical iPhone 15 / iOS 18.7.3 flows pass**: keyboard dismissal with draft retained; Settings persistence; native icons and tool details; appearance/grouping application; and confirmed server change followed by reconnect with the draft retained. The corresponding iPad checks include light mode and maximum Dynamic Type in dark mode. These use synthetic profiles and never mutate the live server. See [refinement evidence](tdd/interface-polish/interface-polish.tdd.md) for run boundaries and remaining limitations.


Final refinement verification: 3 physical and 2 light-iPad checks pass after the supporting-text contrast correction; the 5 existing chat/connection regression checks pass, and the retained-draft reconnect check passes after the test reveals its offscreen root-list target. Final Release build succeeds. The final device build was opened normally outside XCTest. See the [complete scoped receipt](tdd/interface-polish/interface-polish.tdd.md); live owner acceptance remains separate.


## Native generated replies and rich catalog — 2026-09-28

The pinned A2UI-Swift adapter renders explicit assistant payloads as native forms, forecasts, image carousels, charts and adaptive dashboards. Settings → Rich replies defaults on and advertises the catalog with each explicit send. Native form actions use review → add to draft → explicit Send. No backend modification is required.

119 tests pass (100 existing core, 19 generative). Final focused rich-content flows pass on physical iPhone 15 / iOS 18.7.3 and the iPad simulator at maximum Dynamic Type; two form flows and four existing chat/delivery flows also passed on the phone. Unsigned Release simulator build passes. The updated development app was reopened normally outside XCTest. See [TDD evidence and precise run boundaries](tdd/generative-ui/generative-ui.tdd.md).

All content and transport acceptance in this slice is synthetic. Live model generation, Google image retrieval and actual external image display remain unverified. Existing owner-assisted authentication acceptance above is unchanged.


## Workspace, session continuity and on-device voice — 2026-09-28

The physical iPhone passes all ten existing interface flows plus session background/termination restoration and passive Voice. The final Workspace flow passes after selector fixes and dedicated History/Context navigation. Maximum-text dark iPad confirmation passes Workspace and Voice. Core/generated tests total136 (117+19); final Release simulator build passes, and the latest development app was reopened normally outside XCTest.

Native tools include Pause/Resume, Nudge, History and Context; other WebUI capabilities are reached through the confirmed browser handoff. Voice dictation and continuous foreground listening require explicit Listen, keep recognition on-device where supported, and add reviewed text to the ordinary draft. FoundationModels cleanup is optional on supported iOS26 configurations. No microphone was activated during acceptance. Live audio/model quality and server control actions remain owner checks. See [complete run boundaries](tdd/workspace/workspace.tdd.md).

## Projects, model presets, launch drawer and inline voice — 2026-09-28

Native Projects include colored assignments, filters, create/edit/clone/delete and starting a chat inside a project. Model Presets expose current-chat overrides and explicitly shared definition editing. Advanced project resources, project-default model selection and provider credentials retain the WebUI handoff. Server-reported context accounting appears in a compact popover; conversation tools use an anchored popover. Authenticated cold launch displays startup branding, then a new draft with the sidebar closed while retaining earlier chat drafts and restoring A2UI when an earlier chat is opened.

The physical Speech permission crash was traced to a MainActor-inherited callback invoked on TCC's background queue and corrected with a Sendable nonisolated bridge. The owner confirmed the repaired app stays open and transcribes. The subsequent requested refinement streams dictation directly into Message, persists continuous-listening preference without automatically starting recording, preserves typed edits, and removes the routine saved-state caption. Errors and draft-saving recovery stay visible.

162 package tests pass. Focused phone and maximum-text iPad UI flows pass across the documented initial/corrected runs; seven distinct physical persistence/inline-voice checks are covered. Release builds and installation succeeded, and the updated app was opened normally outside XCTest. The corrected context counters and composer passed visual review. See [precise run boundaries and limitations](tdd/model-presets/workspace-controls.tdd.md). Synthetic controls tests do not establish live server mutations or sustained microphone behavior; the owner's dictation check predates the inline UI refinement.


## Browser captures, attachments and Queue/Steer — 2026-09-28

Browser tool screenshots now use contained native previews, conversation tools provide image/file attachments, and the composer carries a tappable connection dot. Send spins during agent work while allowing follow-ups; Settings selects Queue (default) or immediate Steer. Attachment preparation blocks premature sends and preserves uncertain outcomes without replay.

192 package tests pass. Focused simulator, physical iPhone and maximum-text iPad flows pass across the explicitly recorded runs, including the final slow-import device check and corrected large-text layouts. The signed Release app was installed and launched normally on the iPhone. See [exact evidence and run boundaries](tdd/chat-media/chat-media.tdd.md).

New media, upload and Queue/Steer acceptance is synthetic. Real screenshot availability, actual uploads and live agent scheduling remain owner checks; no live task or attachment was submitted. Earlier owner-authenticated session acceptance remains valid and separate.
