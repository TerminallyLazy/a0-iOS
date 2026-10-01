# Milestone 0 acceptance — September 28, 2026

## October 1 — Shared computer setup (local development)

### Release-candidate follow-up

The final Mac setup tests passed through the development Launcher: Browser
verified typing and capture on its owned temporary page; Computer verified
a fresh capture without sending desktop input. Both appeared as Tested in
shared readiness. The original Launcher then reconnected using saved sign-in.
On the physical iPhone, the explicitly reviewed old heartbeat receipt was
cleared, the expired viewer lease recovered, and Return to A0 acknowledged.
The viewer returned to Take over computer without replaying the old action.
The development tab was closed, leaving the original host connection active.

Fresh release checks: 237 Swift package tests, six WebUI adapter tests,
52 Core targeting/viewer/setup tests in the selected framework runtime,
29 connector ownership/viewer/setup/gateway tests and 183 Launcher tests passed
(one Launcher platform test skipped). Earlier full connector/baseline failures
below remain disclosed. The three iOS UI checks below cover unchanged UI source.

Launcher now handles a fixed, payload-free setup app link with cold/warm-launch
queuing and manual fallback. Packaged OS dispatch and Windows/Linux native
installation/permission acceptance remain separate release gates. Tutorial
videos remain optional; text guidance is complete without them. This is a beta
candidate, not certification of every platform or unattended host use.

Implemented themed native setup, a chat-independent protected Core API, shared
help, owner-bound ten-minute continuation codes, and a Launcher assistant with
separate local consent and explicit connection tests. Launcher source is based
on upstream 1.8/b0333d8; connector source is based on 2.13/76e834f with the prior
live-viewer changes preserved. Core target: curious-bohr, 2.13/e3051fb5.

- Physical iPhone 15: signed Release built and installed. The existing HTTPS
  profile showed server/host readiness with the selected theme. A code created
  on the phone was claimed by the isolated development Launcher on this Mac;
  confirming the host on the phone appeared in Launcher. No host scopes changed.
- WebUI: Connect your computer opened from More options and showed shared
  readiness/help using the active theme. Setup required no chat or model call.
- iOS: 237 core tests passed; three UI tests passed, covering continuation and
  existing takeover/handback plus light/dark viewer and Computer sheet colors.
  Bundle: `/tmp/a0-live-derived/Logs/Test/Test-AgentZeroSpike-2026.10.01_06-53-00--0400.xcresult`.
- Core: 13 focused tests passed in the named container's framework runtime.
- Connector: 46 focused tests passed. Full suite: 972 passed, 75 failed,
  11 skipped. Unchanged upstream under the same environment and Core source:
  955 passed, the identical 75 failures, 11 skipped. This is not a green full
  suite; failures include Core fake-module compatibility, macOS case-insensitive
  paths and an RSS assertion. Failure-set comparison found no new failures.
- Launcher: 96 focused tests passed; fresh guided scopes, existing scopes,
  session/CSRF boundaries, base paths and gateway controls are covered.

**Initial slice receipt (superseded by the release-candidate follow-up above):**
The final Core reload expired the desktop login. Manual sign-in restored the
development Launcher's WebUI session. Its host gateway remains disconnected
with development scopes off; this is not live host-reconnection acceptance.
Fresh unauthenticated local and Dev Tunnel requests both redirect to `/login`;
runtime UI Login and UI Password are configured (values were not disclosed).
Actual connection-test capture/input acceptance is also pending: the existing
uncertain host receipt and held state were preserved. Connection-test helpers
were exercised with isolated fakes. Installed production Launcher/connector
were not replaced; new desktop work remains in the isolated development source.
At the initial slice receipt, app-link dispatch and tutorial clips were not
included and nothing had been published. The release-candidate follow-up above
supersedes that implementation status; distribution is recorded in TESTFLIGHT.md.

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

## Plugins — September 30, 2026

The conversation sidebar now opens a native Plugins workspace with installed inventory, searchable/filterable Plugin Hub, installation/update, scoped activation/inheritance/override removal, protected-plugin restrictions and custom-plugin deletion. Settings and main screens use the initialized server WebUI inside an ephemeral, authenticated WebKit presentation. Native commands retain ControlJournal receipts; the user-approved embedded-WebUI exception preserves plugin-owned actions without native per-action receipts. See [behavior, boundaries and screenshots](PLUGINS.md).

Source basis: iOS `9648e92` plus the current uncommitted feature; server `6a6cecff` as inspected in `/Users/lazy/Desktop/agent-zero`. Existing unrelated server changes were preserved, and no server source was modified. Native lifecycle verification uses local `PreviewHTTPTransport`; the embedded fixture at `https://127.0.0.1:18447` serves real WebUI assets plus a synthetic `fixture-plugin` and in-memory APIs. It does not run Agent Zero, execute installation hooks, or serve `usr/`.

Verified package baseline: **196 tests in 16 suites pass** with coverage (`/tmp/a0-plugin-final-package.log`). The four JavaScript adapter tests pass and directly cover 403 retry suppression, credentials/redirect policy and page teardown. Xcode simulator builds compile the app and UI tests without dependency installation.

Native plugin install/delete, update, deactivate/protection and uncertain-command flows pass on the Agent Zero Transport Spike iPhone simulator (iOS 27). Existing drawer, model-preset selection/shared editing, project-to-new-chat and background/relaunch-session regressions pass in focused runs. The iPad Pro 13-inch (iOS 26.5) passes the plugin maximum Dynamic Type flow after page-sized presentation and navigation targeting were corrected; [details](evidence/plugins/ipad-accessibility-detail.png) and [Hub](evidence/plugins/ipad-accessibility-hub.png) were visually inspected. These are separate focused runs, not one full UI-suite run.

