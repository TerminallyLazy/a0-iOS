# Plugins

The sidebar's **Plugins** workspace combines native **Custom**, **Built-in**, and **Plugin Hub** collections with the server's existing settings and main screens inside an isolated WebKit presentation. Agent Zero and its plugins continue to execute on the server.

## Ownership and API contract

- `Sources/A0Core/Plugins.swift` owns installed metadata, scope/status reads, documents and validated command payloads. `PluginHub.swift` owns catalog/update semantics and validated screen routes.
- `App/PluginWorkspace.swift` owns transient catalog state and shared `ControlJournal` coordination. `PluginsView.swift` owns installed/Hub/detail navigation and native confirmations.
- `Sources/A0Core/PluginThumbnail.swift` owns validated artwork references and authenticated thumbnail reads; `App/PluginThumbnailView.swift` owns bounded decoding and presentation.
- `App/PluginWebScreen.swift` owns the ephemeral browser lifecycle and session handoff; `PluginWebAdapter.js` adapts the initialized WebUI without modifying server source.
- `SavedAuthentication.validatedCookie` validates identity, origin, expiry and cookie bytes and returns a secure HTTPOnly cookie for restoration or WebKit handoff.

Installed state comes from `/api/plugins_list`. Scoped status/toggle/removal, deletion and installed documentation use `/api/plugins`. Hub fetch/install/update use `/api/plugins/_plugin_installer/plugin_install`. The installer reports `success`; the core endpoints report `ok`. Handle both HTTP failures and negative acknowledgements. The connector's global installed-plugin endpoint cannot substitute for these contracts.

Custom and Built-in cards expose a global enable switch instead of an enabled/disabled badge. The switch submits once through the existing journal and refreshes acknowledged server state; card details remain a separate tap target. Always-active plugins have locked-on switches, and loading or unresolved commands disable changes. Global activation preserves project/agent overrides. Removing an override submits only the server-returned path and relies on the server's allowed-asset validation. Built-ins cannot be deleted and always-enabled plugins cannot be disabled. Settings remain available for scoped plugins even without a custom form. Hub suspension blocks native installation/update, and commit/timestamp metadata drives update indicators. Catalog fetch can backfill thumbnails on the server and is not automatically retried.

Native install/update/delete/toggle/override commands validate before persisting a pending control receipt, then submit once. A timeout, failed acknowledgement or interrupted operation remains uncertain. Refreshing reads server state without clearing the receipt; the user explicitly resolves it after inspection. Receipt storage contains operation title and plugin identity, never configuration, tokens or response bodies. Native management shares the existing single-writer journal with other app controls.

## Embedded WebUI boundary

The user explicitly approved preserving trusted plugin and Workspace WebUI actions without native per-action journaling. Plugins may use fetch, sockets and GET-based operations; an app cannot infer every action's effect from transport alone. These screens preserve plugin behavior and do not claim universal native recovery or execution receipts. Native lifecycle commands remain journaled.

The browser uses a nonpersistent data store and the current profile's validated session cookie. Credentials never enter URLs, JavaScript source, bridge messages or diagnostic logs. The script-message interface accepts only bounded screen status strings from the expected main frame, not native commands. Plugin names are validated before path construction, and selected scope and current native chat identity are passed as structured JavaScript arguments. A native chat change closes the old screen; a new-chat draft is not converted into a server chat merely by opening a plugin. The authenticated `/index.html` document initializes before opening its existing settings/main modal; the `/` route is a splash that replaces its document, so it is not a valid embedded entry point. Root-level `/index.html` also preserves relative asset resolution (unlike directly navigating to `/ui/index`). custom controls, nested modals and dialogs remain WebUI-owned.

The fetch adapter preserves same-origin credentials, omits them for external requests, rejects automatic fetch redirects and throws on 401/403 before the core `fetchApi` retry branch can run. This is specific to the intercepted fetch path; arbitrary plugin libraries and socket behavior are not represented as exactly-once execution. Exact-origin navigation policy includes scheme/host/port, rejects login navigation and separates user-selected external HTTPS links. The installed server plugins are trusted code, not an isolation boundary against that server.

Backgrounding, disconnecting or changing profiles destroys sensitive web state. Reopening is explicit; it never retries an app command. Same-origin file exports use the Workspace download delegate and native share sheet. Native Done asks the user to save first and explains that closing does not cancel server work. External OAuth popups and specialized plugins require their own compatibility acceptance; do not infer universal plugin parity from the representative fixture.

The chat renderer continues to render non-executable native Markdown. Installed Readme/license use that existing renderer and its link-confirmation policy. Native Hub details link to a validated repository; third-party installation retains an explicit code-execution disclosure and exposes Plugin Scanner when the server provides it.

## Verification

