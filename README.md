# a0-iOS — Agent Zero for iPhone and iPad

Native iPhone/iPad foundation for the approved plan in [docs/PLAN.md](docs/PLAN.md).

The foundation includes session/CSRF authentication, Socket.IO state with foreground polling fallback, and a diagnostic probe. The first Milestone 1 slice adds chat creation, text sending, busy-chat queue routing, per-chat drafts, protected actor-backed storage, and explicit delivery states. Uncertain mutations are never automatically replayed. Server acceptance does not mean agent execution completed.

## Repository and TestFlight

The app bundle is `com.terminallylazy.a0-ios`; display name **Agent Zero**. Release preparation, local signing setup and beta test notes are in [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md). Source, fixtures and authored reports are versioned; build products, raw XCTest bundles, recordings and local logs remain excluded. Historical report links to those artifacts refer to the originating development Mac.

## Run

Open `AgentZeroSpike.xcodeproj`, select the `AgentZeroSpike` scheme, and run on an iOS 17+ simulator. Xcode 27 / Swift 6.4 were used for verification. The included project is generated from `project.yml` with XcodeGen; ordinary Xcode use does not require regenerating it.

For HTTPS servers, enter the origin and credentials directly in the app, then tap **Connect securely** in the bottom action area. The button stays above the keyboard; the password keyboard also offers Go. Drafts, the selected chat, and unresolved delivery receipts are now saved on this device, isolated by origin and username. A valid saved session restores the same server/account after relaunch and opens the new-chat draft with the sidebar closed; older chat drafts and unresolved receipts remain available. Expired authentication requires sign-in. Interrupted sends restore as uncertain and never auto-replay. Saved servers restore connection details without connecting automatically. Password saving is off by default; opt in to save a verified password in device-local, when-unlocked Keychain storage. The active session cookie is saved separately in device-only, when-unlocked Keychain storage. Backgrounding pauses transport while retaining the chat; foreground return refreshes current state before sending. See [session continuity](docs/SESSION-RESTORATION.md).

Use the QR toolbar button to scan your server’s tunnel QR or enter its HTTPS address, review the destination, then fill the sign-in form. QR import does not connect, look up passwords, or save a profile. Camera permission is requested only when you tap Open camera. Denied or unavailable cameras retain manual address entry.

For the user-designated development server, enter `http://localhost:49805` in the simulator and enable **Local development (loopback only)**. This option is compiled only in Debug. Localhost on a physical iPhone refers to that phone, so this address is not a physical-device connection path. Release origin validation always requires HTTPS.

The app can show **Explore synthetic preview** without any connection, including synthetic creation and sending. The preview is labeled and is not runtime acceptance. `--synthetic-http-preview` is a Debug-only UI-test fixture that exercises the HTTP client without network traffic.

```sh
swift test
swift run a0-transport-probe http://localhost:49805
swift build -c release
```

The Debug probe prints only status and counts. It verifies CSRF bootstrap, HTTP snapshot decoding, `/ws` acknowledgement, and an applied full state push; it never prints cookies, tokens, or conversation bodies. It supports loopback targets only and is disabled in Release builds. A probe request uses UTC for snapshot timezone, matching the browser API's existing localization behavior; it is a state request, not a stateless health request.

## Dependencies

User-approved `socket.io-client-swift` **16.1.1**, with resolved `Starscream` **4.0.8**. Preserve `Package.resolved` and the Xcode workspace resolution file. Socket.IO uses MIT licensing; Starscream uses Apache 2.0. Full bundled notices are in [App/ThirdPartyNotices.txt](App/ThirdPartyNotices.txt).

Realtime currently uses Socket.IO over WebSocket with independent foreground `/api/poll` fallback. Engine.IO long-polling upgrade is intentionally not enabled in the spike. Healthy polling now checks realtime again after 30 seconds, then at 60/120-second intervals (120-second cap). It refreshes the existing session without submitting credentials, and keeps polling authoritative until a valid handshake and full current state arrive. A missing full socket state times out after 20 seconds. Owner-assisted camera scanning and destination import have been observed on an iPhone 15; see the device report for separate sign-in and remaining acceptance gates. Saved-password lookup happens only when you select a saved server, followed by explicit Connect. The HTTP client never automatically follows redirects or retries mutations. Foreground polling retries selected transient network/HTTP failures four times with bounded backoff. Drafts stay editable, Send pauses until full state returns, and Retry sync becomes available after exhaustion. Authentication and certificate errors require attention rather than automatic login.

## Source boundaries