**Final integrated plugin run: 6 tests, 0 failures** on iPhone 14 Plus / iOS 26.5 after temporary diagnostics were removed: install/delete/suspension, update, deactivate/protected plugins, uncertain commands, maximum text size, and real-WebUI settings save/reopen plus main action, 403 single-attempt rejection and background teardown. Log: `/tmp/a0-plugin-final-combined.log`; result: `/tmp/a0-plugin-derived/Logs/Test/Test-AgentZeroSpike-2026.09.30_04-12-12--0400.xcresult`. The embedded test executed against the fixture; it did not skip.

Intermediate failures are retained in local logs: fixture omissions initially prevented WebUI setup; selector assumptions affected native confirmations and WebUI Save (which closes its modal); one simulator rendering-process crash interrupted an update test, which passed on rerun. Repeated embedded startup failures were traced to the disposable HTTPS listener performing TLS handshakes in its accept loop. The fixture now performs handshakes in request workers; a deliberately unhandshaken connection no longer blocks a verified HTTPS request. Production bootstrap is also bound to the initial root navigation. After these changes the complete embedded flow passed twice consecutively in `/tmp/a0-plugin-https-fixed.log` (85.5 seconds total). Startup timeout and bootstrap errors have distinct recovery messages and a 60-second loading deadline. Verbose Xcode failure-diagnostic collection stalled two screenshot/accessibility runs; those collectors were stopped and focused reruns use `-collect-test-diagnostics never`. Successful screenshots/functional checks are not inferred from those interrupted result bundles.

Production/custom-plugin compatibility, real Git install/update hooks, secret-field/scoped custom-form behavior, specialized socket transports, downloads/OAuth popups, physical-device acceptance and TestFlight distribution remain unverified. No live plugin was installed, toggled, configured or deleted, and no release, commit or push was made.


### Plugins — connected iPhone handoff, September 30

At the owner's request, the current uncommitted plugin implementation was built in Release configuration, signed with the existing development team, installed on the USB-connected iPhone 15 / iOS 27.2, and launched normally outside XCTest. Build and code-signature verification passed; the embedded adapter is present in the installed app bundle. `devicectl` confirmed installation and launch. The local version remains 0.1.0 (4); this is a direct device installation, not a new TestFlight upload. Local receipts are `/tmp/a0-plugin-device-build.log`, `/tmp/a0-plugin-device-install.json` and `/tmp/a0-plugin-device-launch.json`.

This establishes device build/install/launch, not successful live plugin operations. The owner is testing the sidebar Plugins workspace and embedded screens. No automated live plugin installation, activation, settings save or deletion was performed during this handoff.


### Custom/Built-in collections and thumbnails — September 30

The owner's follow-up replaces Installed with Custom and Built-in while keeping Plugin Hub. Rows and detail screens now show declared plugin artwork, with a consistent fallback. Installed images use bounded authenticated thumbnail-path reads; external Hub images reuse the credential-free public-image client. Scope, protected-plugin and journal behavior are retained.

199 package tests pass, including thumbnail path/origin/credential policy and redirect/non-image rejection (`/tmp/a0-plugin-thumbnail-core.log`). Four of five initial iPhone UI checks passed; the uncertain-command assertion needed to scroll because the new detail artwork moved its button outside the visible form. The corrected uncertain-command check and collection/protection flow both pass in `/tmp/a0-plugin-thumbnail-final-ui.log`. The maximum-text iPad check passes in `/tmp/a0-plugin-thumbnail-ipad.log`. This covers all five distinct native plugin flows across the initial/corrected runs. Custom/Built-in screenshots visibly show decoded synthetic artwork; the maximum-text views remain usable.

The final signed Release device build succeeded and was installed and launched normally on the connected iPhone 15 / iOS 27.2 for owner testing. Receipts: `/tmp/a0-plugin-thumbnails-device-build.log`, `/tmp/a0-plugin-thumbnails-device-install.json`, `/tmp/a0-plugin-thumbnails-device-launch.json`. Version remains 0.1.0 (4); no TestFlight upload or live plugin mutation was performed. Actual server/CDN artwork availability remains an owner check.


### Embedded Dev Tunnels handoff — September 30

The owner reported blank plugin screens after clicking Continue on the Microsoft Dev Tunnels notice. Source review found that the initial browser request lacked the documented interstitial-skip header and that WebUI bootstrap could run against unexpected root HTML; a later navigation retained native ready state while losing the initialized plugin document. The host now sends the documented header only to its authenticated Dev Tunnels origin, validates the loaded shell before importing modules, and invalidates the presentation when a later main-document navigation replaces it. No request or plugin action is automatically replayed.

200 package tests pass (`/tmp/a0-plugin-tunnel-core.log`), including exact tunnel-host header policy. Five JavaScript adapter tests pass, including same-origin-only header injection and lookalike/external-host rejection. Both final embedded UI tests pass (`/tmp/a0-plugin-tunnel-final-ui.log`): real WebUI settings save/reload, main action, one rejected request, background clear, unexpected-root recovery, explicit reopen and subsequent document-replacement recovery. These run against the disposable local HTTPS fixture, not Microsoft's live relay.

The signed Release build passed and was installed and launched on the owner's iPhone 15 / iOS 27.2. Device receipts use the `/tmp/a0-plugin-tunnel-device-` prefix. The owner can retry SkillOpt; actual live tunnel/plugin success remains to be confirmed. No server files or live plugin configuration were changed. The disposable fixture was stopped and its owned private key removed after verification.


