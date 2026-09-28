# Tool presentation, keyboard and Settings — 2026-09-28

## Request and implementation

The owner's screenshots showed unrendered `icon://chat` tokens, dense/raw tool events, a keyboard without an explicit minimize action and no Settings menu. They remain private in the supplied Photos library paths; replacement evidence uses authored fixtures.

- **Tool presentation:** `LogHeading` implements the WebUI token grammar with escaped tooltip handling and safe SF Symbol fallbacks. `ActivityPresentation` prefers structured metadata, supports bounded legacy JSON decoding (64 KB), preserves agent attribution, and gives common tools readable names/icons. Incomplete JSON becomes a receiving summary; full structured content stays under Raw event. Expanded activity uses flattened rows rather than nested cards. Human headings and link confirmation remain available.
- **Keyboard:** composer FocusState controls an explicit keyboard/down-chevron action beside Draft options. It resigns focus without sending or changing the draft; scroll dismissal remains available.
- **Settings:** gear on the root and Settings in the conversation menu. Native form/sheet controls System/Light/Dark appearance, long-message collapse and activity grouping. Display preferences persist in UserDefaults; synthetic tests use a UUID-scoped suite. No credentials enter those preferences. Connection information, About and storage explanation are present. Change server confirms via an alert, disconnects and returns to existing server/profile/Keychain controls; drafts and uncertain receipts are retained.

Goose's tool disclosure, Settings sections and icon use informed this refinement. Agent Zero's WebUI remains the icon/protocol authority. No Goose code, assets or dependencies were imported. See [reference decisions](../../GOOSE-REFERENCES.md).

## RED evidence

- `core-red.log`: missing LogHeading/ActivityPresentation types.
- `ui-red.xcresult`: both missing Settings and missing explicit keyboard dismissal fail before implementation.
- `metadata-red.log`: tooltip-only field names and legacy JSON with empty structured metadata fail, then pass after fallback correction.
- `subtitle-red.log`: missing friendly agent-step subtitle, then implemented without losing agent attribution.
- `device.xcresult` and `ui-green.xcresult` retain the first Settings persistence failure. The captured switch stayed on: XCTest targeted the whole labelled row instead of the visible switch thumb. Corrected tests target the native control, assert its changed value before relaunch, and retain the persistence assertion. No production persistence weakening was needed.
- `settings-green.xcresult` retains a native confirmation-dialog mismatch: newer iOS presented a popover without a visible Cancel button. Change server now uses a standard alert with explicit Cancel on all tested platforms.

## GREEN evidence and scope

- `core-final.log`: **100 core tests pass**. LogPresentation executable line coverage **64/68 (94.1%)**.
- `ui-green.xcresult`: seven of eight interface flows passed before the Settings harness correction, including the five pre-existing conversation/Markdown/following flows; the retained failure is described above.
- `settings-green.xcresult`: preference persistence and tool formatting pass; its server-change test failure was corrected by the standard alert.
- `device-final.xcresult`: **5/5** focused physical iPhone 15 / iOS 18.7.3 flows pass: appearance/grouping behavior, keyboard dismissal with draft retained, server change/cancel/reconnect with draft retained, preference persistence/reopening Settings without losing navigation, and native icon/tool-summary rendering with details.
- `keyboard-capture.xcresult`: focused dismissal flow passes again to capture the visible minimize control and the preserved draft after dismissal.
- `ipad.xcresult`: **3/3** light iPad flows pass (appearance/grouping, keyboard, tool presentation).
- `ipad-large.xcresult`: **2/2** dark iPad flows pass with maximum accessibility text (Settings persistence and tool presentation).
- `release.log`: unsigned iOS Release build succeeds. Existing development identity installed the device build; it was reopened without XCTest or synthetic arguments after checks.

Focused physical executable line coverage: SettingsView **279/285 (97.9%)**, ChatComposer **174/188 (92.6%)**, MessageRow **326/344 (94.8%)**, from `device-coverage.json`. These are line-coverage receipts, not full app/security acceptance.

## Acceptance limits

All automated state is synthetic and isolated; no live messages were submitted and no credentials or real chats captured. This pass does not claim a new full 37-flow suite, complete WebUI parity, voice, server model configuration, or distribution. UI build/tests do not substitute for owner acceptance against the live tunnel. Custom tool names use readable fallback labels/icons; raw events remain inspectable. Markdown support remains the previously documented native subset.

Final visual review packet is `.impeccable/review/interface-polish/`, including phone/tablet, keyboard-visible/dismissed, Settings and large text. The final verification and review receipts are recorded below.

## Final verification

- `regression.xcresult`: the four existing ChatUITests and the connection test pass (5 flows). The additional reconnect flow failed because the lazy root list retained its scrolled offset after Password was revealed: Continue draft existed behind the navigation bar. `server-change-final.xcresult` confirmed that waiting alone did not solve the offscreen target. The test now reveals the row before tapping; `server-reveal.xcresult` passes, including the unchanged retained-draft assertion. No production navigation workaround was needed.
- The visual reviewer identified faint supporting text in light appearance. `Color.a0Supporting` now uses opaque light RGB(0.34, 0.34, 0.36) for activity metadata, summaries, draft status and Settings supporting text; dark appearance retains UIKit secondaryLabel. Existing Agent Zero palette and layout remain intact.
- After that correction, `device-contrast.xcresult` passes 3/3 physical flows (keyboard, Settings persistence, tool presentation), and `ipad-contrast.xcresult` passes 2/2 light iPad flows (appearance/grouping and tool presentation). Phone and light-tablet review captures were refreshed from those results; prior maximum-text dark captures retain their original provenance.
- `release-final.log`: final unsigned iOS Release build succeeds; only the existing no-AppIntents metadata-extraction warning remains. The final signed development app was installed by physical testing and launched normally using devicectl without test or synthetic arguments afterward.
- DESIGN.md and its design sidecar now document the actual Settings, keyboard, tool-disclosure and supporting-color contracts.

Final independent Impeccable review: **ship**. The reviewer measured the corrected light summary region at approximately **4.85:1**, confirmed dark treatment retained and design documentation current, and observed no regressions in the final recaptures. Receipt: `.impeccable/review/interface-polish/verdict.md`.