- `Sources/A0Core`: DTOs, isolated authentication/cookies, HTTP transport, pure reducer, draft/delivery state machine, protected actor-backed session/profile repositories and credential interfaces.
- `Sources/A0Realtime`: pinned Socket.IO integration, ack validation, bounded handshake buffering.
- `Sources/A0TransportProbe`: Debug-only loopback interoperability receipt.
- `App`: native connection, saved-server and Keychain controls, chat composer, and synthetic preview.
- `Tests/A0CoreTests`: authored synthetic protocol, storage, recovery, project, context-accounting and speech-permission regressions.
- `Tests/A0GenerativeUITests`: generated-content, SDK lifecycle, action and image-transport regressions.
- `Tests/A0UITests`: authored native UI flows covering chat/recovery, saved profiles, Keychain, background password clearing, QR onboarding, transient connection recovery, retry exhaustion, expired sessions, and staged realtime recovery.
- `Tests/DeviceAcceptanceTests`: separate opt-in, owner-assisted camera/sign-in checks; select a specific test in the `AgentZeroDeviceAcceptance` scheme.
- `scripts/async_pytest.py`: bounded coroutine runner for existing backend tests in an isolated framework container; not a replacement for a project's full async test tooling.

[Acceptance and known limits](docs/ACCEPTANCE.md) distinguish source tests, live loopback interoperability, simulator verification, and remaining security, network-recovery, and physical-device gates.

[TDD evidence for the chat slice](docs/tdd/chat-slice.tdd.md) records failing tests, passing verification, and measured coverage. No live agent task was submitted during this work.

[Persistence and recovery evidence](docs/tdd/persistence/persistence-slice.tdd.md) records the next TDD slice. Files use atomic writes and iOS complete file protection and are excluded from backup. The composer saves drafts silently during normal use; Draft options exposes storage status to accessibility, and failures remain visible with retry. Its Draft options menu clears the current draft after confirmation; unresolved delivery records are retained to prevent duplicate sends. Disconnecting retains local drafts. Synthetic preview remains memory-only. No transcript history, passwords, cookies, or CSRF tokens are stored in these archives. Optional passwords live exclusively in Keychain.

Saved-server controls distinguish retention: **Disconnect** clears the active session and password field but keeps server details, opted-in Keychain credentials, and drafts. **Forget saved password** removes the credential and clears its field. **Remove saved server** removes the connection entry and its credential after confirmation, retaining local drafts and delivery records. Enter the same origin/username again to recover retained drafts. Keychain failures are visible and never fall back to plaintext storage.

[Server profiles and Keychain evidence](docs/tdd/profiles/profiles-slice.tdd.md) records tests and remaining device acceptance gates.

[QR onboarding evidence](docs/tdd/qr/qr-slice.tdd.md) records URL validation and native review flows. QR payloads must be a plain HTTPS origin (up to 2,048 UTF-8 bytes), with ASCII/punycode hosts; credentials, paths, queries, fragments, escapes, and non-HTTPS links are rejected. The Debug loopback exception remains available only through manual connection settings.

[Foreground recovery evidence](docs/tdd/recovery/recovery-slice.tdd.md) records retry limits, cancellation, full-state recovery, and remaining live-network/device acceptance. This slice recovers HTTP polling while foregrounded. Foreground continuity and saved-cookie relaunch restoration are documented separately in [session restoration](docs/SESSION-RESTORATION.md); neither replays login or pending mutations.

[Realtime recovery evidence](docs/tdd/promotion/promotion-slice.tdd.md) records session refresh, staged handoff, stale-state rejection, cancellation, and simulator validation. Live network recovery remains pending; authenticated HTTPS and applied Socket.IO state were subsequently observed on the physical iPhone, with the manual harness limitation recorded below.

[Physical-device and Connect action evidence](docs/tdd/device/device-slice.md) records development installation on iPhone 15 / iOS 18.7.3, six distinct synthetic hardware flows across runs, observed camera import and authenticated HTTPS/Socket.IO state, the connection-button correction, and remaining acceptance limits. The latest focused simulator run passes three flows; it is not a new full-suite run.

The two physical keyboard/Keychain regressions now pass on iPhone 15 / iOS 18.7.3 and on the iOS 27 simulator after the test harness learned to scroll fields above the fixed action bar. Production connection behavior is unchanged by this follow-up; the corrected owner-assisted live test also passes with authenticated HTTPS and full Socket.IO state. See the device report for retained earlier failures and remaining security/recovery gates.

Tap an existing chat to open its conversation screen. Back returns to the chat list while preserving its draft; changing chats displays that chat's own messages and draft. [Conversation navigation evidence](docs/tdd/conversation/conversation-fix.md) records the reproduced missing-navigation bug and simulator/physical-device correction.