### Direct WebUI document correction — September 30

The owner's follow-up RRSI screenshot still showed the unexpected-document recovery message. The tunnel-only fix above was insufficient. Read-only inspection of both the tracked server and running container `a0-inst-curious-bohr-mue3503n` found that `helpers/ui_server.py` serves `webui/splash.html` at `/`; that splash fetches `/ui/index` and replaces the current document with `document.open/write/close`. The previous fixture incorrectly served the index directly at `/`, hiding this integration mismatch.

The native plugin host now requests authenticated `/index.html` directly with the existing tunnel header. This skips the document-replacing splash and preserves root-relative resolution of the index's relative assets; directly navigating to `/ui/index` would give those assets the wrong base path. The fixture now serves the actual splash at `/`, maps the actual shell at `/index.html`, and asserts zero root-splash navigations during settings/main interaction.

All 200 package tests pass (`/tmp/a0-plugin-direct-shell-core.log`). Both embedded UI flows pass against the corrected fixture (`/tmp/a0-plugin-direct-shell-ui.log`): settings save/reopen, main action, no retry, background clearing, unexpected-document recovery and explicit reopen. The final signed Release build was installed and launched normally on iPhone 15 / iOS 27.2; receipts use `/tmp/a0-plugin-direct-shell-device-`. Actual owner-tunnel RRSI/SkillOpt acceptance is still pending. No live plugin mutation or server source change was made; the disposable fixture was stopped and its owned key removed.


### Workspace canvas and siderail — September 30

The owner confirmed the direct-document plugin fix worked, then requested the right sidebar and siderail tools in the app. The native chat toolbar and sidebar now open a full-screen Workspace. It uses the existing authenticated WebUI canvas/store/extension registry for File Browser, Browser, Desktop, Editor and custom plugin surfaces. Opening from a native draft does not create a chat. Phone surfaces float; tablet surfaces dock with the original rail and tabs. Plugin screens can hand off to registered surfaces while retaining their browser session.

The implementation fixes WebKit user-script module imports by resolving an absolute origin URL, leaves embedded frame layout untouched, labels modal/file action controls, and removes the rail translation that gave tablet accessibility elements incorrect hit regions. Inactive panels remain mounted but leave the accessibility tree. Same-origin exports use a protected temporary destination and the iOS share sheet, rejecting redirects/failed responses and never resuming automatically.

202 package tests pass (`/tmp/a0-workspace-core-complete.log`); six adapter tests pass (`/tmp/a0-workspace-adapter-tests.log`). The final iPad Pro 13-inch / iOS 26.5 fixture flow passes in `/tmp/a0-workspace-ipad-rail.log`: original File Browser metadata and download through the native share sheet, each registered tool, custom plugin panel interaction, child-frame input and background clearing. Initial tablet tests exposed the missing accessible file-action names and inaccurate translated rail bounds; the final run includes both fixes. The test uses WebUI assets from server checkout `6a6cecff8527b164668c7a6ab2f76b6b1ed7cfa1` with its current local frontend files, a disposable local HTTPS server and synthetic APIs/surfaces. This does not verify live Desktop streaming, Browser automation or real Editor saves.

The final Release build and code-signature verification passed. Both bundled JavaScript adapters match the final source. The app was installed and launched normally on the paired iPhone 15 / iOS 27.2 with the existing development identity, retaining version 0.1.0 (4). Receipts: `/tmp/a0-workspace-device-final-build.log`, `/tmp/a0-workspace-device-install.json`, `/tmp/a0-workspace-device-launch.json`. This is a direct development-device handoff, not a TestFlight release. Owner testing of live Workspace services remains separate; no server source, real files or plugin settings were changed by the automated checks.

The final iPhone 14 Plus / iOS 26.5 Workspace and unexpected-document flows pass in `/tmp/a0-workspace-phone-complete.log`. Its extended settings/main/handoff check initially failed because the synthetic plugin used a relative dynamic import inside the WebUI's blob-loaded module. Correcting that fixture import to an absolute origin URL produced a passing focused run in `/tmp/a0-workspace-handoff-final.log`, including settings save/reopen, a single rejected request without retry, plugin-modal-to-surface handoff, interactive custom panel and background clearing. Thus all three distinct phone flows pass across the final and corrected-fixture runs; this is not a claim that the initial combined run passed. Six adapter checks were repeated against the final bundled source in `/tmp/a0-workspace-adapter-final.log`.

The owned disposable fixture was stopped and its temporary TLS private key removed after verification. No commit, push, dependency installation or TestFlight upload was performed.


### Floating Workspace tab and plugin card switches — September 30

The duplicate top-toolbar Workspace icon is removed. ConversationView now presents a single material-backed floating tab at the right edge, with a 44-point hit target, transcript clearance and no overlap with the composer. It disappears while the left drawer is open; the sidebar Workspace menu remains available.

Custom/Built-in cards replace their enabled/disabled badges with native switches. Details use a separate explicit button; switches have independent touch/accessibility targets, avoiding List row navigation swallowing toggle taps. Commands set global activation through the existing ControlJournal, retain scoped overrides, refresh only after acknowledgement and block changes while busy or uncertain. Always-enabled plugins remain locked on.

