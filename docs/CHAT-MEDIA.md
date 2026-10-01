# Chat media and connection status

## Browser captures

Explicit browser tool metadata (`browser_snapshot` or legacy `Screenshot` image URI) opts into native screenshot rendering. Ordinary Markdown images do not trigger authenticated downloads. The app retrieves raster captures only through the current authenticated server's `/api/image_get` endpoint, with no redirects, no disk image cache, an 8 MiB response ceiling, bounded pixel dimensions and thumbnail decoding off the main actor. Account generation, selected context and log epoch fence the result. Leaving the view or backgrounding removes decoded images from view state.

The conversation consolidates captures in one Browser/Computer pane and disables duplicate inline tool cards. Capture history selects one retained evidence image at a time. Historical images still use bounded popovers; negotiated live capture can expand into the dedicated takeover workspace. See [Live viewer](LIVE-VIEWER.md). Capture loading and explicit Retry are visible; unavailable/expired captures do not block reading the rest of the message.

## Direct audio and video replies

Ordinary assistant prose containing a supported direct public HTTPS audio/video link offers a native **Load audio/video** card beneath the unchanged message. Recognition is local and bounded; it performs no lookup or download. Code, quotations, HTML, user/tool entries and explicit or candidate generated payloads are excluded. Explicit A2UI retains precedence. Files still pass the existing credential-free media policy after Load; playback requires Play. Playback stays inline with compact audio controls or a bounded video frame, keeping the conversation and composer accessible. Unload releases the player; starting another clip pauses the previous one. See [the generated-media contract](GENERATIVE-UI.md#audio-and-video).

## Related subagent chats

A compact **Subagents** control below conversation status shows verified child chats and a New count. It opens the themed Agents inspector with related conversation cards; opening a child marks it seen and exposes **Return to parent**. Navigation uses existing chat selection, retaining each chat's draft and attachments. Arrival never changes the selected chat. Same-chat recorded agent steps remain separate from related chats.

Relationships require server-reported subordinate metadata between visible contexts; names and tool prose never create links. Missing, deleted, ambiguous or cyclic relations are discarded. Only positive Working/Paused evidence produces a status; false or missing running does not mean Complete. Initial historical data establishes a baseline. Newness survives background/foreground in the same authenticated session and resets on disconnect/profile replacement. Incomplete sync disables navigation and defers discovery reconciliation.

## Attachments

The composer plus opens Tools → Attach images or files. Photo Library and Choose Files use native pickers. Selection stages data on this device; it does not upload or send. The removable tray shows filenames and sizes. Limits are five files per message, 10 MiB per file and 20 MiB total.

Attachment data lives in protected, profile-isolated files managed by SessionRepository; ordinary draft archives contain only metadata references. Send journals the pending delivery before any mutating request. Immediate messages (idle or Steer mode) use `message_async` multipart file parts named `attachments`. Queue-mode messages for a busy or already-queued chat upload multipart `file` parts to `upload`, validate returned filenames, then enqueue with `message_queue_add`. An uncertain upload/send is never automatically replayed. Acknowledged files are cleared while retained or uncertain drafts remain recoverable.

## Connection indicator

The rounded message input contains a small status dot at its upper-right corner, with a 44-point button target and no persistent status text. The draft has a separate column so wrapped text cannot overlap the indicator; the button stays top-aligned as the input grows with text size or multiline drafts. Green means current realtime state, blue means polling is keeping state current, amber means synchronization/reconnection, red means attention is needed and gray means no active connection. VoiceOver announces the textual state. Tapping opens a compact explanation, agent-paused information when relevant and explicit Retry sync after exhausted recovery. Connection/setup screens retain their text status.

## Working and follow-up messages

The composer uses one trailing Send/Stop control. With an empty draft and running, paused or queued work, it shows Stop. Typing text or staging a file restores Send and an adjoining menu offers Stop agent and clear queue without discarding the draft. Idle empty chats show disabled Send. A Stop in progress disables submission. The active button keeps a rotating progress ring while the selected agent is running (static with Reduce Motion). Settings → Send mode defaults to Queue: messages sent while the agent is busy or a queue already exists join the server queue. Steer submits immediately through the ordinary message endpoint. Changing mode affects future explicit sends only; it neither drains an existing queue nor replays uncertain delivery.

## Acceptance boundary

Synthetic protocol/UI fixtures establish endpoint shape, local state and presentation. They do not prove the owner's live server screenshot availability or uploaded file processing. New fixtures never access the owner's Photos library or upload files to the live server. Exact test runs are recorded in docs/tdd/browser-media and the final slice receipt.