```sh
swift test --enable-code-coverage --skip-update
node --test Tests/PluginWebAdapterTests.mjs
xcodebuild -project AgentZeroSpike.xcodeproj -scheme AgentZeroSpike \
  -destination 'platform=iOS Simulator,name=Agent Zero App Store iPhone' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:A0UITests/PluginUITests test
```

`PluginTests` exercises authentication/payloads, origin and identity rejection, protected plugins, inheritance, catalog envelopes, update ordering, HTTPOnly cookies and no automatic retry. `PluginUITests` uses `PreviewHTTPTransport` and synthetic journal namespaces for installation/deletion/activation and uncertain outcomes. The JavaScript tests execute the actual adapter against deterministic requests.

`PluginWebFixtureUITests` is an opt-in local HTTPS test. `Tests/plugin_web_fixture.py` serves real WebUI assets from an existing checkout, only synthetic in-memory APIs, and a synthetic plugin form/main screen. It never starts the Agent Zero backend or serves `usr/`. Run it with `--source /path/to/agent-zero --cert /path/to/test-cert.pem --key /path/to/test-key.pem --port 18447`, using a disposable simulator-trusted certificate for 127.0.0.1. TLS handshakes run in request workers so speculative WebKit connections cannot stall the listener. The test requires the fixture identity and otherwise skips; there is no fallback to a user server. Do not commit certificates, keys, raw xcresults or logs.

Current run results and remaining acceptance gates are recorded in `ACCEPTANCE.md`. Physical-device, real plugin installation and production plugin compatibility remain separate gates. No release, commit, push or server modification is implied by local verification.

## Representative evidence

The local fixture runs exercise the actual WebUI shell and `fetchApi`, with in-memory synthetic settings/actions. They are separate from native lifecycle tests, which use `PreviewHTTPTransport`; no real Git installation hooks were run.

- [Native Hub after installation](evidence/plugins/native-hub.png)
- [Native scoped activation](evidence/plugins/native-activation.png)
- [Unconfirmed native command](evidence/plugins/native-uncertain.png)
- [Embedded settings](evidence/plugins/embedded-settings.png)
- [Interactive embedded main screen](evidence/plugins/embedded-main.png)
- [Embedded state cleared after background](evidence/plugins/embedded-background-cleared.png)

Bootstrap runs once for the initial `/index.html` navigation, with an exact-origin check and verification that the document is the authenticated Agent Zero shell. Unexpected HTML and later document replacements show native recovery instead of keeping a blank, supposedly ready screen. The screen startup deadline is 60 seconds to accommodate multiple waves of shell/module/component loading. Bootstrap failures and startup timeouts have separate recovery messages; no action is retried. On iOS 18 and later, plugin sheets use page sizing to leave room on iPad; the iOS 17 fallback uses a large sheet.


## Plugin artwork and collections

Custom and Built-in use the server's `is_custom` flag and search within the selected collection. Plugin Hub retains its Installed/Updates/category filters. All three collections and plugin details show artwork when available, with a puzzle-piece fallback for absent or failed images.

Installed artwork accepts only `/plugins/<validated-id>/webui/thumbnail.<raster-extension>` from `thumbnail_url`, fetched with the active session and no redirects. Hub uses `thumbnail`, or the WebUI-compatible GitHub `main/thumbnail.png` fallback. Public artwork uses the existing credential-free `ImageDownloads` client, with public-host checks, no redirects and a 4 MiB limit; server artwork has the same byte limit. Decoding rejects oversized pixel dimensions and downsamples to 384 pixels off MainActor. Rendering is fenced to the active connection and foreground, and decoded state clears on disappearance.

- [Custom plugins with thumbnails](evidence/plugins/custom-thumbnails.png)
- [Built-in plugins with thumbnails](evidence/plugins/builtin-thumbnails.png)


## Dev Tunnels browser handoff

For an already authenticated `*.devtunnels.ms` origin, the initial WebKit request and same-origin fetch requests carry `X-Tunnel-Skip-AntiPhishing-Page: true`, following [Microsoft's documented app-request behavior](https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/security#anti-phishing-protection). The header skips the browser notice only; it does not grant tunnel access or replace Agent Zero authentication. It is not added to external requests or lookalike domains. Browser sessions remain ephemeral, and TLS, origin, cookie and CSRF checks remain intact.

Before importing the shell, the host verifies its authenticated runtime marker and chat-panel container. An interstitial must not be initialized as if it were the application. A later main-document navigation invalidates the plugin presentation and offers explicit reopening; it never automatically repeats a plugin action. The disposable fixture mirrors `/` as the real splash and `/index.html` as the real shell, and asserts zero splash navigations. It tests unexpected HTML, explicit recovery, document replacement, settings save/reload, main actions and a single rejected request.

Plugin screens can also hand off to the shared [Workspace canvas and siderail](WORKSPACE.md); the host keeps that browser session alive while the selected surface opens.

Installed card controls: [enable switch](evidence/plugins/card-switch.png), captured with synthetic plugin metadata.
