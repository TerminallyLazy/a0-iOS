# Native model presets

## Ownership and scope

`Sources/A0Core/ModelPresets.swift` owns typed documents, inheritance projections, bounded result validation and authenticated requests to `/api/plugins/_model_config/model_presets` and `/api/plugins/_model_config/model_override`. `App/ModelPresetWorkspace.swift` owns transient collections, generation/context fencing, conflict checks and shared ControlReceipts. `ModelPresetPicker.swift` and `ModelPresetEditor.swift` own selection scope and explicit edits.

The composer picker shows the effective preset and Main model, expanding into provider/model rows for Main, Utility, Embedding and applicable separate Vision. It loads server-reported override eligibility and inheritance. Selecting calls `set_preset` for the current chat; Use inherited clears that override. A new-chat draft cannot set a chat override until it has a server context. The UI does not invoke the broader scoped-default `select` operation. Project/agent-profile default selection remains in WebUI.

Edit presets changes the shared server collection, not a local copy or a chat-only configuration. Add, edit, rename and remove are staged until Save shared presets; reset has explicit confirmation. Default cannot be renamed/deleted and retains Main, Utility and Embedding model identities. Removing another preset explains that references fall back to Default. Provider keys and OAuth connections use a confirmed WebUI handoff.

## Inheritance and payload preservation

Keep documents sparse. Main, Utility and Embedding use Default when a preset lacks model identity; when a slot is customized, merge the model fields for display but keep its own kwargs rather than inheriting Default's kwargs. Separate Vision is never inherited. Main's native vision takes precedence unless a separate Vision override explicitly supersedes it. Display projections must never overwrite the raw document.

Editing supports provider/model IDs, applicable context and vision settings, API base, rate limits and an explicit JSON-object editor for additional parameters. Preserve unknown fields and nested kwargs. Match server stripping only at document/model-slot top level for underscore-managed fields and `api_key`; do not recursively remove opaque provider keys inside kwargs. Changing a provider explicitly clears that slot's prior API base and kwargs. Provider credentials belong in provider settings, not the parameters editor. No preset payload is archived or logged.

## Mutation and conflict contracts

Before save or reset, fetch the current collection and compare it with the editor's original baseline. If changed, stop before mutation and tell the user to close/refresh. This is a client-side stale-editor check, not an atomic server compare-and-swap guarantee.

Persist shared ControlReceipts intent before each mutation, retain unconfirmed outcomes, and never replay automatically. Read-only refresh does not clear uncertain intent. Disable mutation if receipts cannot be read or an earlier outcome is pending. Known validation/override-disabled failures may resolve an unsent/rejected intent; storage failures preserve it. After successful changes, read the actual effective selection rather than predicting inheritance. Fence every result to the account generation and chat; dismiss and discard editor state on background or owner changes.

## Verification boundary

Source and synthetic UI tests cover protocol, inheritance, field preservation, current-chat scope and native editing. Exact final combined results belong in the acceptance/TDD receipts; native UI availability is not proof of live provider generation or global-setting acceptance. No provider credentials are needed in fixtures.
