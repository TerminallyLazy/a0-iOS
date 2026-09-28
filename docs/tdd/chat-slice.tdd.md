# Native text-chat slice — TDD evidence

September 28, 2026. Workspace: `/Users/lazy/Projects/agent-zero-ios`.

## Intent and boundary

Source: approved [PLAN.md](../PLAN.md), first Milestone 1 conversation slice. The user asked to proceed with ECC's `tdd-workflow`. Plan text was treated as planning data; validation was translated into native Swift Testing, XCUITest, and local build commands. No dependencies were added in this slice. The previously approved Socket.IO pins remain unchanged.

Journeys: create a chat and submit text; enqueue when a chat is busy; preserve per-chat drafts on failure or selection changes; report uncertain delivery without resending; reconcile matching server receipts; retain drafts through reconnect while separating accounts.

The ECC package-manager detector returned npm by fallback. This workspace has `Package.swift` and no package.json, so npm was not used. `git rev-parse --is-inside-work-tree` confirms this workspace is not a Git repository. No checkpoint commits could apply; the logs and result bundles below preserve stage evidence. No commits or pushes were created.

## RED → GREEN guarantees

| Guarantee / approved behavior | Tests | RED evidence | GREEN evidence |
| --- | --- | --- | --- |
| Create a fixed chat identity, send the original text/context/message ID with CSRF, validate acknowledgments, never replay errors | `ChatCommandTests.swift` | `chat-red.log`: missing intended `ChatAPI` implementation | `chat-green.log` |
| Create before sending; retain drafts; route busy/already-queued chats to the queue; prevent double taps; reject stale completions | `ChatSessionTests.swift` | Same initial compile-time RED | `chat-green.log` |
| Timeout blocks replay; a matching context/log ID resolves uncertainty; reconnect never resends | `ChatSessionTests.swift` | Same initial compile-time RED | `chat-green.log` |
| Queue receipt resolves lost HTTP acknowledgment before execution | `queuedReceiptResolvesTimeoutBeforeExecution` | `queue-red.log`: status remained uncertain and draft remained | `chat-green.log` |
| Log receipt cannot be downgraded by a late queue acknowledgment | `executionReceiptBeforeQueueAcknowledgmentStaysAccepted` | `receipt-race-red.log`: queued instead of accepted | `chat-green.log` |
| Queue receipt outranks a later HTTP timeout | `queueReceiptBeforeTimeoutStaysQueued` | `queue-race-red.log`: uncertain instead of queued | `chat-green.log` |
| Repeated old receipts cannot erase a new identical draft | `repeatedOldReceiptCannotEraseANewIdenticalDraft` | `draft-receipt-red.log`: new draft became empty | `chat-green.log` |
| Uncertain creation is visible before any context is selected | `uncertainCreationIsVisibleBeforeContextSelection` | `creation-visible-red.log`: missing intended visible-delivery projection | `chat-green.log` |
| Native new-chat/send clears the draft; timeout retains it and disables resend | `ChatUITests` first two journeys | `ui-red.xcresult`: two failures on missing New chat control | `ui-complete.xcresult` |
| Native HTTP-client send and reconnect preserve the pending draft | `testHTTPConnectionSendAndReconnectKeepsDraft` | `http-ui-red.xcresult`: missing synthetic HTTP connection path | `ui-complete.xcresult` |
| Different accounts at the same server do not share drafts | `testDifferentAccountDoesNotInheritDraft` | `account-red.xcresult`: first account's draft visible in second account | `ui-complete.xcresult` |

Test files live under `Tests/A0CoreTests` and `Tests/A0UITests`. Initial compile-time RED was followed by a test-helper correction: nested `#require` expansion was unsupported, so the body assertion was split into two statements. That macro error was not treated as business RED. The first UI implementation build also needed an actor-isolation correction; build/setup errors are not counted as behavioral evidence.

## Commands and final results

- Initial RED: `swift test --filter 'Chat'` (compile fails on missing ChatAPI).
- Follow-up RED: `swift test --filter <test-name>` for each regression named above. Logs retain actual assertion mismatches.
- Final core GREEN and coverage: `swift test --enable-code-coverage` — **43 tests passed**, including parameterized cases; no skipped tests.
- Native E2E: XcodeBuildMCP `test_sim`, scheme `AgentZeroSpike`, simulator `E69191E1-301F-4A18-B682-02BC75958E70`, `-enableCodeCoverage YES -resultBundlePath docs/tdd/ui-complete.xcresult` — **4 passed, 0 failed, 0 skipped**, 52.5 seconds.
- `swift build -c release` — passed; see `release-build.log`.
- iOS Release simulator build with signing disabled — passed; see `ios-release-build.log`. An initial tool invocation supplied the configuration twice; selecting Release in session defaults resolved that command setup error.
- Debug simulator build/run — passed; `chat-preview.jpg` shows the synthetic preview and native composer.
- `swift run a0-transport-probe http://localhost:49805` — live read-only HTTP snapshot and Socket.IO handshake/state application passed; see `loopback-probe.log`. It submitted no chat message or agent task.

Xcode 27.0 / Swift 6.4; simulator iPhone 18 Pro, iOS 27. Test sends use synthetic responses or the Debug-only HTTP fixture. The HTTP fixture exercises the app coordinator and real APIClient, but does not make real network calls. The compiler still reports the existing nested weak-capture ownership warning in SpikeModel; it is not a test failure.

## Coverage

`swift test --enable-code-coverage` emits SwiftPM LLVM coverage at `.build/out/Products/Debug/codecov/AgentZeroIOS.json`. Relevant summaries are preserved in `core-coverage.json`.

- A0Core: **440/482 lines, 91.3%**; **311/370 regions, 84.1%**.
- App target: **664/714 executable lines, 93.0%**, as reported by `xcrun xccov view --report --json docs/tdd/ui-complete.xcresult`; see `ui-coverage.json`. SwiftUI/Observation-generated executable locations contribute to Xcode's count.
- App coordinator `SpikeModel.swift`: **81.7%** line coverage.

Both tested targets exceed the skill's 80% target-level threshold. These figures are separate target metrics, not a combined whole-product percentage. Existing `Protocol.swift` alone remains below 80% (74.4%); A0Realtime and the diagnostic executable do not have instrumented coverage in this suite. The read-only live probe supplies interoperability evidence for realtime, not a coverage percentage. Swift coverage did not expose branch counters; region coverage is reported separately, without calling it branch coverage.

## Remaining gates

- No real text/queue mutation or agent response was tested against the user's instance. The source contract is mapped in deterministic request tests.
- The named loopback runtime remains HTTP with login disabled. Authenticated remote HTTPS and physical-device acceptance remain open.
- Drafts/delivery state are memory-only. They survive in-process reconnects, not process termination. Backgrounding disconnects and requires explicit reconnection.
- Uncertain submissions stay blocked until a matching receipt arrives. There is no manual override to risk a duplicate submission in this slice.
- Attachments, queue editing, execution controls, protected persistence/Keychain, automatic foreground recovery, notifications, and full accessibility/device testing remain pending.
- No server source changes, restarts, account changes, signing/distribution, commits, or pushes were performed.

This completes the text-chat development slice, not the full Milestone 0/1 acceptance gates or a production release.
