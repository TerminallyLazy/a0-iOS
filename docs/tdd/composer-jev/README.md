# Jev setup discovery and combined Send/Stop

Journeys derive from the requested Settings and composer improvements: find the Jev credential destination before opening it; stop active work from the trailing composer control; send queued or steering follow-ups without losing cancellation access or drafts. No transport, credential storage or server behavior changes.

## RED / GREEN

`5e13739` records the executed runtime RED: all three selected iPhone tests failed for the expected missing Jev wording, duplicate empty-draft Send/Stop controls, and absent combined-control menu. The target compiled and tests executed before production changes. `005560e` records GREEN: all six selected iPhone tests passed. One intermediate implementation build failed by referencing a private attachment-import flag; that reference was removed. It is not counted as the RED proof.

Executed native command through XcodeBuildMCP `test_sim`:

```sh
xcodebuild -project AgentZeroSpike.xcodeproj -scheme AgentZeroSpike \
  -configuration Debug -destination 'platform=iOS Simulator,id=0758A3EE-44E9-4645-AEC3-8CA818DBF74C' \
  -derivedDataPath /tmp/a0-composer-derived \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -parallel-testing-enabled NO -enableCodeCoverage YES \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
  -only-testing:A0UITests/SendModeUITests \
  -only-testing:A0UITests/JevUITests/testSecureSettingsSaveEnableReplaceRemove test
```

RED used only `testEmptyWorkingComposerHasOnePrimaryStopThenReturnsToSend`, `testStopFromComposerPreservesDraftAndStopsWorkingState`, and the Jev settings case. Result bundles: `/tmp/a0-composer-red.xcresult` and `/tmp/a0-composer-green2.xcresult` (disposable).

| Guarantee | Executed UI check | iPhone result |
| --- | --- | --- |
| Settings names the Jev API key; save/enable/replace/remove still work | `JevUITests/testSecureSettingsSaveEnableReplaceRemove` | Passed |
| An empty working composer has one Stop control and returns to disabled Send after stopping | `testEmptyWorkingComposerHasOnePrimaryStopThenReturnsToSend` | Passed |
| A nonempty draft offers Stop inside the joined Send menu and survives cancellation | `testStopFromComposerPreservesDraftAndStopsWorkingState` | Passed |
| Default Queue and persisted Steer still route through their existing endpoints | `testFollowUpsQueueByDefaultAndSteerPreferencePersists` | Passed |
| Attachment-only follow-ups remain sendable, queue, then return to Stop | `testAttachmentOnlyFollowUpStillQueuesAndReturnsToStop` | Passed |
| Unknown Stop outcomes remain visible and are never silently replayed | `testStopFailureIsVisibleAndDoesNotSilentlyReplay` | Passed |

`swift test --enable-code-coverage` passed all 265 package tests (57 generative, 208 core), including queue/steer delivery and cancellation protocol checks. `xccov view --report --json` for the six-test iPhone run measured ChatComposer.swift at 458/557 executable lines (82.23%) and SettingsView.swift at 474/492 (96.34%). SwiftUI generated closures contribute to these line counts; they do not prove every condition or whole-app coverage.

Screenshots in `docs/evidence/composer-jev/` contain only synthetic content. Live Agent Zero work and real TypeSafe credentials are outside these fixture checks.

## Final refinement and tablet checks

Removed the extra send-mode label calculation: the accessible action remains Send, while the existing send path is the only owner of Queue/Steer routing. The same command on iPad Pro 13-inch / iOS 26.5, using destination `256E8E14-492E-4A80-B1F1-B3EF18E1FA90`, passed all seven tests, including the added maximum-text Settings/composer and whitespace-draft check. iPhone is dark appearance; iPad is light. No transport code changed.

The maximum-text and whitespace case also passed on iPhone 14 Plus / iOS 26.5 after the refinement. Seven distinct UI journeys therefore passed on each platform across the documented runs. Screenshots were visually reviewed.

The signed Release build passed and strict signature verification succeeded. Direct installation and ordinary launch succeeded on the paired physical iPhone 15 / iOS 27.2 as 0.1.0 (5). No fixture arguments were used. This confirms device handoff, not owner acceptance against the live server. No push, merge or TestFlight upload occurred. Task-owned DerivedData, test products, result bundles and exported screenshots were cleaned after retaining this report and selected images.
