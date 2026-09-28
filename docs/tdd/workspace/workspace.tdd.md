# Conversation workspace and continuity — 2026-09-28

## Behavior
- Latest is a 36-point circular down arrow with a 44-point touch target. The framed composer grows with the draft and provides Tools, Voice and Send; keyboard dismissal and draft ownership remain intact.
- Activity previews show actual tool labels and agent attribution. Agents opens the latest recorded step and expandable history for each reported agent. Working/paused/catching-up states derive from server progress flags, not invented per-agent completion.
- Workspace offers search, selected-chat state, new conversation, running indicators and Settings. It changes the existing stable route.
- Native tools support Pause/Resume, Nudge, History and Context through the authenticated API. Read results open a dedicated reading screen. Mutation intent is atomically saved before submission; unknown outcomes block another control until explicitly acknowledged. Reads do not clear pending receipts. No automatic mutation retries. Full WebUI handoff covers attachments/folders/MCP/skills/goal mode/terminal; native parity for these is not claimed.
- Backgrounding preserves the transcript and A2UI while pausing transport. Foreground refreshes before Send becomes available. Process relaunch restores a valid device-only session cookie and re-fetches the selected chat. Explicit disconnect removes it. No password replay or transcript archive. Generated form edits survive an ordinary background transition, but not process termination.
- Voice is explicit foreground on-device dictation or continuous listening, with local transcript review before draft insertion. Playback is explicit. FoundationModels cleanup is optional and availability-gated on iOS 26; no arbitrary Core ML model was added.

## Verification
`core-final.log`: **117 A0Core tests and 19 A0GenerativeUI tests pass (136 total)**. Added control contracts, authentication/no-retry checks, durable pending receipt behavior, restoration/session epoch tests, voice partial accumulation, activity attribution and truthful progress tests. Parallel test-first additions caused temporary missing-type compilation failures; those are recorded as compile-stage RED, not behavioral failure. Voice buffer has its own RED/GREEN evidence. No new runtime dependencies.

| Run | Result and scope |
| --- | --- |
| `../workspace-first.xcresult` | 3 pass, 1 selector failure. Background recovery, A2UI Home/activate/terminate/relaunch, and passive Voice pass on phone simulator. Workspace test matched both Back and menu Chats buttons. |
| `../workspace-navigation.xcresult` | Test runner launch rejected by simulator as Busy; no behavioral result. |
| `ipad.xcresult` | Voice passes at maximum text; workspace reaches chat switch then duplicate Chat tools selector fails. |
| `ipad-final.xcresult` | Workspace passes; tooling resolved another same-name iPad and captures are normal-text light, not max-text evidence. |
| `device.xcresult` | 12 pass, 1 selector failure: all 10 existing interface flows, session lifecycle and Voice pass on physical iPhone15/iOS18.7.3. Workspace still had old ambiguous tool selector. |
| `device-final.xcresult` | 2/2 pass: corrected Workspace and passive Voice on physical phone. |
| `device-polish.xcresult` | 2/2 pass after bounded icon sizing and disabled Voice contrast fixes. |

The final maximum-text check additionally exposed read results below the tools viewport. History and Context now navigate to their own reading screen. `device-tools.xcresult` passes the final dedicated reading flow on the physical phone. `ipad-confirm.xcresult` passes both Workspace and Voice on the explicitly pinned iPad at maximum Dynamic Type in dark mode. The previous `ipad-max-final` run recorded offscreen-result assertion failures and then stalled in result finalization; its own runner was terminated, and it is not acceptance evidence. `ipad-light-confirm.xcresult` also passes both flows in light mode, providing post-fix contrast evidence. `release-build.json` records the successful final unsigned Release build; `normal-launch.log` records reopening the latest installed phone app outside XCTest.

Core executable-line coverage for the four new control/session/voice-buffer files is **93.64%** (103/110 lines), recorded in `core-coverage.txt`. This is not whole-app coverage or microphone/model-quality validation. A passive audio deactivation warning was fixed by tracking session ownership; the final passive Voice tests do not activate or deactivate audio. The older orientation warning remains outside this slice.

## Boundaries
Synthetic server data only; no live chat mutation, microphone activation or owner credentials inspected. User must sign in once in the updated build to create its new session Keychain item. Subsequent valid sessions restore automatically; server expiry still requires sign-in. Cold offline relaunch cannot show uncached server content. Real speech quality, continuous microphone rollover, FoundationModels output and live Pause/Nudge acceptance remain owner-verification items. iOS can suspend sockets while Agent Zero continues on its server. Development installation is not TestFlight/App Store distribution.

Sources: [session contract](../../SESSION-RESTORATION.md), [voice contract and Apple references](../../VOICE.md), [Goose mapping](../../GOOSE-REFERENCES.md). Design packet: `.impeccable/review/workspace/`; no new shipping raster assets.

Final Impeccable disposition: **ship** for the bounded UI corrections. Light and dark captures confirm the disabled Voice action and explanatory text are readable; maximum-text icon collisions are resolved. The review does not establish live speech or server-control acceptance.
