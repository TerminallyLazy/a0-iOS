# Browser captures, attachments and follow-up delivery — 2026-09-28

## Result
Browser tool captures appear in the transcript and grouped activity, with larger contained previews. Tools exposes native image/file selection and a removable local attachment tray. The composer owns a compact connection dot with status/recovery details. Send retains its enabled state during agent work and adds a motion-aware spinning ring. Settings chooses Queue (default) or immediate Steer for future explicit follow-ups.

## Contract and test-first evidence
See [browser protocol evidence](../browser-media/contract.md), [attachment RED/GREEN cycles](../attachments/attachments.tdd.md), [send-mode RED/GREEN](../send-mode/send-mode.tdd.md), and local `a0-status-red.log` / `a0-status-green.log`. The backend was read-only at revision `6a6cecff8527b164668c7a6ab2f76b6b1ed7cfa1`. No dependencies were added.

Final `swift test --enable-code-coverage` passed **173 core + 19 generated-UI tests = 192**; output is `a0-media-core-complete.log`. Executable-line coverage for new core files: Attachments 75/84 (89.3%), BrowserScreenshot 73/80 (91.3%), ConnectionIndicator 18/18 (100%), SendMode 10/10 (100%). These focused-file figures do not describe all app UI or all changed repository code. Machine-readable summary: `focused-core-coverage.json`.

## Native runs

| Retained bundle | Target | Passed tests | Scope |
| --- | --- | --- | --- |
| a0-media-phone-final.xcresult | iPhone simulator / iOS 27 | 5 | Attachment lifecycle, native Files cancel, capture/contained preview, composer status, Queue/Steer persistence |
| a0-media-device.xcresult | iPhone 15 / iOS 18.7.3 | 4 | Attachment lifecycle, capture/preview, status, Queue/Steer |
| a0-media-ipad.xcresult | iPad Pro 13 M5 / iOS 26.5, dark maximum text | 4 | Same four media/composer journeys |
| a0-media-device-confirm.xcresult | physical iPhone | 3 | Final slow-import Send gating, uncertain attachment restoration, Queue/Steer |
| a0-media-status-regression.xcresult | iPhone simulator | 2 | Realtime promotion and exhausted-read recovery through moved status popover |
| a0-media-ipad-final.xcresult | dark maximum-text iPad | 2 | Corrected filename wrapping and connection-detail layout |

All listed bundles finalized with TEST SUCCEEDED. Counts describe separate focused runs, not one fresh full UI suite. Screenshots and manifests live alongside these bundles. The physical tests use authored fixtures and never open the owner's document picker or upload owner data.

## Corrections found during verification

- Browser media scope handled optional context before the first successful native build.
- A duplicate nested synthetic attachment selector was narrowed; the earlier phone attempt completed some flows but stalled bundle finalization and is not counted as a passing run.
- Review found a delay before attachment staging could allow sending too early. An owner/token reservation now gates Send before asynchronous loading, with stale-callback and physical slow-import regressions.
- Attachment count/size checks precede unbounded import; current metadata survives delayed additions; startup pruning preserves referenced and newly staged bytes; filenames tolerate server normalization.
- Connection recovery assertions now find the moved composer indicator/popover. Retry, Close and image retry use actual 44-point labels.
- Maximum-text review found truncated short filenames and a split Polling heading. The final iPad run verifies adaptive widths and filename wrapping. The final review report is `.impeccable/review/chat-media/finish-review.md`.

## Release and acceptance limits

The signed Release build passed, installed on physical device `REDACTED_DEVICE_ID`, and launched normally outside XCTest as `local.agentzero.AgentZeroSpike`. Receipts: `a0-media-release.log`, `a0-media-install.log`, `a0-media-launch.log`.

Synthetic transport and native UI checks establish local behavior and endpoint contracts. Actual browser-tool captures, real photo/file upload processing and live agent interruption/queue timing remain owner acceptance; no real task or file was sent to the live server. Earlier authenticated-session acceptance is unchanged. This is local device installation, not TestFlight/App Store distribution. No backend edits, commits or pushes occurred.