202 package tests pass in `/tmp/a0-card-toggle-core.log`. Both new focused iPhone UI tests pass in `/tmp/a0-card-controls-ui.log`: off/on transitions without detail navigation, protected built-in switch, no top-toolbar Workspace button, accessible floating tab and uncertain-outcome blocking. The same card/tab flow and the maximum-text plugin/Hub flow pass on iPad in `/tmp/a0-card-controls-ipad.log`. An older tablet detail test used an unscoped navigation-bar Back locator; it was changed to target the Core Fixture navigation bar explicitly. Initial card tests caught the row-wide interaction issue; the final card layout has separate controls and passes the focused checks.

The final signed Release build passed, and `devicectl` confirmed installation and normal launch on the owner's iPhone 15 / iOS 27.2. Receipts: `/tmp/a0-floating-toggle-device-final-build.log`, `/tmp/a0-floating-toggle-device-install.json`, `/tmp/a0-floating-toggle-device-launch.json`. Version remains 0.1.0 (4); no TestFlight upload, commit, push, dependency installation or automated live plugin mutation was performed. Synthetic visual receipts are `docs/evidence/workspace/floating-tab.png` and `docs/evidence/plugins/card-switch.png`.

The corrected iPad detail/protected-plugin flow also passes in `/tmp/a0-card-detail-ipad-final.log`, verifying card-to-detail navigation and the existing scoped activation control after the row change.


### Attached A0 tab, Workspace tiles and panel-only plugins — September 30

The chat’s symmetric padding restores the centered empty-state branding. The transparent AgentZeroMark tab now sits flush against the right edge with rounded inner corners. Vertical dragging is bounded to the transcript viewport, uses global coordinates to avoid the moving view distorting the gesture, and preserves relative position in local display preferences. VoiceOver adjustment also moves the tab; opening the left drawer hides it without resetting its position.

Workspace replaces the duplicate rail/tab row with responsive tiles using registered surface icons or images. Panels occupy the full host width on both phone and tablet; Back to tools closes through the existing canvas lifecycle. Read-only inspection of the actual `a0-inst-curious-bohr-mue3503n` runtime found Swarm registered with `id: swarm`, `icon: group_work`, and no `modalPath`, with its own right-canvas panel extension. The old narrow-width modal route therefore returned false before presenting it. The native host now retains docked layout at every width, preserving original canOpen and surface-visibility restrictions. No live plugin/server files were changed.

The live canvas store differs from checkout `6a6cecff8527b164668c7a6ab2f76b6b1ed7cfa1` in rail dragging and preference-based visibility; those differences were inspected read-only. Automated UI verification uses that checkout’s real WebUI assets plus synthetic registrations, including a panel-only Swarm-style surface and a genuinely blocked canOpen surface. This proves the host compatibility path, not live Swarm execution.

202 package tests pass (`/tmp/a0-tiles-core.log`), as do six JavaScript fetch/frame-isolation tests. Settings save/reopen, main action, no-retry rejection and modal-to-panel handoff pass in `/tmp/a0-tiles-phone-ui.log`. That initial combined run exposed the drag-coordinate defect; the corrected complete Workspace flow passes on iPhone 14 Plus and iPad Pro 13-inch / iOS 26.5 (`/tmp/a0-tiles-phone-final.log`, `/tmp/a0-tiles-ipad-final.log`). These checks cover centered branding, edge attachment, dragging without opening, saved position across drawer presentation, tile navigation, original File Browser export/share, Browser/Desktop/Editor/custom-panel interaction, Desktop iframe input, panel-only Swarm interaction, true eligibility rejection and background clearing. Synthetic screenshots are under `docs/evidence/workspace/attached-a0-tab.png`, `workspace-tiles.png`, `ipad-workspace-tiles.png` and `panel-only-swarm-fixture.png`.

The final signed Release build and signature verification pass (`/tmp/a0-tiles-device-final-build.log`); both bundled JavaScript adapters match source. Installation and ordinary launch on the connected iPhone 15 / iOS 27.2 succeeded (`/tmp/a0-tiles-device-install.json`, `/tmp/a0-tiles-device-launch.json`). Version remains 0.1.0 (4). Actual owner-side Swarm use remains a separate acceptance check. No dependency installation, commit, push or TestFlight upload was performed.


### Native Selectable Theme matching — September 30

The native app now follows the connected server’s global Selectable Theme selection by default. Settings provides a local Match server theme switch, active-theme status and explicit refresh; Light/Dark/System stays independent. The native environment maps semantic colors across chat, message/activity cards, composer, drawer, Workspace tab, plugin lists/details, settings and supporting controls. It renders linear gradients natively, converts supported CSS color formats to sRGB in a credential-free network-disabled local document, and chooses contrasting ink for filled controls. Native navigation bars use the theme’s panel color. Built-in values are read from the installed plugin’s CSS rather than copied into the app; custom palettes come from read-only plugin configuration. No server scripts are executed by native theming.

Theme state is transient and connection-generation fenced. Disabling matching, backgrounding, disconnecting or switching profiles removes the active palette; missing/disabled plugins and invalid data fall back to neutral colors. Reads refresh on connection/foreground, every 30 active seconds, after embedded-screen dismissal or acknowledged native theme lifecycle changes, and through the refresh button. No plugin configuration is saved by this integration. The source reference was the installed Selectable Theme 2.0.0 in `a0-inst-curious-bohr-mue3503n`; all automated UI requests went to the disposable HTTPS fixture, never the owner’s live configuration.

