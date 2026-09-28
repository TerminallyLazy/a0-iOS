# Foreground polling recovery — TDD slice

September 28, 2026. Continues Milestone 1 lifecycle/recovery work. It does not close full milestone or device acceptance.

## Behavior and ownership

Previously, a single failed fallback poll called `fail`, disconnected, and removed the composer. `PollRecoveryPolicy` now permits four retries of foreground snapshot reads after selected transient failures. Base delays are 1, 2, 4, and 8 seconds, each with 0–25% positive jitter. Request timeout remains separate from this delay budget; there is no promise of recovery within 10 seconds.

Only URL loading failures for offline, lost connection, timeout, unreachable host, missing host, and DNS lookup failure are retried, along with HTTP 500/502/503/504. Cancellation, certificate/TLS failures, authentication/CSRF rejection, unexpected responses, incompatible schemas, and other HTTP statuses stop. No login, CSRF bootstrap, chat creation, send, queue mutation, or other command is automatically replayed.

`SyncReducer.invalidateForRecovery()` keeps the last displayed snapshot while invalidating generations and cursors. The next read requests full state; delayed snapshots for an old selection cannot be applied. `SpikeModel` owns the single serialized polling loop, cancellation, retry exhaustion, current-state gating, and recovery UI. Read failures belonging to the active connection still terminate authentication when appropriate even if the selected chat changed during the request.

During an outage, drafts remain visible/editable and protected storage continues saving them. The composer and model both block new sends until current server state returns. An in-flight command is marked uncertain through the existing session suspension path and is never replayed. Snapshot reconciliation may resolve its receipt, as before. After four unsuccessful retries, **Sync paused** offers **Retry sync**, a user-triggered read-only operation. Backgrounding/disconnecting cancels waits and in-flight reads; the existing explicit sign-in flow remains in place when returning to the app. Pausing synchronization does not pause an agent running on the server.

Socket.IO still falls back to HTTP polling. Automatic promotion back to Socket.IO, automatic foreground credential revalidation, and real network/device acceptance are separate remaining work.

## RED → GREEN evidence

| Guarantee | RED evidence | GREEN coverage |
| --- | --- | --- |
| Retry allowlist, four-attempt cap, jitter bounds, reset | `red.log`: missing PollRecoveryPolicy and reducer invalidation method | `PollRecoveryTests.swift`: all transient/nontransient parameter sets pass |
| Preserve last snapshot but require full resync; reject stale responses | Same RED run | Reducer test retains logs, zeros both request cursors, rejects stale generation/delta, then accepts a full snapshot |
| Keep draft and recover from a failed poll | `ui-red.xcresult`: missing Reconnecting state and composer after the injected failure | Four new recovery journeys pass in `ui-first.xcresult` |
| Exhaustion requires explicit read retry; background cancels; auth expiry does not retry login | UI tests authored before coordinator implementation | Transient, exhausted, background, and expired-session native flows pass |

`swift test --enable-code-coverage`: **78 tests pass**, including all previous protocol, credential, QR, and uncertain-delivery tests. `core-coverage.json`: **688/729 A0Core lines (94.4%)**; the new retry policy has 100% line and region coverage.

Debug-only `PreviewHTTPTransport` injects a bounded outage after initial synchronization. Recovery fixtures first advance both cursors and then reject any recovery request that does not reset both to zero. The exhaustion fixture remains failed through all four retries and succeeds only on the next explicit read. No live server task, network disruption, or real credential is used. This is synthetic transport/coordinator evidence, not real-network acceptance.

The workspace is not a Git repository. RED/GREEN evidence is retained in logs and result bundles without checkpoint commits. No dependencies were installed and no server files, signing, distribution, commits, or pushes were changed. Native UI behavior follows the established SwiftUI/Impeccable form and recovery patterns; draft-retention copy was corrected to match the already implemented optional Keychain behavior.

## Final regression and visual verification

- `ui-final.xcresult` / `full-suite-summary.json`: full 19-flow regression completed with **18 passed, 1 failed**. The tool's five-minute reporting timeout did not stop Xcode; its completed bundle was inspected directly. The failing existing send/reconnect test tapped Send before the new current-state gate enabled it, then expected a submission that had not occurred. Both failed assertions belonged to that one test.
- The test now explicitly waits for Send to become enabled. The app also labels selected-chat resynchronization. `ui-corrected.xcresult` / `corrected-suite-summary.json`: **all eight chat/recovery flows pass**, no skips (127.5 seconds), including the previously failing case and all four new recovery flows. Combined with the unaffected flows from the full run, all **19 distinct UI flows** are verified; this is not described as a single clean full-suite run.
- `ipad-recovery.xcresult`: the selected transient-recovery/draft-retention flow passes on iPad Pro 13-inch (M5), iOS 26.5 (29.7 seconds). iPhone tests use the dedicated iPhone 18 Pro / iOS 27 simulator.
- `ui-coverage.json`: app-target coverage from the full regression collection is **1,531/1,686 lines (90.8%)**, before the final synchronization-label addition/test readiness correction. Core coverage above comes from the separate passing SwiftPM suite. Coverage is not proof of live network or physical-device acceptance.
- SwiftPM Release and unsigned iOS Release simulator builds pass (`release-build.log`, `ios-release-build.log`). Existing realtime weak-self capture and iPad future-orientation warnings remain.
- One batched visual inspection found the retry explanation, editable retained draft, and disabled Send visible on both device classes, including the iPad keyboard layout. No additional visual adjustment was needed. Screenshots: [iPhone](iphone-screenshots/0985AC14-CA67-496F-990A-2B4614526CE5.png), [iPad](ipad-screenshots/1150D9AF-181E-4D4E-AAF2-9463352A26EA.png).

## Remaining acceptance

Real Wi-Fi/cellular loss, server restart/runtime rotation, TLS failures on a physical device, physical lock/unlock, camera capture, and authenticated remote HTTPS remain unverified. The simulator does not establish physical-device lifecycle or live server behavior. Automatic realtime recovery and foreground sign-in are still deferred.
