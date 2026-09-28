# Agent Zero iOS

A native iPhone and iPad companion for an existing, authenticated Agent Zero server. The user connects through an HTTPS origin or tunnel and keeps server credentials private. Primary work is opening conversations, sending messages, reading streamed replies and inspecting agent activity.

## Confirmed direction

Use Agent Zero's actual logos and WebUI palette with native SwiftUI navigation and accessibility. New chat must open a dedicated composer. Successful authenticated cold launch lands on that draft with the sidebar closed, after a branded cover for actual startup work. Existing chat drafts and uncertain receipts are retained; ordinary background/foreground preserves the open conversation. Render Markdown; collapse long messages and tool output. Follow new replies unless the user scrolls into history or expands content to read; provide an explicit return to latest.

## Boundaries

Drafts and unresolved delivery receipts stay on the device; transcripts are not persisted. Password retention is optional and uses Keychain. Never automatically replay an uncertain send. Tunnel QR import reviews an HTTPS destination before explicit sign-in. This app connects to a tunnel; it does not provision one.

The implementation supports chat, search, readable Markdown, copy, collapse, local drafts, secure session restoration, native generated replies, a chat drawer, native project management, server-reported context usage and per-agent activity. The composer provides native model preset selection/editing, direct on-device dictation into the draft, a context meter and a compact tools popover with native photo/file attachments and Pause/Resume, Nudge, History and Context. Native project settings include instructions, file-structure preferences, variables, project MCP JSON and opt-in masked-secret edits. Project file management, knowledge, memory, skills, project-scoped preset selection, provider credentials, broader MCP administration, goal mode and terminal remain available through a confirmed full-WebUI handoff. Full native WebUI parity is not claimed. Screenshots and automated tests use authored synthetic data; the owner confirmed physical iPhone dictation in the prior voice interaction. The new inline-composer flow, continuous listening and live server controls have separate acceptance boundaries. Continuous listening is remembered locally but activation and Send remain explicit. Routine saved-state copy stays out of the composer while storage failures remain visible.

Shared model definitions can be created, edited, renamed, removed or reset natively; these changes affect every server chat/project using them. The composer selector applies only a current-chat override and can restore inheritance. The interface must distinguish these scopes.

## References

Agent Zero WebUI is the primary identity and interaction reference. Goose mobile is a secondary reference for its growing composer, activity disclosures, sessions and tunnel onboarding; no Goose code or assets are incorporated.

## Chat usability refinement

The user requested cleaner tool calls, native handling of icon:// markers, an explicit keyboard minimize action and Settings. Settings now owns local appearance, long-message collapse and activity-group preferences, connection information and changing servers. It preserves existing authentication/Keychain behavior; it is not a server configuration editor. Tool metadata is summarized with SF Symbols, and raw structured events remain optional details.

## Generative replies

Explicit A2UI replies render native forecasts, image carousels, charts, responsive dashboards, forms and cards alongside Markdown. Rich replies advertises the catalog automatically with each explicit send and can be disabled in Settings. Generated actions are reviewed locally, appended to the existing draft and sent explicitly. Settings provides producer instructions. The client supports a bounded native catalog, not remote HTML or executable UI. ImageCarousel uses a separate bounded image downloader; all values and source links come from the agent.

Browser capture cards remain visible in collapsed activity and open a bounded larger popover. The composer carries a text-free trailing connection dot; its accessible popover explains connection state and recovery. See docs/CHAT-MEDIA.md.