208 package tests pass (`/tmp/a0-theme-core-final.log`), including six new theme parsing/transport tests for custom and built-in palettes, gradients/alpha, bounded data and huge-angle normalization, read-only authenticated acquisition, disabled short-circuiting, and redirect/interstitial rejection. Six existing WebUI protection tests also pass (`/tmp/a0-theme-web-checks.log`). The complete native theme UI flow passes on iPhone 14 Plus and iPad Pro 13-inch / iOS 26.5 (`/tmp/a0-theme-phone-final.log`, `/tmp/a0-theme-ipad-final.log`). It verifies actual screenshot pixel colors in both modes, opt-out, custom HSL/named colors and gradients, refresh after embedded dismissal/foreground, and disabled/missing/invalid fallback. The same iPad run passes plugin card switches, protected built-ins, Workspace entry and maximum-text Hub/detail checks. Initial UI runs needed corrected native switch targeting and foreground-readiness waits; those initial runs are not counted as passes.

The signed Release build and signature verification pass (`/tmp/a0-theme-device-contrast-build.log`). The final build was installed and launched normally on the paired iPhone 15 / iOS 27.2 (`/tmp/a0-theme-device-final-install.json`, `/tmp/a0-theme-device-final-launch.json`). Version remains 0.1.0 (4). This confirms direct device delivery; owner-side appearance against the live instance remains separate from synthetic acceptance. No dependency installation, commit, push, TestFlight upload or live theme mutation was performed.


### Theme coverage follow-up — September 30

The owner’s live screenshot confirmed partial theme application: plugin cards matched while collection/filter rows and the search chrome retained system gray. Plugin collection controls now use scoped native segment styling, contrasting selected text, themed row backgrounds/separators and a native themed search field. At accessibility sizes, choices stack vertically with complete labels instead of truncating. The compact Plugins title avoids the blank large-title region; missing artwork uses themed placeholder ink. Settings shares the segment styling, and project/model/generated-action forms and Tools use shared themed row containers. No global UIAppearance overrides or server changes were introduced.

Four focused iPhone UI checks passed in `/tmp/a0-theme-controls-phone.log`: theme pixel/search checks in both modes, a light-toolbar contrast floor of 4.5:1, card switch independence and maximum-text plugin navigation. Project create/edit/delete, shared model-preset editing and Queue/Steer persistence passed in `/tmp/a0-theme-forms-phone.log` (synthetic transport only). The final accessibility layout and both-mode Hub coverage passed on iPad Pro 13-inch / iOS 26.5 in `/tmp/a0-theme-controls-ipad.log`. Screenshots were reviewed directly; this follow-up does not claim every platform-owned sheet can adopt arbitrary server colors.

The final signed Release build passed in `/tmp/a0-theme-controls-device-final.log`; strict signature verification passed. Device installation and ordinary launch succeeded on the paired iPhone 15 in `/tmp/a0-theme-controls-install.json` and `/tmp/a0-theme-controls-launch.json`. Version remains 0.1.0 (4). Owner testing of the corrected build against the live theme is separate from fixture verification. No commit, push, TestFlight upload or live theme mutation was performed.


The final phone Hub/accessibility repeat passed in `/tmp/a0-theme-controls-phone-final.log`. A second owner screenshot identified the default sheet background below Settings, outside the themed Form. The shared navigation modifier now paints the presentation background and extends the theme beneath safe-area edges. `testSettingsSheetSafeAreaUsesTheme` passed on iPhone 14 Plus / iOS 26.5 in `/tmp/a0-theme-safe-area-phone.log`, checking actual bottom pixels after scrolling to Acknowledgments in both dark and light appearance. The resulting screenshots are `docs/evidence/themes/settings-bottom-dark.png` and `settings-bottom-light.png`.

The safe-area correction passed the signed Release build and strict signature check (`/tmp/a0-theme-safe-area-device-build.log`) and was installed and launched on the paired iPhone 15 (`/tmp/a0-theme-safe-area-install.json`, `/tmp/a0-theme-safe-area-launch.json`). The disposable HTTPS fixture was stopped and its temporary private key removed after testing.

### Optional Jev and expanded A2UI catalog — September 30

Added Metric, DataTable, Timeline and Checklist to the native catalog and producer guidance, available with ordinary rich replies and optional Jev candidate selection. Tables use responsive grids or stacked labeled cells for wide phone tables and accessibility text. Checklist controls retain local data binding; actions require review, Add to draft and explicit Send. A native scrolling hang exposed by the combined surface was corrected by keeping the delivery area and bottom anchor outside the lazy message stack.

Jev settings accept a masked per-profile TypeSafe key in a dedicated device-only Keychain service. Save/replace leave consent off. New opted-in sends advertise candidates; a minimized direct TypeSafe choice request follows local validation and a durable one-attempt record. Replies preserve prose on failure, and candidate eligibility uses only the reachable visible graph. Profile/context/epoch/source changes and backgrounding cancel pending selection. No server code was changed.

252 Swift package tests pass (44 generated-UI plus 208 core). New Jev/expanded DTO files have 97.27% line coverage; owned source in the two package test binaries has 91.52%. Five distinct iPhone and seven distinct iPad native checks pass across the documented runs, including secure settings, end-to-end choice/checklist draft review, unavailable-choice fallback, maximum text with a synthetic server palette, previous generated components and history following. Simulators: iPhone 14 Plus and iPad Pro 13-inch, iOS 26.5, dark/light appearance respectively. Sources, executed commands, initial failures and final outcomes are in `docs/tdd/jev/README.md`; selected images are in `docs/evidence/jev/`.

These are synthetic HTTP/chooser and simulator results. No real TypeSafe call, owner-key access, real server generation, physical-device installation or release is claimed. Build/version and dependencies remain unchanged. Review the optional external data flow against privacy disclosures before a future distribution.