The chat interface now uses Agent Zero's original wordmark, mark and app icon. New chat opens a dedicated composer and remains open after sending. Replies render headings, emphasis, lists, quotes, fenced code and basic tables; long messages and routine tool activity collapse. Scrolling into history or expanding content pauses automatic following; **Latest** resumes it. Message/code copying and activity details are available. This is a native Markdown subset, not full CommonMark/GFM or full WebUI parity.

[Chat UI evidence](docs/tdd/chat-ui/chat-ui.tdd.md) records regression coverage, physical-device checks, visual review and limitations. [Goose reference decisions](docs/GOOSE-REFERENCES.md) maps the user-supplied examples to implemented behavior and later navigation/voice work.


Use the gear on the chat list, or **Conversation options → Settings**, for appearance, long-message collapse, activity grouping and connection information. **Change server** returns to the existing saved-server/sign-in flow after confirmation; drafts are retained. These are local companion preferences, not Agent Zero model/server configuration. While editing, the keyboard-with-down-chevron button beside Draft options minimizes the keyboard without sending or deleting text.

Tool activity uses native SF Symbols and structured summaries. Agent Zero `icon://` heading markers become icons rather than visible URI text; incomplete/structured event JSON stays behind Raw event. [Interface refinement evidence](docs/tdd/interface-polish/interface-polish.tdd.md) records the requested fixes and synthetic device verification.


Native generated replies now use the pinned A2UI-Swift SDK. With **Settings → Rich replies** enabled (default), an ordinary forecast, image-search, chart or dashboard request can return native visual content. Forms can return reviewed choices through the existing draft/Send flow. See [supported catalog, setup and limits](docs/GENERATIVE-UI.md). The renderer is verified with synthetic payloads; a live model must still emit the documented format.

Session continuity now preserves the chat and generated replies on background/foreground and restores a valid device-only Keychain session after relaunch. The composer includes a compact Latest control, a tools menu and direct on-device dictation into Message; the Workspace drawer and Agents inspector make chats and attributed activity easier to reach. See [session restoration](docs/SESSION-RESTORATION.md), [voice](docs/VOICE.md), and [workspace verification](docs/tdd/workspace/workspace.tdd.md). Native controls cover Pause/Resume, Nudge, History and Context in a compact tools popover; native attachments stage photos/files locally until Send; the full WebUI remains available for broader administration.

**Projects** is available from the chat list, Workspace drawer and conversation project label. Browse and filter by project, create or clone a repository, edit project settings, assign/remove the current chat, start a project chat, or delete with a typed folder-name confirmation. File management, knowledge, memory, skills and project-scoped preset selection use a confirmed WebUI handoff. Shared model preset definitions and current-chat overrides are now native. See [project ownership and limits](docs/PROJECTS.md).

The composer’s context ring opens a compact breakdown of server-reported prompt tokens and model-window usage. Categories, free space and separately reported provider input/output/cache counts appear only when available; this is not an estimate from visible messages.

The composer’s **Model presets** control shows the effective Main, Utility, Embedding and applicable Vision models. Select a preset for the current chat or return to its inherited choice. **Edit presets** manages shared definitions across the server, with explicit Save/reset and a stale-editor baseline check. Provider keys/OAuth and project-scoped default selection remain in WebUI. See [model preset ownership and limits](docs/MODEL_PRESETS.md).

The branded launch cover lasts only while profiles and session restoration load. A successful cold launch opens the new-chat draft; ordinary background/foreground retains the current chat. The leading sidebar button opens a bounded drawer with search, Projects, conversations and Settings; close, backdrop, escape and a left swipe on its header dismiss it. Opening the drawer dismisses the keyboard and preserves drafts.

The captured Speech permission crash was an executor assertion in Apple’s background authorization callback. The nonisolated, Sendable permission bridge corrects that path; [crash evidence](docs/tdd/voice/permission-crash.md) records the repair. The owner subsequently confirmed dictation worked on the physical iPhone. That confirmation applies to the prior voice interaction; the new inline-composer flow and continuous-listening behavior need separate acceptance.

Tap the composer microphone to dictate into the existing message; Stop voice ends capture and Send stays explicit. Voice options remembers Continuous listening across launches without starting it automatically, and offers Read reply and supported on-device draft polishing. Ordinary saved-state text is removed from the composer; failed storage still shows a clear warning and Retry saving. The context meter now scales and stacks its breakdown at accessibility text sizes while keeping numeric groups intact.

Browser tool captures now appear as native thumbnail cards with contained previews. A compact composer status dot explains connection state on tap. See [chat media and attachments](docs/CHAT-MEDIA.md).
