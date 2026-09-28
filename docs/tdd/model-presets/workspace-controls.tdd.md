# Native workspace controls — September 28, 2026

## Scope

Projects now expose colored assignments, filtering, creation, cloning, editing, explicit deletion and starting a conversation inside a project. Advanced project resources and credentials retain the confirmed WebUI handoff. Composer model selection changes only the current conversation override; the shared preset editor makes its broader scope explicit and checks for concurrent changes before saving. A new-chat draft has no server context yet, so selection becomes available after context creation.

Context accounting uses the server's context-window endpoint, including reconciled category counts, free space and provider cache/input/output usage. Unavailable data is not estimated. Conversation tools use an anchored popover. Authenticated cold launch shows the real startup splash, then a fresh draft with the drawer closed; earlier chats, drafts and generated replies remain accessible in the drawer. Same-process foreground restoration retains the current conversation.

All mutation intents are persisted in one profile-scoped control journal. Unknown outcomes are not replayed. No live server mutation, backend edit, new dependency, commit or push was part of this slice.

## Verification before inline-voice follow-up

- `core-final.log`: 159 package tests pass (140 core, 19 generative), including Projects, ModelPresets, ContextUsage and the Speech callback bridge.
- `phone.xcresult`: ModelPreset, Drawer and SessionLifecycle flows pass on iPhone simulator.
- `device-final.xcresult`: four focused physical iPhone 15 / iOS 18.7.3 flows pass: preset selection/shared editing, startup/drawer, earlier A2UI restoration after cold launch, and workspace tools/context.
- `release-build.log`: Release device build succeeds. That build was installed and opened outside XCTest.
- Earlier Projects device evidence lives in `../projects/`: four passes plus one selector failure in `device.xcresult`; the corrected focused flow passes in `device-confirm.xcresult`. These are separate runs, not a single green suite.
- Actual Speech-permission denial is exercised in `../projects/voice-permission.xcresult`. The callback crash evidence and correction are described in `../voice/permission-crash.md`.

The owner then confirmed that physical dictation remains open and transcribes. The owner requested inline composer dictation and retention of the continuous-listening preference; that follow-up has separate validation below. Continuous rollover, five-minute audio sessions and FoundationModels cleanup quality are not established by the single owner dictation check.

## Large-text review

Maximum-text dark iPad review exposed wrapping context numerals and an offscreen destructive confirmation. Context rows now stack the label above unbroken counts/percentages at accessibility sizes. Project deletion pins its typed-name-gated confirmation to the bottom safe area. Earlier test failures and incomplete Xcode bundles were not treated as successful receipts. Final targeted results are recorded after verification.

## Inline voice and final confirmation

The owner-requested follow-up places microphone input directly in Message and saves the continuous-listening preference. Existing text is retained; manual changes stop dictation rather than being overwritten. Send, backgrounding, interruption and conversation/profile changes stop audio. The preference does not restart recording. The routine saved-state caption is removed; storage failures and retry remain visible.

Final package verification: 162 tests pass (143 core, 19 generative), recorded in `../voice-inline/core-final.log`. Seven distinct physical iPhone flows pass across `../voice-inline/device-final.xcresult` and `device-confirm.xcresult`: three persistence flows and four synthetic voice flows. The initial run had two test failures: cursor placement differed from the asserted position, and the background check reopened before verifying background state. Corrected checks preserve the actual edited value and verify a real background transition before returning; both pass in the confirmation run. Automated voice fixtures never access the microphone.

Maximum-text dark iPad passes project create/edit/delete, inline transcript insertion and continuous preference restoration in `../voice-inline/ipad-final.xcresult`. Its manual-edit cursor expectation and context scroll selection initially failed; the focused confirmation log passes both corrected checks plus verified background cancellation. This is scoped verification across runs, not a fresh full UI suite.

The Release device build passes and was installed and launched outside XCTest on the paired iPhone 15 / iOS 18.7.3. The source/visual review disposition is ship for this bounded slice. The owner's earlier dictation confirmation establishes the permission-crash repair; actual microphone use with the new inline UI, long continuous rollover and FoundationModels cleanup quality remain owner acceptance checks. Live project/preset mutations were not performed.

The final iPad confirmation completed all three tests with zero failures in its log, but Xcode stalled during result finalization; the task-owned process was stopped. Its incomplete bundle is labeled explicitly in `../voice-inline/ipad-confirm-bundle-note.md`. Reviewed captures come from the earlier finalized bundle.
