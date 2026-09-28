# Native attachments — TDD evidence

Journeys derive from the request to attach images and files from conversation tools. Selection must remain local until explicit Send, with normal profile, delivery and persistence protections.

## RED → GREEN

- Initial `swift test --skip-update --filter 'attachmentRejects|multipartPreserves'` ran two tests against executable placeholder implementations: both failed with nine assertions covering header injection, oversized bytes, binary payload preservation, multipart fields and safe names. Actual output: `red.log`.
- Implemented bounded attachment values, multipart body generation, protected actor-owned staging files, metadata-only session archives, ChatSession delivery integration and authenticated idle/queued submission.
- `swift test --skip-update --filter 'Attachment|attachment|Multipart|multipart|rejectedUpload|removingDuringImport|changingOwnerContext'` passed all nine original tests. Final expanded output: `green.log` (ten tests).
- The disk restoration regression caught an async protocol default shadowing synchronous actor methods. Explicit async witnesses fixed it; the same nine-test suite passed after correction.

| Guarantee | Test | Result |
| --- | --- | --- |
| Control/header injection and >10 MiB files fail locally | attachmentRejectsHeaderInjectionAndOversizeData | PASS |
| Multipart preserves exact binary bytes and safe unique filenames | multipartPreservesBytesAndEscapesFilename | PASS |
| Attachment-only draft creates then sends once, no selection upload | attachmentOnlyDraftCreatesAndSendsOnce | PASS |
| Files survive fresh repository restoration, profiles stay isolated, uncertain sends never replay | attachmentDraftsPersistIsolatedAndUnknownSendNeverReplays | PASS |
| Count/storage rejection cannot upload | attachingOverLimitAndStorageFailureCannotUpload | PASS |
| Idle multipart and queued upload/queue submission preserve Cookie, CSRF, Origin, context and IDs | authenticatedMultipartUsesOriginalSecurityAndQueueContract | PASS |
| Rejected upload cannot enqueue | rejectedUploadDoesNotQueueOrReplay | PASS |
| Removing an existing file during import cannot resurrect it; Send waits for import | removingDuringImportCannotResurrectFileAndSendWaitsForImport | PASS |
| Context changes discard pending imports and clean their local bytes | changingOwnerContextDuringImportDiscardsNewFile | PASS |

A second RED → GREEN cycle covers orphan cleanup: `swift test --skip-update --filter startupPrunesOnly` failed because a terminated import's unreferenced file remained readable (`prune-red.log`). Startup-only pruning now runs on the first validated profile load, before any fresh stage writes; repeated loads preserve in-flight new files. The expanded ten-test selection passed (`green.log`).

## Contract and limits

Read-only backend reference: `api/message.py`, `api/message_async.py`, `api/upload.py`, `api/message_queue_add.py`. Idle attachments use multipart `attachments` plus `text/context/message_id`; queued attachments upload multipart `file`, validate returned unique filenames, then enqueue with `item_id`. Both mutation sequences are covered by the persisted ordinary delivery receipt and have no automatic retry.

Drafts allow five files, 10 MiB each, 20 MiB together; profile staging has a 64 MiB budget. UUID filenames, profile-hashed directories, owner-only modes, excluded backups and complete iOS file protection apply to local bytes. Archives contain filenames/MIME/count/IDs only. Successful acceptance/removal deletes bytes only after the archive save succeeds. Photos and Files require explicit picker interaction and bounded reads. Unknown outcomes retain receipt and staged files. First profile load also removes orphan UUID staging files that no saved draft references.

`AttachmentUITests` authors the synthetic native selection/remove/send/unknown-relaunch flow plus native Files-picker cancellation without file selection. The root task owns its run and device build receipts. No real file was uploaded, no live server mutation was performed, and no photo-library permission or live attachment acceptance is inferred from these fixtures. Full coverage measurement is part of the root integrated package run.

## Review follow-up: preparation before bytes exist

The reviewer identified a gap before `addAttachments`: slow Photos/iCloud loading still allowed Send. Added an owner-scoped preparation token before loading starts; Send remains disabled until loading/staging finishes or is canceled. Background/disappearance/owner changes release the captured session's token, and a stale completion cannot release a later reservation. Three RED tests failed against inert reservation/filename implementations (`preparation-red.log`); the expanded fourteen-test suite passes (`green.log`). This final run includes both trailing-dot normalization regression tests and proves the server's filename normalization cannot break queued acknowledgement matching. Native Files-picker testing is simulator-only, preventing the physical-device suite from opening owner document lists.
