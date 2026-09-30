# Workspace

A single draggable A0 tab at the chat’s right edge and the sidebar menu open **Workspace**, an authenticated in-app presentation of the server's right canvas and siderail. File Browser, Browser, Desktop, Editor and plugin-contributed tools come from the server's surface registry. A tool appears only when its server extension registers it; no local list invents availability.

## Ownership and behavior

`WorkspaceWebAdapter.js` initializes the existing `rightCanvas` store and presents its registered tools. The home presents responsive tiles using each registered surface’s title and icon or image. The duplicate rail and tab row are hidden; original toolbar slots, HTML panel extensions and open/close/dock lifecycles remain. Panels use the full host width on both phone and tablet, with Back to tools returning to the tiles. The host labels otherwise unnamed modal/file action controls for VoiceOver and excludes inactive panels from accessibility.

`ConversationView` and `ChatSidebarView` own the native entry points. Workspace has no top-toolbar button. The tab uses the existing transparent AgentZeroMark asset, has a 44-point hit area and rounded inner corners, and sits flush against the right edge. Vertical dragging stays within the transcript viewport above the composer and stores its relative position as a local display preference; VoiceOver adjustment also repositions it. It disappears while the left drawer is open and adds no asymmetric transcript padding. `PluginScreenRoute.workspace` preserves the current native context, and opening from a new-chat draft does not create a chat. Tools retain their own context requirements and may require selecting a chat. Swarm’s live registration declares only a docked panel, with no mobile modalPath; the host keeps the real docked layout at narrow widths rather than returning an unrelated chat error. It does not invent a modal route or bypass canOpen. Plugin main/settings screens can hand off into a canvas surface without destroying their browser session when the source modal closes.

`PluginWebScreen` owns the same ephemeral authenticated browser used by plugin screens. `PluginWebAdapter.js` applies canvas styling only to the top document: embedded Desktop/Browser frames keep their own layout. Server authentication, TLS, CSRF, exact-origin navigation, the Dev Tunnels header and intercepted-fetch no-retry policy are unchanged. Native Done confirms closure; background/account/context changes clear the presentation.

The owner's approved embedded-WebUI exception includes these interactive Workspace surfaces. Server-side file edits and tool actions retain their existing WebUI request/socket semantics, without native per-action receipts. Native plugin lifecycle controls remain journaled. External OAuth windows still require dedicated compatibility work; this host does not claim universal transport support or verification of arbitrary plugin code.

## File exports

`WorkspaceDownloads` handles same-origin downloads and blobs owned by that origin through WebKit's download delegate. File Browser and Editor exports open the iOS share sheet. Names are sanitized into unique temporary directories, with protected storage and backup exclusion; normal sharing completion or browser teardown removes them. Backgrounding cancels outstanding downloads. Redirects, failed HTTP responses and automatic download resumption are rejected; platform TLS validation remains in force. File bytes do not enter JavaScript bridge messages or diagnostic logs.

## Verification

`PluginWebFixtureUITests.testWorkspaceRegisteredToolsAndEmbeddedFrame` uses real shell/canvas/rail modules and the original File Browser component, with synthetic file metadata. Synthetic Browser/Desktop/Editor/custom surface registrations exercise discovery and interactive handoffs; a Swarm-style panel without modalPath and a blocked canOpen registration cover narrow-width compatibility and eligibility; a same-origin Desktop iframe verifies that host CSS does not hide child-frame applications. This is not proof of live remote-desktop streaming, real editor writes or browser automation.

Run the disposable HTTPS fixture as described in [PLUGINS.md](PLUGINS.md), then the focused UI test on phone and tablet. Run `node --test Tests/PluginWebAdapterTests.mjs` for fetch protection and frame-layout isolation, `swift test --enable-code-coverage --skip-update`, and the iOS build. Exact outcomes belong in [ACCEPTANCE.md](ACCEPTANCE.md).

Representative synthetic evidence: [iPhone Workspace](evidence/workspace/iphone-workspace.png), [iPad File Browser](evidence/workspace/ipad-file-browser.png) and [native export sheet](evidence/workspace/ipad-export.png).

Current synthetic visual evidence: [attached draggable A0 tab](evidence/workspace/attached-a0-tab.png), [Workspace icon tiles](evidence/workspace/workspace-tiles.png), and [panel-only Swarm fixture](evidence/workspace/panel-only-swarm-fixture.png).
