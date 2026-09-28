# Durable drafts and safe relaunch — TDD evidence

September 28, 2026. Native iOS workspace: `/Users/lazy/Projects/agent-zero-ios`.

## Approved scope and skills

Continues the approved [plan](../../PLAN.md): local protected drafts and lifecycle recovery. The user asked to proceed and refer to SwiftUI Expert, swiftui-skills, Impeccable, ECC SwiftUI patterns, and ECC actor persistence. Those skills informed the implementation. The actor owns file I/O and cached archives; the existing MainActor observable session owns presentation. Unlike a naive cache-first repository, failed writes never become successful cached saves, and corrupt reads do not silently become an empty store.

SwiftUI Expert state/view/accessibility references, swiftui-skills patterns, and ECC patterns guided the extracted `ChatComposer`, injected `@Bindable` state, native actions, semantic text, minimum 44-point action targets, and explicit save/failure controls. Impeccable context and hardening/craft-floor references guided the bounded existing-surface recovery changes. This was not a broad redesign. Inspo was optional and was not used because the work follows the established native interface. No plugins or dependencies were installed or updated.

## Guarantees and RED/GREEN evidence

| Guarantee | Test evidence |
| --- | --- |
| Unicode drafts and selection survive repository/session recreation | `archiveSurvivesNewRepositoryAndSeparatesAccounts`, `draftsAndSelectionSurviveSessionRecreation` |
| Accounts have separate hashed filenames; mismatched archive identity is rejected | `archiveSurvivesNewRepositoryAndSeparatesAccounts`, `archiveFromAnotherAccountCannotBeLoaded` |
| Old revisions cannot replace new text; rapid edits finish with the latest value | `staleArchiveCannotOverwriteNewerDraft`, `rapidDraftEditsPersistTheLatestValue` |
| Corrupt/unsupported files remain intact instead of becoming an empty writable store | `corruptArchiveIsNotSilentlyReplaced`, `futureSchemaCannotBeOverwritten` |
| Disk failure does not report success or dispatch a message; save retry sends nothing | `diskWriteFailureDoesNotPretendToSave`, `diskFailurePreventsNetworkMutationAndKeepsDraft`, `retrySavingRecoversWithoutSendingAnything` |
| A second disk failure after chat creation still prevents message submission | `failedPostCreationCheckpointNeverSubmitsMessage` |
| In-flight delivery is written before dispatch and restores as uncertain without replay | `terminatedSendRestoresUncertainAndNeverReplays` |
| A saved acknowledgment does not resurrect a sendable draft | `savedAcknowledgmentDoesNotRestoreAsSendableDraft` |
| Stored files have private permissions and backup exclusion | `archiveHasPrivatePermissionsAndExcludedBackup` (macOS filesystem test) |
| Native relaunch restores a draft; confirmed clearing persists | `PersistenceUITests/testDraftSurvivesTerminationAndCanBeCleared` |
| Native relaunch restores uncertainty and disables resend | `PersistenceUITests/testUncertainSendSurvivesTerminationWithoutReplay` |
| Native storage failure preserves text, disables sending, and exposes retry | `PersistenceUITests/testStorageFailureOffersRetryAndKeepsDraft` |

Core RED: new tests compiled against the absent `ProfileIdentity` and `SessionStoring` interfaces; `red.log` records the intended missing-implementation failure before production edits. Final `swift test --enable-code-coverage`: **57 passed**, including all previous chat/security tests; `green.log`.

UI RED: XcodeBuildMCP `test_sim` selected `A0UITests/PersistenceUITests` before app integration. `ui-red.xcresult` records three failed journeys: no saved-state status, drafts lost on termination, missing clear/retry actions, and missing restored uncertain state.

UI GREEN: same scheme and iPhone simulator, all targets enabled, `-enableCodeCoverage YES -resultBundlePath docs/tdd/persistence/ui-green.xcresult`: **7 passed, 0 failed, 0 skipped**, 106.7 seconds. The three new journeys and four existing flows all passed.

Repository is still not under Git. No checkpoint commits, commits, or pushes were created; logs and xcresult bundles preserve the evidence. Additional boundary tests were added after GREEN as coverage expansion; they are not represented as new RED cycles.

## Storage contract

- One `SessionRepository` actor owns each directory. Version 1 archives contain profile identity, monotonic revision, selected context, drafts, and unconfirmed delivery records. No passwords, cookies, CSRF tokens, or transcript log stream.
- Files live in Application Support/AgentZeroSessions, named by SHA-256 of encoded origin/username. Directory/file permissions are 0700/0600; archives and directory are excluded from backup.
- iOS writes combine atomic replacement with complete file protection. Apple's [complete file protection documentation](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/completefileprotection) specifies that access fails while the device is locked; [atomic writing](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic) replaces the destination after the auxiliary write completes. Locked-device behavior still requires physical-device testing.
- Draft saves are serialized off the UI thread through the actor. The UI says Saved only after the latest queued write succeeds. Before create/send, the session awaits the persisted command stage; it does not dispatch if that checkpoint fails.
- On restart, creating/sending records become uncertain. Neither restoring nor save retry makes network mutations. An explicit future send remains subject to receipt reconciliation.
- Sign back into the same origin and username to load drafts. Disconnect retains them. Clear draft removes only its text; unresolved delivery records remain to prevent duplicate execution. Confirmed log receipts are omitted from later archives. Passwords remain memory-only.
- Corrupt or future-version files are not deleted or replaced. The connection UI explains local data could not be opened and advises unlock/retry while preserving the installation.

## Verification and coverage

- Core: `swift test --enable-code-coverage`; **560/600 lines, 93.3%**. `SessionRepository.swift` has 100% reported line coverage; `ChatSession.swift` 99.5%. See `core-coverage.json`.
- App: `xcrun xccov view --report --json docs/tdd/persistence/ui-green.xcresult`; **802/858 executable locations, 93.5%**. Composer 98.0%, app coordinator 82.6%. See `ui-coverage.json`. Xcode includes macro/generated locations in its counts.
- SwiftPM Release and unsigned iOS Release simulator builds pass; `release-build.log`, `ios-release-build.log`.
- iPhone 18 Pro/iOS 27 and iPad Pro 13-inch/iOS 26.5 built and launched; saved/empty composer inspected in `iphone.jpg` and `ipad.png`. No clipping found in these default-size layouts. Storage error/clear/relaunch behavior is XCUITest evidence, not claimed from the saved-state screenshots.
- The UI automation bridge reported typing success without a visible edit during manual capture. No visual error-state acceptance is inferred from that action. XCUITest independently typed and asserted the error state successfully.
- The iPad capture tool re-resolved a duplicate device name to a shutdown simulator; the screenshot was captured with simctl using the exact booted device ID instead. No extra simulator was erased or reset.
- Existing nested weak-capture compiler warning in SpikeModel remains. No build errors. No new dependencies.

## Limits

Core/app target percentages are separate; no whole-product coverage claim for realtime or the probe. The existing Protocol.swift file remains below 80% by itself. Real-device lock/unlock protection, power-loss durability, accessibility-size/VoiceOver auditing, authenticated remote HTTPS, and live message submission are not acceptance-tested here. Profile onboarding/Keychain, attachments, execution controls, automatic reconnection, and a dedicated iPad split layout remain later slices. No Agent Zero server mutation or source change occurred.
