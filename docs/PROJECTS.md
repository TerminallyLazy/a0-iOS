# Native projects and context accounting

## Ownership

- `Sources/A0Core/Projects.swift` owns project summaries, lossless in-memory edit documents, typed operations and `/api/projects` request/result validation.
- `App/ProjectWorkspace.swift` owns loading, generation fencing, mutation receipts and create-chat-plus-assign coordination.
- `App/ProjectsView.swift` and `ProjectEditor.swift` own list/detail/editor flows and destructive confirmation; `ProjectDot.swift` and `ProjectChatFilter.swift` carry server colors and filtering into chat navigation.
- `Sources/A0Core/ContextUsage.swift` and `App/ContextUsageView.swift` own read-only server accounting and its compact composer popover.

## Native scope

Projects opens from the root list, Workspace drawer or conversation project label. The list searches title and description, shows server colors, and marks the project active in the current chat. Chat filters select a project or All projects; invalidated selections clear when the project is no longer present.

Create and Clone repository edit title, folder name, description, color, instructions and AGENTS.md inclusion. Existing projects also expose file-structure settings/preview, variables, MCP JSON and opt-in masked-secret editing. The editor preserves fields it does not own. The bottom safe-area Create/Clone/Save action remains separate from Cancel and is disabled while invalid, unavailable or busy. Project details offer new chat, assign/remove current chat and existing project chats.

Deletion requires typing the exact folder name and explains that the whole server-side folder, its files/settings and assignments to every chat are removed. A project is not a local bookmark. File management, knowledge, memory, skills and project-scoped preset selection remain WebUI functions: the native handoff confirms the HTTPS origin and tells the user which project to select. It does not claim a deep link or full native parity. Shared preset definitions and per-chat overrides are separately available through the native composer picker; see [Model presets](MODEL_PRESETS.md).

## Mutation and privacy contracts

Use the authenticated APIClient with existing CSRF/Origin and redirect protections. No project request is automatically retried. Validate folder names and use credential-free HTTPS Git URLs. Optional Git tokens are request-only; project documents, variables, secrets and MCP content stay in memory and never enter archives or diagnostics. Clear sensitive editor state on background and connection-generation changes. Existing masked secrets and unknown/plugin fields survive ordinary edits.

All project mutations share profile-isolated ControlReceipts with agent controls. Persist intent before sending and retain unresolved outcomes until explicitly checked. Read-only list/load/preview does not resolve an uncertain mutation. New chat in project records a generated context ID before creating and assigning it; a partial failure offers Check chat and does not replay either step. Disable mutation if the journal cannot be read or an earlier outcome remains unresolved. Ignore responses from obsolete account generations.

## Context usage

Read `/api/plugins/_context_window/context_window` with the selected context, using the existing authenticated client. Display the server's `tokens` and `context_window`; do not count transcript text. Known category buckets are Messages, System tools, Skills, MCP tools, System prompt and Extras, and a supplied breakdown must reconcile to the total. Fractions are relative to the configured window. An unavailable/zero window does not become an invented denominator; only the ring is clamped at full while the reported percentage remains truthful.

Provider input/output/cache counts are separate from the prompt estimate. Missing categories and provider values remain unavailable rather than zero. The model can decode provider cost, but the current popover does not display it. Refreshes debounce state changes and reject stale generation/context responses. A failed refresh explicitly labels any retained report as stale.

## Verification boundaries

Focused source regressions cover project request/result validation, field preservation, server accounting and the Speech permission bridge. Project UI fixtures cover native navigation and mutation affordances without altering a live server. Exact executed results belong in the acceptance/TDD receipts once the combined run completes; this document does not claim live project mutation, physical microphone acceptance or final visual approval.
