# Chat media and connection status

## Browser captures

Explicit browser tool metadata (`browser_snapshot` or legacy `Screenshot` image URI) opts into native screenshot rendering. Ordinary Markdown images do not trigger authenticated downloads. The app retrieves raster captures only through the current authenticated server's `/api/image_get` endpoint, with no redirects, no disk image cache, an 8 MiB response ceiling, bounded pixel dimensions and thumbnail decoding off the main actor. Account generation, selected context and log epoch fence the result. Leaving the view or backgrounding removes decoded images from view state.

Collapsed activity shows the latest three capture cards; earlier captures remain inside tool details. A tap opens a larger bounded popover, with an explicit Close action, while preserving the conversation. Capture loading and explicit Retry are visible; unavailable/expired captures do not block reading the rest of the message.

## Attachments

The composer plus opens Tools → Attach images or files. Photo Library and Choose Files use native pickers. Selection stages data on this device; it does not upload or send. The removable tray shows filenames and sizes. Limits are five files per message, 10 MiB per file and 20 MiB total.

Attachment data lives in protected, profile-isolated files managed by SessionRepository; ordinary draft archives contain only metadata references. Send journals the pending delivery before any mutating request. Immediate messages (idle or Steer mode) use `message_async` multipart file parts named `attachments`. Queue-mode messages for a busy or already-queued chat upload multipart `file` parts to `upload`, validate returned filenames, then enqueue with `message_queue_add`. An uncertain upload/send is never automatically replayed. Acknowledged files are cleared while retained or uncertain drafts remain recoverable.

## Connection indicator

The rounded message input contains a small status dot at its upper-right corner, with a 44-point button target and no persistent status text. The draft has a separate column so wrapped text cannot overlap the indicator; the button stays top-aligned as the input grows with text size or multiline drafts. Green means current realtime state, blue means polling is keeping state current, amber means synchronization/reconnection, red means attention is needed and gray means no active connection. VoiceOver announces the textual state. Tapping opens a compact explanation, agent-paused information when relevant and explicit Retry sync after exhausted recovery. Connection/setup screens retain their text status.

## Working and follow-up messages

The composer uses one trailing Send/Stop control. With an empty draft and running, paused or queued work, it shows Stop. Typing text or staging a file restores Send and an adjoining menu offers Stop agent and clear queue without discarding the draft. Idle empty chats show disabled Send. A Stop in progress disables submission. The active button keeps a rotating progress ring while the selected agent is running (static with Reduce Motion). Settings → Send mode defaults to Queue: messages sent while the agent is busy or a queue already exists join the server queue. Steer submits immediately through the ordinary message endpoint. Changing mode affects future explicit sends only; it neither drains an existing queue nor replays uncertain delivery.

## Acceptance boundary

Synthetic protocol/UI fixtures establish endpoint shape, local state and presentation. They do not prove the owner's live server screenshot availability or uploaded file processing. New fixtures never access the owner's Photos library or upload files to the live server. Exact test runs are recorded in docs/tdd/browser-media and the final slice receipt.