### Expanded charts and native media — September 30

The native A2UI catalog now supports 14 chart kinds plus AudioPlayer/Video. Producer guidance and Jev eligibility are synchronized, prior capability suffixes still collapse correctly, and SDK media types are remapped to the trusted player before rendering. Media loads only on request through bounded credential-free public HTTPS downloads; native playback uses local files, no autoplay, precise seeking and reply/background cleanup. Server code, version and dependency pins are unchanged.

265 package tests pass. All chart-style cases, dense data, large text, server colors, native media seek/play/background, cancellation, invalid media and existing rich-reply/history behavior passed in the focused iPhone 14 Plus and iPad Pro 13-inch / iOS 26.5 runs. The final iPad batch passed all three selected tests; final heatmap/donut visual checks passed on iPhone. The TDD record distinguishes earlier mixed-run failures from the individually passing final cases. New package chart/media files measured 91.89% line coverage and native media 84.15% in a separate playback run. See `docs/tdd/charts-media/README.md` and `docs/evidence/charts-media/`.

Fixtures used local silent WAV and generated video, synthetic HTTP and fictional chart values. Live media hosts, caption tracks, hardware audio behavior, real server/Jev generation and distribution are not claimed.

Device handoff: source `1fd0b93` passed the signed Release build and strict signature verification. Direct installation and ordinary launch succeeded on the paired physical iPhone 15 / iOS 27.2, using the existing app identity and version 0.1.0 (5), with no fixture launch arguments. This confirms delivery only; live charts, media playback and optional Jev generation still require owner acceptance. No TestFlight upload or distribution was performed. Task-owned device DerivedData was removed after the successful handoff.

### Jev discovery and combined composer — September 30

Settings now names **Jev API key & rich replies**, with a TypeSafe setup subtitle. The trailing composer control shows Stop for empty drafts with running, paused or queued work. Text or attachments restore Send with an adjoining Stop menu, preserving unsent content and existing Queue/Steer routing. Idle empty chats show disabled Send; in-flight cancellation blocks submission.

265 package tests and seven distinct synthetic UI journeys on both iPhone 14 Plus and iPad Pro 13-inch / iOS 26.5 passed across the recorded runs. Checks cover secure key setup, queue/steer persistence, attachment-only follow-ups, primary Stop, draft preservation, uncertain cancellation and maximum text. TDD checkpoints, exact test selection, coverage and limitations are in `docs/tdd/composer-jev/README.md`; selected synthetic images are under `docs/evidence/composer-jev/`.

Signed Release build, strict signature verification, direct installation and ordinary launch succeeded on the physical iPhone 15 / iOS 27.2, version 0.1.0 (5). This is device delivery evidence; live server and owner credential acceptance remain separate. No server code, dependency pins or version changed; no TestFlight upload. Temporary build and test artifacts were cleaned.

### Agents theme, direct media and related chats — September 30

Agents now carries the selected theme through navigation chrome and safe areas. Ordinary assistant direct-file audio/video links retain prose and expose native explicit Load controls; explicit A2UI/Jev payloads retain precedence. Read-only Agents permits passive playback while draft-producing controls remain disabled. Source/context/log-epoch changes release previous players.

Verified visible subordinate relations produce a compact Subagents control, New badges, related chat cards and parent return. Navigation preserves per-chat drafts and staged attachments; new arrivals do not change selection. Newness survives same-session background refresh and resets with authenticated-session replacement. False/missing running never implies completion. No server modifications or additional provider requests were introduced.

286 package tests passed (219 core, 67 generated UI). The final iPhone 14 Plus / iOS 26.5 dark run passed 10 native journeys: seven new theme/media/subagent flows plus playback-background cleanup, Queue/Steer persistence and Stop/draft regressions. All seven new flows also passed on iPad Pro 13-inch (M5) / iOS 26.5 light. Independent code review approved the corrected lifecycle handling; security review found no confirmed new blockers. Exact test-first failures, fixture corrections and final outcomes are in [the verification record](tdd/agents-media-theme/README.md); selected synthetic screenshots are in `docs/evidence/agents-media-theme/`.

The uncommitted working tree based on `555d30a` passed a signed Release build and strict signature verification. Direct installation and ordinary launch succeeded on the paired physical iPhone 15 / iOS 27.2 using `com.terminallylazy.a0-ios`, version 0.1.0 (5), without fixture arguments. This proves delivery; real server generation, live-host media playback and owner acceptance remain separate. No TestFlight upload, commit or push occurred; Gate 2 is pending. Task-owned temporary build and test artifacts were removed after retaining concise evidence.

### Inline media presentation amendment — September 30

At the user's request, audio/video now plays inline in the reply with compact controls, a bounded video frame and explicit Unload. The composer remains accessible. Native audio ownership coordinates media, dictation and read-aloud; switching activity stops the prior owner without losing drafts or automatically resuming it. Existing downloads and source/background cleanup remain unchanged.

Eleven distinct phone UI cases passed across the two inline runs, including a final six-case run covering shared audio ownership and existing voice behavior. Four final iPad cases passed. Review approved the correction. See [inline TDD evidence](tdd/agents-media-theme/inline.md) for exact runs, RED outcomes, the large-text test-harness correction and limitations. Signed Release build, strict signature verification, direct installation and ordinary launch succeeded on the physical iPhone 15 / iOS 27.2 with version 0.1.0 (5). This is delivery evidence; live audio/microphone acceptance remains separate. Changes remain uncommitted, with no TestFlight upload. Temporary artifacts were cleaned after retaining concise evidence.

## Host connector foundation — October 1, 2026

