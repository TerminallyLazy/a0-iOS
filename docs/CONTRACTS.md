# Verified transport contracts

## Authentication and networking

| Operation | Request | Accepted response | Failure handling |
| --- | --- | --- | --- |
| Bootstrap | GET `/api/csrf_token`, same-origin Origin | JSON `ok`, `token`, `runtime_id` plus session cookie | Same-origin `/login` redirect starts login; proxy HTML and remote redirects rejected |
| Login | POST `/login`, form `username`, `password` | Same-origin redirect followed by successful protected bootstrap | HTTP 200 login HTML is failure; no automatic redirect or credential replay |
| Poll | POST `/api/poll`, JSON StateRequest, session cookie + X-CSRF-Token | Snapshot DTO | 401/login redirect or 403 clears security state |
| Socket | Engine.IO 4 `/socket.io/`, Socket.IO namespace `/ws` | `state_request` ack and `state_push` | Failed handler/ack falls back to HTTP polling in app |

Release: HTTPS, platform certificate validation. Debug local-development mode permits HTTP only for exact loopback hosts. The unauthenticated bootstrap exception is restricted to that explicit loopback policy. Session and CSRF cookies are still required. HTTP cookies are held per APIClient with automatic URLSession cookie handling disabled.

Subscription uses `handlers: ["ws_webui"]`; ack handler IDs are Python class identifiers (`ws_webui.WsWebui`, or normal-import `api.ws_webui.WsWebui`). They are not the subscription path. Ack correlation, handler success, runtime epoch and integer sequence baseline are mandatory.

`forceFull` is not a server field. A full request zeroes both cursors. The `state_request` acknowledgement establishes `seq_base` and the first push increments it. Push data has `runtime_epoch`, `seq`, `snapshot` inside the standard event envelope. Poll returns a plain snapshot.

## Reduction

Log entries replace by `no`; nullable collections retain previous state while empty arrays clear it. Full resync replaces logs/notifications. GUID/version regressions, sequence discontinuities and runtime changes require full sync. A selection creates a generation and old HTTP responses are discarded. Handshakes are serialized and the latest context request is coalesced while one is pending.

## Evidence provenance

`source-receipt.json` hashes the inspected checkout at HEAD `6a6cecff`. `live-runtime-receipt.json` identifies the actual container selected by the user; its HEAD is different. Client fixtures are synthetic data authored from inspected contracts, not captured user conversations. Live checks inspected a null-context state stream; they did not open or modify an existing chat.
