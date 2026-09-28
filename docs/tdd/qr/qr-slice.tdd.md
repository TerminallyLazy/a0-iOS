# QR server onboarding — TDD slice

September 28, 2026. Implements the QR/manual onboarding item of Milestone 1. Full milestone acceptance remains open.

## Contract and scope

The inspected Agent Zero source `webui/components/settings/tunnel/tunnel-store.js:176` puts `tunnelLink` directly into the QR code. The app accepts that plain HTTPS origin format; it does not invent a JSON pairing envelope or import credentials. This is source-contract evidence, not a fresh live tunnel/device acceptance receipt.

`A0Core/QRImport.swift` owns pure validation and transient review state. `QRImportView` owns native entry/review, permission requests, cancellation, and identity-safe form application. `QRCodeScanner` wraps Apple's VisionKit controller, requests only QR recognition, starts after presentation, and stops on result, failure, disappearance, or dismantling. The camera usage explanation is generated from `project.yml`. No additional dependency or backend change is needed.

The scanner uses Apple's [documented camera data-scanning APIs](https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera) and checks supported/available status plus camera authorization. Permission is requested only from Open camera. Camera images are not stored or uploaded by this implementation. The app has no new microphone or photo-library permission.

Import is deliberately separate from the active connection form:

1. Scan or enter an address.
2. Validate a plain ASCII HTTPS origin (maximum 2,048 UTF-8 bytes after trimming surrounding whitespace). Require punycode for international domains. Reject credentials, non-root paths, queries, fragments, escapes, embedded whitespace/control characters, other schemes, and malformed ports. Do not echo rejected payloads into diagnostics or errors.
3. Show the normalized full destination for comparison with the server. No network request, Keychain lookup, or persistence occurs.
4. Use this server clears previous account/password/name/remember state and the Debug local-development option, then fills the origin. Credentials and explicit Connect follow. Existing server profiles and drafts remain unchanged.

Cancel preserves the connection form. Backgrounding clears transient import state and cancels the permission task; a later permission result cannot reopen the camera. Scan generations reject stale/duplicate results. Camera denied/unavailable states offer manual entry; denied access also has an explicit Settings link. The simulator debug overrides affect camera outcomes only when the isolated profile-test mode is enabled.

## RED → GREEN evidence

| Guarantee | Test / RED evidence | GREEN evidence |
| --- | --- | --- |
| Safe plain HTTPS origin and rejection boundaries | `QRImportTests.swift`, `red.log`: missing QR destination/review types before implementation | `green.log`: 70 core tests pass; 15 unsafe payload cases and both camera errors parameterized |
| Duplicate/stale scan suppression, cancel, one-time confirmation, error recovery | Pure review-state tests in the same RED run | Core tests pass, QRImport.swift line coverage 100%, region coverage 92% |
| Native import and cancel preserve the form | `ui-red.xcresult`: missing Scan server QR and address-entry controls | `ui-first.xcresult`: all four QR UI journeys pass |
| Confirmation clears previous credentials without connecting; camera denied/unavailable recover through manual entry | `QRImportUITests.swift` authored before the UI implementation | Same four native flows, using isolated synthetic app state |

Core coverage: **664/705 lines (94.2%)**, `core-coverage.json`. Raw RED/GREEN logs and result bundles are retained. The workspace is not a Git repository; no checkpoint commits or pushes were made. The UI implementation preserves the established native form/sheet design and uses the requested ECC, SwiftUI Expert, swiftui-skills, and Impeccable guidance.

## Final verification

- `ui-final.xcresult`: **15 passed, 0 failed, 0 skipped** on iPhone 18 Pro / iOS 27, including all 11 prior chat/profile/recovery flows and four QR onboarding flows (270.7 seconds).
- `ipad-review.xcresult`: destination confirmation and credential clearing also pass on iPad Pro 13-inch (M5) / iOS 26.5 (one selected test; 24.0 seconds).
- `ui-coverage.json`: **app target 1,445/1,601 lines (90.3%)**. The core library's separate SwiftPM coverage is 94.2%. Camera capture/controller delegate execution remains unmeasured on hardware; app-wide coverage is not camera acceptance.
- `release-build.log`: SwiftPM Release build passes. `ios-release-build.log`: unsigned iOS Release simulator build passes. Debug compiled and executed the simulator tests.
- Remaining build warnings: the existing nested weak-self realtime callback capture; iPad test runner also reports a future all-orientations requirement. Neither is represented as a new camera/runtime failure or a warning-free release.
- One batched visual inspection of both native device classes: the full review destination, explanation, cancel, confirm, and change-address actions are visible without clipping. No visual correction pass was needed. Screenshots: [iPhone review](iphone-screenshots/85A81BC8-4892-4A29-B9D4-720B69F9F08D.png), [iPad review](ipad-screenshots/6C65C0E7-F03A-4A24-BC04-CECF7D7922C0.png).

## Acceptance limits

Physical camera capture, system permission prompts, camera restrictions/interruption, real QR recognition, lock/unlock behavior on hardware, and authenticated HTTPS server acceptance remain pending. The simulator camera-error tests use explicit Debug-only denial/unavailable outcomes, not actual OS permission revocation. Manual entry/review uses the same parser as camera payloads. No live server mutation, signing/distribution, or new dependency installation occurred.
