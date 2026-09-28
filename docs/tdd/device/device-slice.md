# Physical iPhone acceptance — September 28, 2026

Scope: install the development build on the owner's available device, run synthetic hardware regressions, and perform owner-assisted QR import and authenticated HTTPS state synchronization. After the owner reported that Connect was missing, the sign-in action moved from the scrolling form into a persistent bottom action area. It remains above the keyboard, and the password keyboard also offers Go. Authentication requirements are unchanged. No agent message/task was submitted and no server code, dependency, signing identity, App Store record, or TestFlight release was created. Existing authorized development signing was used; Xcode generated the necessary development provisioning for the app/test runners.

## Device and build

- iPhone 15 (`iPhone15,4`), iOS 18.7.3, Developer Mode enabled, paired over the local network. Device reported unlocked with no passcode currently required.
- App: `local.agentzero.AgentZeroSpike`, version 0.1.0 (1), minimum iOS 17.0.
- Development build-for-testing and strict signature verification passed. Xcode 27 / Swift 6.4, development team REDACTED_TEAM_ID, existing Apple Development identity.
- Evidence: `device-summary.json`, `build-for-testing.log`, and named result bundles below. Full device inventory was reduced to a sanitized summary.

## Hardware regressions

| Flow | Result | Evidence |
| --- | --- | --- |
| Saved draft survives termination, clears, and stays cleared | PASS after correcting the empty-value assertion | `iphone-corrected.xcresult` |
| Interrupted/uncertain send survives termination without replay | PASS | `iphone-acceptance.xcresult` |
| Opted-in Keychain credential survives relaunch and requires explicit Connect | PASS | `iphone-acceptance.xcresult` |
| QR destination review clears old form credentials without connecting | PASS after correcting empty-value assertions | `iphone-corrected.xcresult` |
| Polling-to-realtime handoff preserves an editable unsent draft | PASS | `iphone-acceptance.xcresult` |
| Verified background transition cancels the candidate and rejects late pushes | PASS | `iphone-background.xcresult` |

Initial run: three of six passed. On iOS 18, empty text fields return nil instead of the placeholder string. Assertions now require the field to exist and accept nil/empty/placeholder values while rejecting retained text. The first correction run passed both field flows.

The injected Home-button command did not put this physical app into background, confirmed by an explicit app-state wait. The test now activates Settings without changing any setting, waits for either background or background-suspended state, and returns to the app. That verified transition passes with the existing lifecycle implementation. These changes correct test assumptions; no application behavior was weakened to pass them. Six distinct hardware flows are verified across the initial/corrected/background runs, rather than a single all-green run.

## Live acceptance

Owner-provided origin: `https://your-agent-zero.example`.

Host preflight verified normal platform TLS, a 200 health response, and—after the owner enabled server login—a protected CSRF bootstrap redirecting to same-origin `/login`. Only a boolean authentication setting was read from the designated running container; no username/password was read or printed. `server-revision.json` records its base commit and whether tracked modifications exist; a base commit alone is not a clean runtime-source receipt.

The separate `AgentZeroDeviceAcceptance` scheme runs only when explicitly requested. Its owner-assisted test receives the origin via `TEST_RUNNER_A0_DEVICE_LIVE_ORIGIN`, opens the real camera, checks the reviewed destination, and waits for the owner to enter credentials on the phone. It never reads credentials or submits a chat command. The regular synthetic test scheme does not include this interactive target.

The first owner-assisted run successfully opened the physical camera, scanned the server QR, verified its destination, and applied the origin. It then timed out waiting for Live while the app remained Not connected. The owner reported no visible Connect button. This proves camera/import behavior, not authenticated synchronization. The sign-in-only retry with the corrected bottom action observed **Live** on the physical iPhone. In this app, Live is published only after an applied Socket.IO state push; the non-fixture path first completes authenticated HTTP bootstrap and snapshot synchronization. The test subsequently failed its `Disconnect` accessibility-element assertion. That button lives after the chat list, so its presence is not a reliable visible-state assertion for a populated live server. No screenshot/transcript is needed to establish the reached Live guard.

`iphone-live-retry.xcresult` remains a **failed test result**, despite the successful connection observation. Its old harness printed the success marker after a nonfatal assertion; that marker alone must not be treated as a green test. Both manual tests now require the visible “Socket.IO state is current.” confirmation with a fail-closed guard before printing success. The corrected harness is build-checked, not owner-rerun. No additional sign-in was forced merely to replace the result bundle.

