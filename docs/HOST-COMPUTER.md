# Computer access through Agent Zero

The native Computer row connects the phone to a Launcher computer through the
existing authenticated Agent Zero server. The phone never connects to host CDP,
copies browser cookies, or grants host permissions.

## Use

1. Connect A0 Launcher to the same server and enable the needed Browser or
   Computer Use scope on the computer. Complete local OS permission prompts.
2. Open an existing chat in the phone app and tap Computer.
3. Review the computer name and individual readiness states. Choose Use my
   browser or Check my computer, edit the prepared text, then explicitly Send.
4. Read the response and tool captures in that conversation. Captures show
   Browser or Computer, host identity when bound, and capture time. A received
   capture does not prove a preceding action succeeded.

The initial release supports text-only tasks and one unambiguous Launcher host.
For browser work, the chat's effective Browser configuration must use
`host_required`. Configuration is project/global scoped; the phone does not
silently change it. A competing CLI or multiple hosts prevents explicit targeting.

## Protocol and recovery

Core advertises `host_tasks_v1` from the connector capabilities endpoint. Protected,
CSRF-checked `host_status` returns a bounded per-chat projection. `host_task`
validates the session/context-bound generation and stores a durable chat binding
before submitting through the existing message/queue path. Remote tools and
subordinates enforce that binding before each operation. Connection, scopes or
configuration changes invalidate it; server restart preserves the restriction
while requiring fresh review. Active or queued descendants prevent retargeting.

The mobile delivery journal records intent before sending. Timeouts remain
uncertain and are never replayed, including after foregrounding or relaunch.
Saved draft targets omit generation tokens and require explicit review. Removing
a draft target does not clear a server-side chat binding; use a new chat for
unrelated work. Older servers expose informational presence without task controls.

All screenshots use explicit tool metadata and authenticated, bounded same-origin
`image_get` reads. No arbitrary transcript or host file paths are fetched. Existing
profile/context/log fences and background image cleanup still apply. Page content
and screenshots may reach the server's configured models.

Stop cancels the current server task tree and clears queued follow-ups. It is not
a host-wide Disconnect and cannot undo external effects already performed.
Launcher owns host Disconnect, permissions, file scope and browser selection.

## Verification

`HostConnectionTests` covers discovery compatibility, payload validation, session
continuity on optional 404, exact mutation receipts, scoped captures, draft
isolation and no replay. `PluginWebFixtureUITests.testHostComputerReadinessAndExplicitDraft`
uses the disposable HTTPS fixture with `--host-fixture` for native layout and
draft preparation. Backend targeting tests live in Agent Zero's
`tests/test_a0_connector_host_tasks.py`.

See ACCEPTANCE.md for exact build, simulator, runtime and physical-device evidence.
The optional live-capture/takeover extension is documented in [Live viewer](LIVE-VIEWER.md).
Video streaming, phone permission controls, APNs, multi-host selection
and point-and-ask annotations remain outside this release.
