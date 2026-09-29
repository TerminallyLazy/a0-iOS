# Composer Stop

A dedicated 44-point Stop action stays available beside the voice and Send controls in an existing chat, including while a draft is populated. It stops local dictation/read-aloud, preserves the unsent draft and staged attachments, and requests cancellation of the current chat's agent task tree.

The authenticated control clears `/api/message_queue_remove` first, then calls `/api/stop`. Clearing first prevents the normal delayed queue worker from restarting the cancelled chat. Cancellation is still attempted after a queue-clear failure unless authentication has been invalidated. Both operations are explicit, scoped to the captured context, and never automatically retried. A single persisted control receipt covers the sequence; only valid acknowledgements for both steps resolve it. Partial results remain uncertain and the user can inspect them through Chat tools/WebUI. Existing unresolved control receipts are preserved. Send is disabled during Stop, and Stop waits for any in-flight local delivery to finish.

Acknowledged success marks this context's locally queued receipts as removed, without changing drafts or other chats. Stale queue snapshots cannot restore their queued label. Later transcript evidence can still confirm a message that reached the agent before cancellation.

The server endpoint cancels the context's registered child tasks through `kill_process`; it does not erase chat history, undo completed actions, stop other chats, or guarantee termination of detached external processes. Older servers without `/api/stop` report an unconfirmed result, never fabricated success.

## Verification

- RED: the new stop protocol tests failed to compile because `AgentControl.stop` did not exist (commit 767c826). The queue-receipt regression separately failed because `recordClearedQueue` and `.cancelled` did not exist (commit 7742981).
- GREEN: `swift test --enable-code-coverage` passes 198 tests (179 core, 19 generative UI), including request ordering, CSRF preservation, scoped acknowledgements, cancellation after queue failure, no automatic retries, expired authentication, scoped cancelled receipts and stale snapshots.
- Coverage: AgentControls.swift 90.16% lines; ChatSession.swift 98.65% lines.
- The failure-path UI test initially tapped while the first chat snapshot still disabled controls; it now explicitly waits for the Stop button to become enabled.
- Simulator UI: composer Stop preserves the draft and reaches idle; server failure stays visible and repeating Stop cannot bypass the unresolved receipt; Queue/Steer behavior remains functional.
- No live user conversation was stopped. No physical-device or detached-process cancellation acceptance is claimed. This source change is not included in the previously uploaded TestFlight build 2.