The approved plan adds the native Computer sheet, optional `host_tasks_v1`
discovery, explicit text-only host drafts, and authenticated browser/computer
capture labels. Core owns durable session/context-bound routing; Launcher owns
permissions. See [HOST-COMPUTER.md](HOST-COMPUTER.md).

Verification on the final source:

- 228 A0Core tests and 67 generative UI tests passed. Simulator build passed.
- The focused Computer sheet UI test passed on the iPhone transport simulator
  and iPad Air 11-inch (M4), covering per-capability gating, explicit draft
  preparation and foreground draft preservation.
- 85 focused backend checks passed against isolated local Core `6a6cecff`.
  99 passed against a staged copy of live Core `e3051fb5`. The live framework
  lacked pytest-asyncio; a temporary pytest hook executed its 11 existing async
  test bodies with `asyncio.run`. No dependency was installed or test skipped.
- Dynamic API-loader regressions verify the real authenticated/CSRF handler is
  selected. Live requests without authentication returned 302; authenticated
  requests without CSRF returned 403 for both new endpoints.
- The development-signed Release app, version 0.1.0 (6), was installed and
  launched on the paired iPhone 15. This is not a TestFlight upload or proof of
  physical phone-to-host execution.

Live target: `a0-inst-curious-bohr-mue3503n`, host port 49805, this Mac,
Launcher 1.8.0 and installed `a0` 2.13. Eleven owning plugin files were adapted to
that newer runtime rather than overwriting it with the older checkout. Originals
and a manifest are in `/a0/usr/backups/ios-host-connector-20261001/`. Only the
WebUI process was restarted. The user explicitly requested leaving all Launcher
scopes enabled; file and code scopes were not exercised by the acceptance tasks.

The isolated `iOS Host Acceptance` project uses `host_required` with an A0
controlled browser profile; shared/global browser configuration was preserved.
The browser task read Example Domain and returned a chat-scoped capture. The
browser reused its existing acceptance tab, so creation of a new tab is not
claimed. Initial live checks exposed benign inventory and computer-session status
transitions invalidating a target; regressions now distinguish these from actual
connection, selected-browser, scope and trust-mode changes.

Computer Use completed Calculator `2 + 3 = 5` through the host connector.
Independent native accessibility inspection confirmed the expression and display.
The installed Mac backend initially selected a sharing overlay with PID-only
window lookup; app-scoped AX actions revealed the actual main-window path, after
which explicit window targeting and background button dispatch completed the
calculation. The connector's formatted window state omitted the display value,
so Agent Zero itself reported the result as unverified; the independent native
read confirmed `5`. The computer-use session then stopped successfully.
This is a real Mac result initiated by the protected API test harness, not by the
physical phone.

Both browser and computer capture metadata were verified against the exact chat;
authenticated `image_get` returned 200 JPEG and PNG respectively. Computer Use
currently takes a full-desktop capture when a session starts; a Calculator-only
capture is not claimed. The client hides server-redacted host labels while
retaining source and capture time.

Physical phone-to-host browser acceptance passed on the installed iPhone 15 app
over the existing authenticated HTTPS Dev Tunnels connection. The owner signed
in; subsequent recovery used the phone's already-saved Keychain credential.
Through iPhone Mirroring, `PHONE-HOST-FINAL` was composed, explicitly targeted to
the Mac and sent once. The host browser opened Example Domain, read content and
returned captures visibly rendered on the phone. The final response arrived and
the server task stopped. The text extraction and screenshot observed different
page languages; this verifies the transport/capture path, not translation parity.

Earlier phone attempts exposed two over-broad generation inputs: chat-only socket
reconnections and the browser content-helper checksum populated at startup. Both
regressions failed before their fixes and pass now. Generations exclude these
observations while retaining competing execution-client, reconnect, scope,
selected-browser, configuration and trust checks. The final live attempt began
with an uninitialized browser helper and retained its binding after initialization.
No failed or uncertain message was automatically replayed.

The final receipt is in the live backup as `physical-phone-acceptance.json`.
Computer Use remains independently verified on the Mac through the protected API
harness; this phone-originated test exercised Browser. All five host permissions
remain enabled. Temporary diagnostic instrumentation and its endpoint were removed.
The existing tunnel runs separately from the WebUI process; its direct tunnel
status endpoint alone does not establish external reachability. Source remains
uncommitted, with no TestFlight upload. Core updates/container replacement can
overwrite this manual runtime patch.

## Live host viewer and takeover — 2026-10-01

Development build 0.1.0 (6) was built, signed and installed on the paired iPhone 15.
The target was the existing curious-bohr Core v2.13/e3051fb5 runtime, Launcher 1.8
and installed connector 2.13 on this Mac. New protocol code was adapted to that
runtime while preserving its newer code. The source connector checkout remains
2.8/e6302fd5. No TestFlight distribution, commit or push is included.

Physical acceptance used the saved authenticated HTTPS Dev Tunnels profile and
chat K3q4vcFy in the isolated iOS Host Acceptance project. iPhone Mirroring drove
the actual installed app. Browser and Computer use the same single viewer:

- Browser: Take over acknowledged exclusive control and expanded the pane. A
  phone tap focused the existing Mac page input; the modifier control selected
  its text, native text entry sent `PHONE`, and a phone tap applied it. Both input
  and output became `PHONE`. A waiting agent task emitted no tool work while
  human control was held. Return supplied fresh state; A0 read both values and
  emitted one final response.
