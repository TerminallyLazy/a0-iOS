# Chat UI and Agent Zero identity — 2026-09-28

## Changes

New chat now pushes a durable draft route and stays open when the server assigns a context. Existing chats retain stable routes. Root startup stays on the navigation container. The composer is multiline; the chat list is searchable.

Native Markdown supports headings, inline emphasis/code, lists/tasks, quotes, fenced code including incomplete streaming fences, rules and basic pipe tables. Copy message/code and expandable activity details are available. Images remain descriptive text; HTML is not executed. All message links, including headings and collapsed previews, require a validated HTTP(S) destination and confirmation.

Long messages and tool output collapse. Consecutive known routine activity logs group under a step-count disclosure without combining warnings, errors, unknown types or final answers. Scroll gestures and expansion pause following. Latest resumes it. An unmounted lazy footer uses an infinite position, avoiding the false-bottom signal that previously resumed following while reading history.

Original Agent Zero wordmark/mark SVGs were copied without artwork changes. AppIcon.png is a Quick Look rasterization of backend webui/public/icon.svg, with source provenance embedded. Neutral colors derive from webui/index.css; the adaptive tint and explicit foreground pair maintain readable actions. Native system navigation/material and Dynamic Type remain in use.

## TDD and retained failures

- core-red.log: Markdown/presentation types did not exist.
- follow-red.log: follow-intent type did not exist.
- group-red.log: grouping type did not exist.
- ui-red.xcresult: New chat did not open a dedicated conversation navigation screen.
- link-red.xcresult: a heading link bypassed destination confirmation; moved link handling to the complete message row. link-green.xcresult passes confirmation/cancel, details and code copying on iPad.
- device.xcresult and device-final.xcresult retain expansion/history failures that identified unwanted follow resumption; device-follow-fixed.xcresult passes all three initial physical flows after correction.
- regression.xcresult and chat-check.xcresult retain stale test assumptions: tests typed during navigation, assumed a single-line field placeholder value, or tapped a covered reconnect password. Tests now await the conversation, accept native empty multiline values and reveal the password field.
- device-complete.xcresult: four of five pass; the link test assumed iOS 26 Link accessibility type on iOS 18, which exposes the same attributed link as StaticText. The test now locates its visible label while still requiring the actual destination confirmation.

## Verification

- core-complete.log: **97 tests pass**. Measured executable line coverage: MarkdownDocument 106/106, TranscriptFollowState 5/5, TranscriptGroup 12/12 (100% each).
- regression-final.xcresult: **16/16** chat, persistence, foreground recovery and realtime-promotion flows pass. MCP response timed out at 300 seconds; completed xcresult independently confirms all 16 passed with no runtime warnings.
- onboarding-final.xcresult: **11/11** connection, existing-chat, profiles/Keychain and QR flows pass.
- ipad-light-confirm.xcresult: Markdown and grouped activity **2/2** pass.
- ipad-dark-confirm.xcresult: Markdown expansion/copy/collapse **1/1** passes with maximum accessibility text size in dark mode.

The 27 existing regression flows ran before the final style/link/group refinement; new behavior has focused checks rather than a repeated full suite. Evidence uses isolated synthetic data and no live server mutation. Hardware acceptance and final build receipts are recorded below after completion.

## Review and limits

Impeccable review found Latest/placeholder contrast, retry touch targets and incomplete link-handler scope. The correction uses explicit adaptive colors, 44-point label hit areas and whole-row URL handling. Screenshots are under .impeccable/review; they depict synthetic fixtures, not the owner's chats. Agent Zero identity is primary. [Goose reference decisions](../../GOOSE-REFERENCES.md) document secondary inspiration; no Goose code/assets or dependencies were imported.

Markdown is a deliberately bounded native subset, not full CommonMark/GFM: nested lists, escaped-pipe table edge cases, math, syntax highlighting and remote image rendering remain outside this slice. Full WebUI parity, attachments, voice, execution controls and management remain planned. Live new-chat creation and the refreshed UI still need the owner's check; earlier live existing-chat send/receive was owner-reported. No credentials or transcript contents were inspected, no backend files changed, and no TestFlight/distribution was performed.


## Final receipts

- **device-verified.xcresult: 5/5 pass** on physical iPhone 15 / iOS 18.7.3: dedicated new-chat/send route, Markdown expansion/copy/collapse, history-follow pause/resume with an incoming reply, grouped tool activity preserving the final answer, and link confirmation/cancel plus tool details/code copy.
- Final focused native coverage (verified-coverage.json): MessageRow 234/241 (97.1%), MarkdownView 158/159 (99.4%), ConversationView 412/424 (97.2%). These are line coverage for the focused run, not whole-app acceptance.
- **release-verified.log: unsigned iOS Release build succeeds** after the final production changes. Device tests built/installed with the existing authorized development identity.
- Latest physical screenshots refreshed under .impeccable/review. The app was launched without XCTest or synthetic launch arguments after testing; owner acceptance of refreshed live behavior remains separate.

Final independent Impeccable scoring disposition: **ship** for the four corrected findings; no fix-batch regressions identified. See `.impeccable/review/verdict.md`. This is not whole-app or live-server acceptance.