## Connect action — TDD correction

The focused placement regression failed against the original form: Connect ended 195.333 points above the app bottom instead of occupying the bottom action area (`connect-position-red.xcresult`). The earlier `connect-red.xcresult` failed only at connection and is not the placement RED evidence.

`ConnectionActionBar` now owns the full-width native primary button in the root bottom safe-area inset. `SpikeModel.canConnect` shares the existing credentials/busy gating between this button and the password field's Go action. The action bar uses semantic colors/materials and native control sizing.

Three focused iPhone simulator tests pass in `connect-simulator.xcresult`: bottom placement/keyboard reachability and synthetic connection, opted-in Keychain relaunch with explicit Connect, and QR confirmation with credential clearing. Measured coverage: ConnectionActionBar 26/26 executable lines (100%); ServerConnectionSection 146/158 (92.4%); root app source 379/438 (86.5%). This is focused coverage, not a fresh full-suite run.

The physical `connect-green.xcresult` confirmed the new placement and passed QR confirmation, but the automated connection did not reach Polling and the saved-profile test failed keyboard focus. Those failures remain recorded; simulator success does not erase them. The updated physical layout was visually inspected. The six hardware flows above passed before this UI correction, across separate runs.

Unsigned Release simulator build passed (`connect-release-build.log`). Development Debug builds for the physical device and simulator also passed. No core protocol code changed in this correction; the earlier 88-test core result is prior-slice evidence.

## Limits and diagnostics

- Synthetic hardware tests exercise real iOS storage/Keychain/UI with synthetic network/callback inputs. They are not actual server-outage or reconnection evidence.
- Locked-device Keychain/file protection, cellular transitions, server restart, expired tunnel, sustained-stream performance, and distribution remain separate gates.
- Build warnings: all-orientations support, a Release linker ambiguous-target-atom warning, and skipped AppIntents metadata extraction (the app has no AppIntents dependency). No warning-free build is claimed.
- Owner-assisted live-test logs/result artifacts may contain private UI metadata; keep them local and share only sanitized summaries. No live transcript or credential screenshot is intentionally captured.


## Follow-up: physical keyboard targeting

The two physical synthetic checks were repeated in `connect-device-recheck.xcresult`; both failed at Username focus. The captured accessibility geometry explains the failure: Username occupied y=480.7–524.7 while the keyboard action bar occupied y=495–549, so XCTest's center tap hit the action area. The test was targeting a field covered by the fixed bottom control.

The shared test helper now scrolls inside the visible form before tapping any connection field extending under the action bar. It does not change application layout, inject model state, enter real credentials, or retry a connection. Both physical tests pass in `connect-device-scroll.xcresult`: reachable Connect above the keyboard and successful synthetic polling; opted-in Keychain password restoration across termination with explicit Connect. This resolves the earlier post-fix hardware automation failures without weakening the assertions.

The same two checks also pass on the iOS 27 simulator (`connect-scroll-simulator.xcresult`). The corrected owner-assisted live harness now passes on the physical device (`iphone-live-confirmed.xcresult`: 1 passed, 0 failed). It observed both Live and “Socket.IO state is current.” after the owner entered credentials directly in the app. The sanitized receipt is `live-confirmed-sanitized-status.json`. No chat command was submitted. This supersedes the earlier build-only status of the corrected harness; the earlier failed result bundles remain retained. Host requests without credentials to both CSRF bootstrap and poll returned 302 to same-origin login (`unauthenticated-https-recheck.json`); no response bodies or cookies were retained. This is denial without a session, not authenticated CSRF/Origin-negative acceptance.


## Owner report after successful test

The owner confirmed sign-in and visible chats, then reported that the app closed. The passing test entered Tear Down at 14:32:59 local time. A subsequent read of the device's `systemCrashLogs` domain found no AgentZero-named crash report. The app was relaunched outside XCTest and its process was present (PID 16364). This points to test teardown, but absence of an app-named crash report is not proof against every termination cause. The owner subsequently confirmed that normal sign-in stays open with chats visible outside XCTest. A second process check retained PID 16364 and a second app-named crash inventory remained empty. Together these observations support test teardown as the explanation; they are not a long-duration stability or memory-pressure test. No credentials or live transcript were inspected.
