# Native generated replies

## Purpose
Adapt explicit Agent Zero response payloads to the pinned A2UI Swift SDK and the local mobile catalog.

## Ownership
- GeneratedContent recognizes explicit response fences or kvps metadata and preserves prose.
- GeneratedDocument validates the complete snapshot, including intermediate graphs, before SDK processing.
- GeneratedSession owns surface replacement/disposal and reviewed action envelopes.
- RichComponents owns forecast, chart, carousel DTOs and public-URL policy.
- ExpandedComponents owns Metric, DataTable, Timeline and Checklist DTOs and bounds; Checklist reuses reviewed native form actions.
- ImageDownloads owns isolated, bounded raster downloads and DNS preflight.
- GenerativeGuide and GenerativeChatAPI own opt-in capability guidance on ordinary explicit sends.
- JevCandidates owns explicit candidate-envelope recognition, local eligibility and minimized provider projection. JevClient owns isolated bounded TypeSafe Choice transport. JevSettingsStore owns profile-scoped consent/key operations through a dedicated credential backend. JevAttemptJournal and JevCoordinator own durable one-attempt admission and stale-result rejection.
- App owns trusted rendering, review, draft insertion, Settings and image decoding.

## Local Contracts
- Pin the SDK revision and resolved dependencies. Do not modify vendored SDK code.
- Only response entries may activate UI. Accept one complete bounded surface; do not accumulate deltas across replies.
- Validate surface/catalog/component identities, typed properties, references, graph expansion and JSON limits before SDK state changes. Reject functions, implicit model sharing and generic remote media.
- A replacement invalidates previous actionable state; identical snapshots preserve local form edits. No surface crosses chat/profile/log-epoch boundaries.
- Actions expose only declared context, require local review, then append without sending or replacing the draft.
- Forecast/chart data and image URLs come from the agent. Never infer live values from the synthetic examples.
- Only the carousel downloads media. Use a separate ephemeral session with no cookies, credentials, redirects or persistent cache, raster MIME/size limits and bounded thumbnails. DNS preflight is not a network sandbox.
- Capability instructions ride on the same explicit send, preserving context/message IDs and queued status. Collapse only the exact client-owned suffix in presentation.

- Optional Jev only selects original locally validated candidates. Markdown remains available; provider output cannot add data or actions. Keep keys in the dedicated device-only credential service, separate from server auth. Persist a minimal attempt before POST and never replay interrupted attempts. Do not log candidate descriptions or provider bodies.

## Work Guidance
Keep native catalog properties synchronized with GenerativeGuide, tests, App/GeneratedCatalog.swift and docs/GENERATIVE-UI.md. Maintain Markdown fallbacks and inspectable rejected data. Never log payloads or form values.

## Verification
Run swift test --enable-code-coverage; A0GenerativeUITests covers recognition, validation, lifecycle, actions, guidance and transport. Run GenerativeUITests and JevUITests native flows for form review, rich views, source confirmation, Settings, candidate selection/fallback and large-text server-theme rendering. Keep the transcript bottom anchor outside lazy row estimation so tall generated surfaces remain scrollable. Physical/simulator synthetic success is not live generation acceptance.

## Child DOX Index
None.
