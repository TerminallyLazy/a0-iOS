# Follow-up send mode

Journeys are derived from the user's request: queue follow-ups by default, optionally steer immediately, keep sending while agents work, and retain the choice after relaunch.

## Contract

Settings stores `sendMode` in the same non-secret local preference suite as appearance (isolated UUID suite in UI tests). Missing or unknown preferences resolve to Queue. Queue uses the existing server queue when the selected chat is running, has active progress, or already contains queued messages. Otherwise messages send immediately. Steer always uses the immediate message endpoint. New-chat creation remains direct. Changing preferences does not drain or move an existing server queue.

Backend source checked read-only: `webui/components/chat/input/input-store.js` `_getSendState`, `api/message_queue_add.py`, `api/message_async.py`, `api/message.py`. The queued endpoint is `/api/message_queue_add`; immediate delivery is `/api/message_async`. The same decision is passed through the attachment delivery path. No server changes or live mutations were made.

## Evidence

Command: `swift test --filter 'sendMode|steerSends|queueAllows|changingMode|newChatSends'`.

- RED: the new tests failed compilation because `SendMode` and the `mode` send parameter did not exist; see `red.log`.
- GREEN: the same command passed six tests (the policy test exercises four busy/queue combinations); see `green.log`.
- Guarantees: conservative preference default, immediate steer even with an existing queue, repeated explicit queue sends after acknowledgment while busy, no replay after an uncertain mutation even when changing modes, direct creation/first send despite a stale busy hint.
- `SendModeUITests.testFollowUpsQueueByDefaultAndSteerPreferencePersists` is authored for synthetic native UI verification: queue/steer receipts, active send indicator accessibility, and persisted selection. Execution and device evidence are recorded by the owning integration run.

No dependency installation or commits. Coverage is not claimed from this focused run. Spinner rendering and end-to-end UI acceptance belong to the integration run.
