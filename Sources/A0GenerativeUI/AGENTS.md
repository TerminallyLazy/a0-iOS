# Native generated replies

## Purpose
Adapt explicit Agent Zero response payloads to the pinned A2UI Swift SDK and the local mobile catalog.

## Ownership
- GeneratedContent recognizes explicit response fences or kvps metadata and preserves prose. ReplyMediaPreview discovers up to four unique supported public HTTPS file links in bounded ordinary response prose, without any request or generated action.
- GeneratedDocument validates the complete snapshot, including intermediate graphs, before SDK processing.
- GeneratedSession owns surface replacement/disposal and reviewed action envelopes.
- RichComponents owns forecast/carousel DTOs and public-URL policy. ChartContent owns bounded chart semantics; MediaContent and MediaDownloads own native audio/video validation and isolated temporary-file downloads.
- ExpandedComponents owns Metric, DataTable, Timeline and Checklist DTOs and bounds; Checklist reuses reviewed native form actions.
- ImageDownloads owns isolated, bounded raster downloads and DNS preflight.
- GenerativeGuide and GenerativeChatAPI own opt-in capability guidance on ordinary explicit sends.
- JevCandidates owns explicit candidate-envelope recognition, local eligibility and minimized provider projection. JevClient owns isolated bounded TypeSafe Choice transport. JevSettingsStore owns profile-scoped consent/key operations through a dedicated credential backend. JevAttemptJournal and JevCoordinator own durable one-attempt admission and stale-result rejection.
- App owns trusted rendering, review, draft insertion, Settings, image decoding and reply-scoped AVKit playback.

## Local Contracts
- Pin the SDK revision and resolved dependencies. Do not modify vendored SDK code.
- Only response entries may activate UI. Accept one complete bounded surface; do not accumulate deltas across replies.
- Validate surface/catalog/component identities, typed properties, references, graph expansion and JSON limits before SDK state changes. Reject functions, implicit model sharing and generic remote media.
- A replacement invalidates previous actionable state; identical snapshots preserve local form edits. No surface crosses chat/profile/log-epoch boundaries.
- Actions expose only declared context, require local review, then append without sending or replacing the draft.
- Forecast/chart data and image URLs come from the agent. Never infer live values from the synthetic examples.
- Carousel images and explicitly loaded AudioPlayer/Video files use separate ephemeral sessions with no cookies, credentials, redirects or persistent cache, allowlisted raster/audio/video MIME types, size limits and bounded thumbnails/files. Media never autoplays; AVKit receives a local file with external references forbidden, and stops/releases on background, disappearance or source change. DNS preflight is not a network sandbox.
- Remap AudioPlayer/Video to local A0-prefixed custom components before SDK processing; built-in SDK players must never receive these requests.
- Plain reply media previews accept at most 128 KiB of response text and 2,048 bytes per URL. Explicit A2UI/candidate presence takes precedence even when incomplete or invalid. Exclude raw JSON, code, quotes, HTML, images and reference definitions. MP3/M4A/AAC/WAV/MP4/MOV path extensions only identify an invitation to Load; existing MIME, size, DNS and playable-track checks still decide acceptance. Preserve source prose and confirmed links.
- Read-only generated views disable form inputs and event buttons individually, retaining explicit media loading and passive inspection. The draft-action callback remains independently guarded; never enable server actions or automatic draft insertion.
- First-message model preset application passes unchanged through GenerativeChatAPI before sending; capability guidance never replaces or bypasses that operation.
- Capability instructions ride on the same explicit send, preserving context/message IDs and queued status. Collapse only the exact client-owned suffix in presentation.
- Host-targeted sends retain the same host selection/generation and delivery IDs
  through `GenerativeChatAPI`; optional reply guidance never changes the route.

- Optional Jev only selects original locally validated candidates. Markdown remains available; provider output cannot add data or actions. Keep keys in the dedicated device-only credential service, separate from server auth. Persist a minimal attempt before POST and never replay interrupted attempts. Do not log candidate descriptions or provider bodies.

## Work Guidance
Keep native catalog properties synchronized with GenerativeGuide, tests, App/GeneratedCatalog.swift and docs/GENERATIVE-UI.md. Maintain Markdown fallbacks and inspectable rejected data. Never log payloads or form values.

## Verification
Run swift test --enable-code-coverage; A0GenerativeUITests covers recognition, validation, lifecycle, actions, guidance and transport. Run ChartMediaUITests for chart styles, readable values, explicit media load/play/seek, cancellation and background teardown. Run GenerativeUITests and JevUITests native flows for form review, rich views, source confirmation, Settings, candidate selection/fallback and large-text server-theme rendering. Keep the transcript bottom anchor outside lazy row estimation so tall generated surfaces remain scrollable. Physical/simulator synthetic success is not live generation acceptance.

## Child DOX Index
None.
