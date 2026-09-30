# Jev TDD evidence

Source: [approved Jev plan](../../JEV-PLAN.md). User approved in chat after canvas review on September 30, 2026. Swift/XCTest are the actual runners; ECC npm detection was a default with no package.json. Plan shell examples were normalized to project test/build commands; no secrets, destructive validation or remote installers were used.

## Journeys and guarantees

| Plan task | Test target | RED evidence | GREEN evidence |
| --- | --- | --- | --- |
| Candidate contract and fallback | JevContractTests | Swift compile-time RED: missing JevClient, JevChoosing, JevChoice, JevBatch and JevCoordinator; underlying contract types also not implemented | PASS: final package run |
| Secure profile credentials | JevCredentialTests; JevUITests | Same compile-time missing implementation; native missing-field RED | PASS: final package run |
| Bounded choice transport and durable attempts | JevTransportTests; JevReceiptTests | Same compile-time missing implementation | PASS: final package run |
| One-attempt lifecycle and stale reply rejection | JevCoordinatorTests | Same compile-time missing implementation | PASS: final package run |

RED command: `swift test --enable-code-coverage --filter Jev` exited 1 because the new tests reference missing Jev types. Existing pinned dependencies resolved successfully. No production Jev code existed at this checkpoint. Raw regenerable output: `/tmp/a0-jev-red.log`.

Native UI RED command: `xcodebuild -project AgentZeroSpike.xcodeproj -scheme AgentZeroSpike -destination 'platform=iOS Simulator,id=0758A3EE-44E9-4645-AEC3-8CA818DBF74C' -derivedDataPath /tmp/a0-jev-derived -only-testing:A0UITests/JevUITests test`. Result: the new secure-field assertion failed because the control was absent; see the Core GREEN section below.

Live API checks and physical-device acceptance remain unverified. Coverage is recorded below. Only synthetic credentials are in tests. Local checkpoints are retained on codex/jev-ios; no push or release is included.

## Core GREEN checkpoint

`swift test --enable-code-coverage --filter Jev` passed 14 tests in five suites. The same missing implementations now compile and exercise candidate validation, credential storage, transport failures, durable deduplication and coordinator isolation. Raw output: `/tmp/a0-jev-green.log`. Coverage measurement follows integration.

The iPhone JevUITests runtime RED reached Settings / Generative UI, then failed because secure field `jevAPIKey` did not exist. This validates the missing Settings behavior before App implementation. Raw output: `/tmp/a0-jev-ui-red.log`.

## Expanded catalog RED

The user expanded scope to Metric, DataTable, Timeline and Checklist during implementation. `swift test --enable-code-coverage --filter ExpandedCatalogTests` failed because the tested `GenerativeGuide.expandedExample` and catalog behavior are missing. Native metric/table/timeline eligibility, malformed data rejection and persistent local checklist binding are explicit guarantees in the new test target. Raw output: `/tmp/a0-jev-catalog-red.log`.

## Admission-capacity regression RED

`swift test --enable-code-coverage --filter JevCoordinatorTests` ran five tests and failed the new `journalRejectionReleasesCapacityForLaterReplies` assertion: a previously journaled attempt occupied an in-memory pending slot after its early return, reducing later selection capacity. The in-flight provider cancellation regression passed. Raw output: `/tmp/a0-jev-capacity-red.log`.

## Expanded implementation GREEN

`swift test --enable-code-coverage` passed 251 tests: 43 generated-UI tests and 208 core tests. This includes the five coordinator regressions (early-return capacity is now released) and five expanded-catalog tests. A further runtime RED (`de8754d`, `/tmp/a0-jev-checklist-red.log`) proved that 21 checkboxes incorrectly passed the documented 20-task bound; validation now rejects that input. Final package output is `/tmp/a0-jev-package-complete.log`.

New Jev/expanded DTO logic has 97.34% line coverage (293/301 lines), 92.24% regions and 91.58% functions. `coverage.txt` records the exact six-file scope; this is not whole-app or Keychain/UI coverage. The command uses `xcrun llvm-cov report .build/out/Products/Debug/A0GenerativeUITests.xctest/Contents/MacOS/A0GenerativeUITests -instr-profile=.build/out/Products/Debug/codecov/default.profdata` with the six files listed in that report.

Owned source coverage across both package test binaries (excluding dependency checkouts, tests and DerivedSources) is 91.48% lines (2,877/3,145). Command: `xcrun llvm-cov report .build/out/Products/Debug/A0GenerativeUITests.xctest/Contents/MacOS/A0GenerativeUITests -object=.build/out/Products/Debug/A0CoreTests.xctest/Contents/MacOS/A0CoreTests -instr-profile=.build/out/Products/Debug/codecov/default.profdata -ignore-filename-regex='checkouts|/Tests/|DerivedSources'`. App and A0Realtime are outside these test binaries.

Initial native integration diagnostics are not business-logic RED evidence: one invocation selected zero tests, another lacked the candidate fixture, and the first complete fixture changed JSON field order between identical polls. Deterministic fixture serialization corrected the latter. Scrolling assertions also needed to account for initial bottom-follow position. None of these runs is counted as a pass.

## Native scroll regression

The executed `testNewReplyChoosesExpandedSurfaceAndChecklistReviewKeepsDraft` reached the newly rendered surface, then became unresponsive after scrolling toward the table. XCTest reported `App event loop idle notification not received` and entered failure triage after repeated snapshot timeouts (`/tmp/a0-jev-phone-scroll.log`). A two-second sample of that synthetic app showed its main thread continuously updating SwiftUI lazy layout, with approximately 100% CPU. The test runner also stalled while collecting the inaccessible view hierarchy; this is a reproduced UI hang, not a completed test-suite result. The scroll reproducer is retained before the layout correction.

A bounded repeat completed the runtime RED gate: XCTest reported `testNewReplyChoosesExpandedSurfaceAndChecklistReviewKeepsDraft exceeded execution time allowance of 2 minutes` in `/tmp/a0-jev-phone-layout.log`. Giving the horizontal table an intrinsic height did not resolve it. Subsequent isolation showed that deferring scroll calls, fixed heights, row identity changes and wrapping groups did not remove the hang. Eager transcript layout passed, but was not retained. The final fix keeps message rows lazy while placing the delivery area and bottom scroll anchor in the surrounding non-lazy stack.

The final layout fix preserves lazy message rows and moves `DeliveryContent` plus the measured `latest` anchor into the surrounding VStack. The eager-layout diagnostic and other attempted layout changes were discarded. The retained native regression verifies scrolling up to the table and back down to the checklist. Its switch interaction targets the actual switch thumb and asserts value `1` before review; tapping the broad accessibility row did not reliably change the control in the first anchor-fix run.

## Visible-candidate eligibility RED

`swift test --enable-code-coverage --filter JevContractTests` executed eight tests; the new `invisibleComponentsCannotQualifyRichCandidates` failed both assertions. A text-only root with orphan Metric definitions and a Dashboard containing only one reachable Metric incorrectly qualified. `/tmp/a0-jev-visible-red.log` records this intended runtime RED before the graph-reachability fix.

## Final package GREEN

After restricting candidate summaries and Dashboard eligibility to the reachable graph, `swift test --enable-code-coverage` passed **252 tests** (44 generated-UI tests plus 208 core tests), including both previously failing orphan-component cases. Output: `/tmp/a0-jev-package-final-reviewed.log`. This supersedes the earlier package totals above. Updated six-file coverage in `coverage.txt` is **97.27% lines (321/330), 91.70% regions and 90.91% functions**. The same owned-source coverage command now reports **91.52% lines (2,905/3,174)** across the two package test binaries.
