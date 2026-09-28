# Saved server profiles and optional Keychain sign-in

September 28, 2026. Continues manual onboarding/profile and authentication work from [PLAN.md](../../PLAN.md).

## Behavior and ownership

`Sources/A0Core/Profiles.swift` owns saved-profile metadata, protected atomic profile-file storage, credential-store interfaces, and profile/credential operations. `App/KeychainCredentialStore.swift` owns Security.framework calls. `SpikeModel` coordinates verified login, profile selection, generation fencing, and disconnect; `ServerConnectionSection` owns the native form and profile actions.

Profiles are keyed by validated server origin and username. Names are display labels. Metadata is saved only after successful API authentication. Selecting a profile loads its exact credential if available, but makes no network connection. Editing origin/username clears the password and the remember option. Connection requires an explicit action. Asynchronous selection is generation-fenced.

Password saving defaults off. An enabled option saves only after successful sign-in. Turning it off applies after the next successful sign-in; the dedicated Forget action removes a stored password immediately. No passwords, cookies, or CSRF tokens are written to JSON, UserDefaults, logs, or fixtures containing real user data.

| Action | Connection | Metadata | Saved password | Local drafts / uncertain receipts |
| --- | --- | --- | --- | --- |
| Disconnect/background | Closed; active cookie jar and password field cleared | Kept | Kept if previously opted in | Kept |
| Forget saved password | No automatic connection | Kept | Removed for exact origin/username | Kept |
| Remove saved server | Available while disconnected | Removed after confirmation | Removed first; metadata retained if credential removal fails | Kept |
| Select saved server | Explicit Connect still required | Loaded | Looked up only for selected identity | Loaded after sign-in |

Keychain uses a SHA-256 profile account identifier, app-local service, nonsynchronizable generic-password items, and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Apple's [accessibility contract](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly) limits access to unlocked devices and prevents migration to another device. Physical-device enforcement is not established by simulator success. Item updates use SecItemUpdate with SecItemAdd fallback, avoiding delete-before-replace. Errors are sanitized; no plaintext fallback exists.

## TDD evidence

- `red.log`: new `ProfileTests` compiled against missing `SavedProfile` / credential interfaces before implementation.
- `green.log`: `swift test --enable-code-coverage` — 64 tests pass, including prior persistence/auth/delivery tests.
- Core guarantees: metadata survives reopening without passwords; upsert by identity; exact-account/host opt-out; password forgetting and profile removal; unavailable credential store does not silently remove metadata; corrupt/future-version metadata remains protected; disk write failure leaves the last committed in-memory metadata intact.
- `ui-red.xcresult`: three new native profile journeys failed on missing profile controls before implementation.
- First UI implementation run was not GREEN. Status-only diagnostics showed the test tapped the Toggle accessibility wrapper without enabling its inner native switch; no Keychain save was requested. Corrected test explicitly targets the native switch and asserts opt-in, then scrolls to the relevant form state. This is a harness correction, not a Keychain workaround. A redundant-identity-write guard was added during investigation. Temporary diagnostic logging was removed before final verification.
- `keychain-native-control.xcresult`: real simulator Keychain add/read/update across termination and explicit reconnect passed. The app uses Security.framework, not a mock Keychain for this journey. Network authentication is synthetic.

`ProfileTests.swift` supplies unit/integration guarantees. `ProfileUITests.swift` covers opt-in across relaunch, default opt-out, identity editing, forgetting, and removing a profile. A background-before-connect regression was added after review: `background-red.xcresult` shows a typed password remained in its secure field after background/foreground. `suspend()` now clears both typed and loaded passwords and invalidates pending profile reads before connection as well.

`ui-complete.xcresult` initially passed nine of ten flows; profile removal was checked before its asynchronous operation completed. The test now waits for the visible completion message and verifies removal after relaunch. All three profile flows then passed in `ui-profiles-final.xcresult`.

UI tests use unique metadata directories and Keychain service namespaces with synthetic credentials; they do not access owner-managed credentials. No dependency installation, Git commits/pushes, signing changes, or server modifications were made.

The existing workspace is not a Git repository; RED/GREEN evidence is retained in logs and result bundles rather than checkpoint commits.

## Final verification

- `ui-final.xcresult`: **11 passed, 0 failed, 0 skipped** on iPhone 18 Pro / iOS 27 (225.2 seconds), including all seven prior chat/recovery flows and four profile/password flows. Background-before-connect is now GREEN.
- `core-coverage.json`: **A0Core 625/666 lines (93.8%)** under SwiftPM; `Profiles.swift` 65/66 (98.5%).
- `ui-final-coverage.json`: **app target 1,057/1,114 lines (94.9%)** under simulator UI tests. This is app coverage, not realtime-package or live-network coverage; the UI suite uses synthetic HTTP transport.
- `release-build.log`: SwiftPM Release build passes. `ios-release-build.log`: unsigned Release simulator build passes. Debug compiled and ran the full simulator suite. One existing nested weak-self capture warning remains in `SpikeModel`'s realtime callback; these are successful builds, not warning-free builds.
- iPhone saved-profile form visually inspected in `profile-screenshots/3FD61E06-C137-40F7-9899-56B27BC183C5.png`: labels wrap, native switches remain separate from actions, the saved-password state and explicit Connect are visible. No new iPad visual acceptance is claimed for this slice.
- `AGENTS.md`, README, plan status, and acceptance ledger updated to match implementation and retention behavior.

## Remaining acceptance boundaries

QR scanning, automatic reconnect, physical-device locked/unlocked Keychain behavior, authenticated remote HTTPS, live message mutation, and distribution remain pending. The prior local read-only transport receipt is not a live credential-storage acceptance test. The established SwiftUI, actor-persistence, and Impeccable hardening guidance informed this scoped native form; no broad visual redesign or new UI dependencies were introduced.
