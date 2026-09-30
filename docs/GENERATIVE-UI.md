# Native generated replies

Agent Zero iOS uses [A2UI-Swift](https://github.com/BBC6BAE9/a2ui-swift) for native SwiftUI rendering, pinned to commit `16476ba2cb3fcb4c4bcb141dfa4c2804adbdedb0`. Tag 0.3.5 cannot resolve as a stable SwiftPM dependency because it references swift-foundation-icu by revision. The pinned upstream fix removes that dependency in favor of Foundation plural rules. Package.resolved records swift-json-schema 0.13.2, swift-collections 1.7.1 and swift-syntax 604.0.0; Socket.IO pins stay unchanged.

## Using it

Rich replies is enabled by default in Settings. Each explicit Send includes the native catalog guidance with the same request, preserving queue/message IDs and delivery handling. No extra bootstrap message is submitted. The user’s message stays separate from the exact client-owned suffix in the native transcript, with a Rich reply instructions disclosure. Turn Rich replies off for future plain requests. The setting does not erase previous instructions already in server conversation history. Settings → Generative UI also provides copyable instructions for manual server configuration; copying never sends or changes the server. `GenerativeGuide.instructions` is the exact in-app producer contract and `GenerativeGuide.example` is an executable synthetic example.

An assistant response carries one self-contained array of v0.9/v0.9.1 messages in a fenced `a2ui` block. An integration may instead put the array in `LogEntry.kvps.a2ui`. Only response entries opt in. Prose stays visible, user/tool JSON stays ordinary text, and code examples nested inside other fences do not activate a renderer. No new endpoint, A2A service, provider key or backend patch is required. Existing authenticated poll and Socket.IO snapshots carry these logs unchanged.

The app renders Text, Row, Column, Card, Divider, Button, TextField, CheckBox, ChoicePicker and Slider, plus trusted Forecast, ImageCarousel, Chart, Dashboard, Metric, DataTable, Timeline and Checklist components under `agent-zero:mobile:v1`. The basic SDK catalog remains accepted for standard components. Forecasts show agent-provided values, units, update time, daily outlook and source; charts use native Swift Charts line/bar/area plots with readable values; carousels show up to 10 images, captions, paging and original source links. Dashboard lays children out responsively. TextField is mapped locally to A0TextField for persistent labels and contrast; server-defined custom components are not allowed. Binding paths are absolute JSON pointers. Layout children are explicit arrays, with a `root` ID. Each reply contains its complete surface state (create, component/data updates and optional final delete); deltas across separate replies are not supported. An incomplete fenced block shows a receiving state. Changed source replaces the surface atomically and cancels an outstanding action review; repeated identical snapshots retain local input values. Local input is transient and is not restored after leaving the conversation.

A button resolves only its declared action context, then opens Review response. Cancel changes nothing. Add to draft appends an `a2ui-action` JSON envelope without overwriting text or sending it. The user then uses the normal Send flow, with existing protected persistence and uncertain-delivery behavior. No full form/data model is shared implicitly. The resulting envelope is plain user-message content for Agent Zero to interpret, not a separate server action API or proof of execution.

## Boundary and failure behavior

Payloads are limited to 64 KiB, 32 messages, 64 component definitions, 12 layout levels and 128 expanded nodes; choice lists allow 32 options. JSON depth/string/array bounds and bounded array indices prevent expensive or unsafe model expansion. Component references, cycles, duplicate IDs, versions, catalog, property types and slider ranges are checked before the SDK receives data. Actions are limited to 16 KiB.

Generic remote media, custom server-defined components, themes, functions, expressions, checks/regex, templates and sendDataModel are not enabled. Only ImageCarousel can load images: a separate ephemeral cookie/credential-free URLSession, public HTTPS hostname checks and DNS preflight, no redirects, allowlisted raster MIME types, 4 MiB response cap, bounded memory cache and 1200-pixel ImageIO thumbnails. DNS preflight is not a network sandbox or a guarantee against DNS rebinding. No account cookies, CSRF or authorization headers are shared with image hosts. Failed images show Retry and keep their source link. Downloads stop with view/background cancellation; caches are memory-only. The local catalog has no functions. Native message-link confirmation covers generated text links. Unsupported or malformed payloads show an explanation with optional interface-data inspection; they never retain a previously actionable surface. No response bodies or form values enter logs. Transcripts and unsubmitted form edits are not persisted; explicitly reviewed values added to the draft use the existing protected draft store.

## Ownership and verification

Sources/A0GenerativeUI owns recognition, bounded validation, SDK surface state, action envelopes and producer instructions. App/GeneratedReplyView.swift owns the native surface, review, keyboard dismissal and setup page. The conversation owns draft insertion and lifetime. Its delivery area and bottom anchor remain outside the lazy message stack to keep tall generated replies scrollable. GenerativeChatAPI decorates the existing API only at an explicit Send; immediate and queued paths have the same capability suffix. New custom layouts and image transport do not modify the Agent Zero backend. No SDK source is vendored or edited. Upstream licensing remains in the package checkout (MIT repository license and Apache-2.0 notices in relevant source files).

See `docs/tdd/generative-ui/` for recorded resolution failure, red tests, focused green tests and device/simulator results. Synthetic rendering and transport checks do not prove a live model emitted a compliant payload.

## Expanded catalog

These components use the same `agent-zero:mobile:v1` catalog and work with ordinary `a2ui` replies as well as Jev candidates. `GenerativeGuide.expandedExample` is a complete executable example.

| Component | Situations | Properties and limits |
| --- | --- | --- |
| Metric | Counts, totals, progress summaries | title, display value, optional unit/change/trend (`up`, `down`, `neutral`) and sourceURL |
| DataTable | Comparisons, inventories, results | title, 1–6 unique column labels, 1–50 rectangular rows; responsive grid, stacked cells at accessibility sizes or for wider tables on a phone |
| Timeline | Plans, itineraries, milestones | title, 1–30 unique items with id/title and optional time/detail/state (`pending`, `current`, `complete`) |
| Checklist | Packing, preparation, task review | title, 1–20 CheckBox children and at most one review Button; existing bindings and reviewed-action flow |

Optional source links use the existing public HTTPS validation and destination confirmation. Values and status come from the agent; the app does not verify their truth or infer execution success. Combine these components in a Dashboard or Column with existing forecasts, charts, carousels and forms.

## Optional Jev selection

Settings → Generative UI accepts a masked `TYPESAFE_API_KEY`. Save stores it in a dedicated device-only, when-unlocked Keychain service for the active server profile. Saving or replacing a key leaves Jev off; enable Use Jev separately. Removal deletes the record. No key enters Agent Zero messages, UserDefaults, WebViews or diagnostics.

With Rich replies and Jev enabled, an explicit Send advertises a versioned `a2ui-candidates` envelope: readable prose outside the fence, bounded intent, and 1–4 candidates with unique IDs, short descriptions and complete native surfaces. The aggregate JSON limit is 64 KiB. Each candidate passes local validation before eligibility; Markdown is always an additional choice. Historical replies are not evaluated merely by opening a chat.

The app sends one isolated POST to [TypeSafe System One](https://docs.typesafe.ai/api), pinned to `jev-1.13.0`. Only intent, candidate IDs, descriptions and component-type summaries are projected. Surface properties, measurements, URLs, form input, attachments, full conversation history and server identity are excluded. Descriptions can still reveal private information, as disclosed before opt-in. Requests use the user's API quota; they are not part of Agent Zero provider billing.

An atomic minimal attempt record precedes the call. Duplicate, interrupted and failed attempts never automatically replay. The journal stores hashed identities, request digests, timestamps and receipt IDs, not keys or content; retention is 30 days with a 2,048-record cap. Requests have a five-second timeout, an 8 KiB request cap and a 64 KiB response cap, with no redirects, account cookies or app-level retries. Selection returns only an eligible ID; rendering uses the original locally validated surface. Failure, Markdown choice or stale scope keeps the readable prose. Profile/chat/epoch changes and backgrounding cancel pending selection and clear transient selected surfaces; ordinary A2UI replies remain independent.

The earlier [experiment](experiments/jev-a2ui/README.md) is historical feasibility evidence. The user-approved device-key architecture supersedes its server-only proposal. See [TDD evidence](tdd/jev/README.md) for synthetic verification and remaining live-provider/device acceptance gaps. Future distribution must review the optional external data flow against release privacy disclosures.