- Computer: the existing backend captured the primary 1920x1080 display.
  Calculator initially occupied another display, so native UI moved it to the
  captured display and cleared it to 0. Phone taps through the capture performed
  `7 + 5 = 12`; independent Mac accessibility confirmed expression and result.
  A waiting read-only task remained held when the phone was backgrounded.
  Foreground recovery showed `Control expired · A0 held`; explicit Return
  resumed it. A0 freshly captured Calculator and reported `7+5` and `12` once.
- The phone's capture details reported 101 received frames, 0.79 frames/s,
  62.4 KB/s of JPEG payload, last frame received 0.2 seconds earlier, and the
  last Calculator input acknowledged in 0.20 seconds. These are one viewing
  period's observed values, not guaranteed frame rate or total network bandwidth.
- The final installed build centers Take over and Return to A0 as tabs attached
  to the capture pane, matching the Workspace tab treatment. Both states were
  visually verified on iPhone 15, followed by an acknowledged Return to A0.
- The subsequent theme correction was signed and installed on the same phone.
  Browser and Computer panes now use the active native palette, including
  expanded backgrounds, source selection, controls and WebKit letterboxing.
  Both viewer UI tests pass; screenshot pixel assertions cover light/dark
  canvas, panel and expanded safe areas. Physical inspection confirmed
  the current theme in compact Browser and expanded Browser/Computer views.
  Evidence: `phone-themed-browser.png` and `phone-themed-expanded.png`.
- The Computer status sheet now uses the shared themed Form, with header, row
  and background palette checks in both appearances. Attached tabs have a
  subtle accent fill, border and glow. The viewer footer is one status row;
  keyboard controls open explicitly and history/inspect/details share a menu.
  The fallback capture no longer repeats metadata or forces a 480-point image.
  Two viewer UI tests pass, including keyboard visibility, handback, rotation
  and both theme palettes. Screenshots are `simulator-refined-viewer-dark.png`,
  `simulator-refined-viewer-light.png` and `phone-themed-computer-sheet.png`.
  A live HTTP 502 during phone use left an unresolved heartbeat receipt and
  an existing host hold. The updated UI preserves that review requirement;
  the layout update does not clear the receipt or automatically resume A0.
  The final signed build was installed and visually checked on iPhone 15 in
  compact and expanded modes, including the retained review card. Evidence:
  `phone-refined-compact.png` and `phone-refined-expanded.png`.

Live checks found and fixed a routine-cookie-refresh acknowledgement race, a
historical screenshot hit area overlapping the source selector, and pending
heartbeat receipts moving the capture layout. Unknown outcomes still require
explicit review without replay. A frame identity follows the actually displayed
image; the connector retains at most three recent identities for five seconds
and checks current target/geometry before input. Return waits for an in-flight
capture before taking the final observation.

Verification:

- Swift core: 233 tests pass, including same-account cookie refresh versus actual
  disconnect while awaiting a viewer acknowledgement.
- iPhone/iPad simulator takeover, source switching, expansion and handback pass;
  one identified WKWebView remains visible. iPhone landscape/portrait rotation
  passed the same single-surface and Return checks. Historical capture preview
  regression also passes.
- Core framework: 107 focused tests passed against the adapted live source;
  no protected agent.py/initialize.py edits were needed.
- Connector: 12 focused ownership/input tests pass. Full disposable Linux suite:
  585 passed, 55 failed, 2 skipped. The 55 failures match the unchanged baseline
  exactly (573 passed, 55 failed, 2 skipped), in legacy plugin-backend fixtures.
  The full suite is therefore not green. No production dependencies were installed.

Limits: JPEG live capture rather than video; computer capture is the primary
whole display, with no window/display picker or computer drag. Phone remote
keyboard is supplied by the text/key controls. Hardware keyboard, all zoom/drag/
scroll combinations, physical rotation and every network/OS-permission failure
combination are not certified by this acceptance. Deterministic tests cover the
core fence, stale epochs, competing ownership, expired/restarted holds, geometry
rejection and non-replay; they are not all physical fault-injection results.

Evidence is in the task's local `live-viewer` visualization folder, including
`phone-browser-control.png`, `calculator-phone-result.png` and
`phone-capture-metrics.png`; `phone-attached-takeover-tab.png` and
`phone-attached-return-tab.png` show the final control styling.
Runtime originals and patch manifests remain under
`usr/backups/ios-live-viewer-20261001` in curious-bohr and the Mac connector backup.
All five Launcher scopes remain enabled as requested. Updating/replacing Core or
the installed connector can overwrite these local runtime patches.

### Viewer corner and inset refinement — 2026-10-01

The compact viewer now uses continuous 24-point outer corners with 12-point
insets and continuous 12-point capture/review corners. The capture owns a single
clip and border; historical fallback images no longer draw another rounded edge.
The review card has a bottom inset clear of the outer curve.

The development-signed Release build succeeded and was installed on the paired
iPhone 15. Physical inspection against curious-bohr through the existing HTTPS
profile confirmed compact and expanded historical Browser capture with the
existing uncertain receipt still present. This check did not clear that receipt,
resume A0, or establish a new host-input acceptance result. Evidence:
`phone-corners-compact.png` and `phone-corners-expanded.png` in the task's
`live-viewer` visualization folder.

Both existing `LiveViewerUITests` passed (2 tests, 0 failures), including fixture
takeover/handback and light/dark Computer-sheet and viewer palette checks. The
letterboxing pixel sample is now away from the newly rounded capture corner.
Result bundle: `/tmp/a0-live-derived/Logs/Test/Test-AgentZeroSpike-2026.10.01_06-07-58--0400.xcresult`.
