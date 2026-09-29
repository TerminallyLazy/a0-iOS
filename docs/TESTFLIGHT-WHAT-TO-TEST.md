Agent Zero 0.1.0 (3)

New in build 3: a dedicated red Stop button beside Send. While the agent is working, queue a follow-up, leave an unsent draft, then tap Stop. Verify this chat and its subagents stop, queued follow-ups are cleared, local voice stops, and the unsent draft and attachments remain. If cancellation cannot be confirmed, inspect the WebUI; the app must not report success or automatically retry. Requires a server with the /api/stop endpoint. Other chats and detached external programs are not stopped.

Connect to your own authenticated HTTPS Agent Zero server. Check sign-in, session restoration after reopening, opening older chats and creating a new chat.

Try Queue and Steer in Settings while the agent works. Verify queued follow-ups wait, Steer sends immediately, and the animated Send control remains usable. Tap the connection dot inside the input box for connection details.

Check Markdown, collapsed tools, browser screenshot previews, generated forecasts/charts/image carousels, project colors and model presets. Attach a small image or document, confirm it can be removed before sending, then verify receipt on your server.

Try dictation into the message field, keyboard dismissal and continuous-listening preference. Speech requires on-device recognition support and explicit microphone activation.

Report device/iOS version, reproducible steps and sanitized status text. Never include passwords, session cookies, tokens or private conversation content.

Known limits: no always-running background socket; the app refreshes when foregrounded. Expired server sessions require login. Unknown send outcomes are deliberately not replayed. Generated UI depends on the server/model emitting supported payloads. This is a beta, not complete WebUI parity.
