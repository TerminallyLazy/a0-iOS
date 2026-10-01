# Live host viewer

The conversation owns one Browser/Computer pane. Tool captures become a bounded
history selector. Compatible Launcher hosts advertise `host_viewer_v1`; older
hosts retain historical captures with takeover disabled.

## Interaction and transport

Expand opens a full-screen workspace; iPad also offers a resizable side pane.
Take over and Return use a centered tab joined directly to the capture’s bottom
edge, matching the Workspace edge-tab shape. A subtle theme-tinted gradient,
accent border, soft drop shadow and faint accent glow distinguish the controls
from the pane; disabled tabs suppress the glow.
The pane, source selector, letterboxing and expanded controls use the active
native theme. The WebKit background is transparent over the themed canvas;
captured website and desktop pixels retain their original appearance.
One footer row shows capture/control status, an explicit keyboard toggle and
an options menu for history, inspect mode and connection details. Keyboard
controls start collapsed. Historical fallback images omit their duplicate
metadata card and flex to the expanded pane's available height. Takeover is
disabled without a current capture; returning an existing hold remains available.
The compact container uses a continuous 24-point corner with 12-point content
insets. Capture and review surfaces use continuous 12-point corners; the capture
owns one clip and border, including historical fallback images. A 12-point bottom
inset keeps the review card clear of the container's lower curve.
Watching cannot send remote input. Take over closes the agent dispatch gate and
waits for the host to drain outstanding work before enabling touch and keyboard
input. Return drains input, captures final host state, invalidates prepared agent
actions and releases the gate. It does not send the task again or restart a
completed/stopped agent. Existing ordinary pause state remains independent.

`LiveViewerModel` owns one WKWebView and capture task. WebKit renders only bundled,
network-disabled HTML in a nonpersistent store. Native `APIClient.hostViewer`
handles authenticated same-origin HTTPS, cookies, CSRF, bounded responses and
account-generation fencing. Credentials and target-site HTML never enter the
JavaScript bridge. Routine same-account cookie refresh does not discard an ack.

Capture uses bounded JPEG snapshots, at most 1600 by 1200 and 1.5 MB each, with a
650 ms wait after each response. This is live capture, not a video stream. Frames
remain transient; only a final handback observation becomes server chat evidence.
The latest three frame identities remain valid for at most five seconds to cover
input in flight, with current page/session and geometry validation at dispatch.

Tap/click, browser drag, two-finger scroll, text and key controls address the same
host session. Inspect mode disables input and permits local zoom. Text is cleared
after submission and on background; receipts contain no typed text. Computer Use
currently captures the whole display and does not support drag. Launcher retains
all permissions and OS prompts.

## Recovery

Every mutation is journaled before transmission and is never automatically
replayed. Unknown results require inspection and explicit receipt review. Phone
background, context change and Workspace entry stop capture and clear pixels.
Lease expiry revokes input but keeps automation held. Watch live refreshes the
read-only state; Recover control or Return is explicit. A second viewer cannot
silently steal an active lease. Closing/minimizing is not Return.

Core persists the hold and fences browser, computer, file and execution dispatch.
Plugin hooks hold the owner and descendants independently of ordinary Pause,
Resume or Nudge. Connector restart/corruption remains held. Open remote execution
sessions block takeover acknowledgement because their effects cannot be certified
settled. Scope revocation must be repaired in Launcher before recovery.

## Verification

`LiveViewerTests` covers capture consolidation, bounded DTOs, acknowledged
ownership, receipt matching and cookie-refresh/account-disconnect races.
`LiveViewerUITests` checks a single identified WebKit surface through expansion,
takeover and handback on phone/tablet fixtures. Core `test_a0_host_viewer.py` and
connector `test_host_control.py` cover ownership, epoch fencing and no replay.
Physical acceptance and measured limitations belong in ACCEPTANCE.md; synthetic
fixtures alone do not establish phone-to-host input or resumed-agent behavior.
