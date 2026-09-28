# Controlled realtime recovery — TDD evidence

Source: approved [plan](../../PLAN.md), section 6. Scope: foreground polling-to-Socket.IO handoff. No backend changes, new packages, signing, distribution, commits, pushes, or live message/task mutations. The iOS workspace is not a Git repository, so no checkpoint commits were created.

## Behavior

While healthy HTTP polling owns visible state, the app attempts realtime after 30 seconds, then at 60/120-second intervals with a 120-second cap. Scheduling uses monotonic time and never catches up with a burst. Attempts begin only after an accepted current polling snapshot; failed polling cancels the candidate and uses the existing bounded HTTP recovery policy.

Each candidate refreshes `/api/csrf_token` using the current session, without logging in or consulting saved credentials. Cookie/runtime/CSRF rotation is accepted only through the existing validated bootstrap. Auth/CSRF rejection stops and requires explicit sign-in. Allowlisted transient refresh failures retain polling; other errors stop visibly.

Handshake and full socket state are staged in a separate reducer. The candidate must match the current context/generation, sequence and epoch, have full collections, and not roll back versions or replace different collection GUIDs observed by polling. A candidate rejected after a collection reset leaves polling to establish the baseline before a later attempt. On success, MainActor cancels and fences polling before publishing socket state. Attempt IDs prevent late callbacks crossing cancellation, selection, profile, or connection changes. The candidate has a 20-second socket-connect/handshake/full-state deadline after HTTP refresh. HTTP refresh uses the existing transport request timeout.

Draft editing and sending remain available while polling is healthy. No automatic command replay is introduced. Backgrounding still disconnects and requires explicit sign-in on return; automatic foreground reauthentication is outside this slice.

## RED / GREEN mapping

| Guarantee | Tests | RED evidence | GREEN evidence |
| --- | --- | --- | --- |
| Bounded realtime cadence, handshake/full-state gate, context/sequence/generation rejection | `RealtimeRecoveryTests.swift` | `red.log`: missing schedule/handoff implementation | `green.log` |
| Fresh existing-session bootstrap, rotated security material, no login/replay, expired session rejected | `RealtimeRecoveryTests.swift` | `red.log`: missing `refreshSocketSession` | `green.log` |
| Candidate cannot overwrite newer poll versions | `handoffCannotRollBackNewerPollingState` | `freshness-red.log`: handoff lacked current-state input | `green.log` |
| Candidate cannot undo a collection reset observed by polling | `handoffCannotCrossCollectionResetObservedByPolling` | `reset-red.log`: both GUID cases executed and failed | `green.log` |
| Native polling becomes Live only after full state; draft is preserved and no send occurs | `PromotionUITests` | `ui-red.xcresult`: Checking realtime and Live never appeared | Simulator results below |
| Missing full state retains healthy polling; expiry stops; background/context change rejects late callbacks | `PromotionUITests` | New acceptance cases alongside the missing-handoff reproducer | Simulator results below |

Commands: `swift test --enable-code-coverage`; `xcrun llvm-cov export` against the SwiftPM test binary and `default.profdata`; XcodeBuildMCP `test_sim` with the named suites, coverage enabled, and result bundle paths in this directory. Xcode 27 / Swift 6.4. A Swift Testing macro limitation required comparing the mutating schedule method's result to `true`/`false`; this test-expression correction is not counted as behavioral RED evidence.

## Validation

- Core: **88 tests pass**, **736/775 lines = 95.0%** in A0Core. `RealtimeRecovery.swift` has **100% line coverage**. Evidence: `green.log`, `core-coverage.json`.
- Initial new simulator flows: **4/4 pass**, `ui-green.xcresult`.
- Chat/recovery/promotion regression A: **12/13 pass**, `ui-regression-a.xcresult`. The sole failure was an incorrect expected empty-composer placeholder (`Message Agent Zero` instead of the existing `Message`). The assertion was corrected; no product behavior was changed to accommodate it.
- Persistence/profile/QR regression B: **11/11 pass**, `ui-regression-b.xcresult` (224.0 seconds).
- Final promotion suite: **5/5 pass**, `ui-final.xcresult` (99.9 seconds), including the corrected placeholder assertion and final version/GUID guards. Together with regression A, this verifies **24 distinct iPhone flows across the runs**, not one all-green full-suite invocation. No skipped tests.
- iPad Pro 13-inch M5 / iOS 26.5: selected handoff flow **1/1 passes**, `ipad-promotion.xcresult` (25.1 seconds), in Dark Mode and XXXL Dynamic Type. iPhone: iPhone 18 Pro / iOS 27.0. iPad appearance/text size and tool defaults were restored afterward.
- App source coverage across A/B/final runs: **750/867 distinct executable lines = 86.5%**. `coverage-union.py` reproduces the line union; `app-coverage-union.json` lists per-file results. App source is identical across these three runs; generated and dependency files are excluded. This is a source-line union, not a claim about one Xcode target coverage run. Regression A preceded the final A0Core GUID guard; the final promotion suite exercises that guard's integration.
- `swift build -c release`: **PASS**, `release-build.log`. Unsigned iOS Release simulator build via XcodeBuildMCP `build_sim` with `CODE_SIGNING_ALLOWED=NO`: **PASS**, `ios-release-build.log`. This is compile acceptance, not signing, installation on hardware, or distribution.
- One batched visual pass inspected [iPhone](iphone-screenshots/62D983AE-28A5-42A2-9436-50DF34A47D81.png) and [iPad](ipad-screenshots/8815138B-1A20-4960-8D02-08854F59CD7C.png): recovery explanation wraps, draft and enabled Send remain available, and larger text/Dark Mode do not obstruct the handoff state. No visual fix was needed.
- Remaining diagnostics: the iPad runner warns that support for all orientations will soon be required; the Release linker reports an address before section 26 with an ambiguous target atom; AppIntents metadata extraction is skipped because this target has no AppIntents dependency. The build succeeds, but these are not warning-free results. The linker diagnostic is retained without claiming a cause or resolution. No orientation acceptance is claimed.

## Limits

UI fixtures use the same coordinator, API client, policies, and reducer with synthetic HTTP and a replaceable realtime callback adapter. Fixture cadence is accelerated by a factor of five, with a ten-second deadline; unit tests verify production 30/60/120-second timing. Late fixture callbacks intentionally outlive disconnect to test fencing. These tests do not establish Socket.IO library reconnection, actual network loss, server restart, authenticated HTTPS, hardware lock/unlock, camera capture, or physical-device acceptance. The earlier live transport probe remains distinct evidence. No new live-server verification is claimed here.
