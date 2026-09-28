# Existing-chat navigation correction — September 28, 2026

## Problem and change

The owner could sign in and see chats, but selecting a chat only flashed synchronization and appeared to return to the main screen. Source inspection showed that row selection requested state but never opened a destination: conversation logs lived below the entire chat list. A long list therefore hid the result.

Existing chat rows now push a dedicated conversation screen with the selected title, status, transcript, draft composer, Back and Disconnect. Rows use stable server context IDs instead of array offsets. Snapshot updates do not replace or pop the route. Back preserves the current chat's draft; another selection loads its own content/draft. Empty and loading states are distinct. Disconnect clears navigation. Shared transcript/delivery rendering preserves existing rendering and command behavior.

Startup/profile loading and scene lifecycle observation are attached to the persistent NavigationStack, preventing root-list reappearance from rerunning startup work. This matters especially to isolated synthetic launch fixtures and ensures lifecycle handling remains active while a destination is visible.

## TDD evidence

| Planned guarantee | Evidence |
| --- | --- |
| Existing chat opens a conversation instead of staying below a long chat list | `red.xcresult`: regression failed at the missing chat navigation title before production UI changes |
| Switching Alpha → Beta → Alpha shows matching content and preserves only Alpha's unsent draft; empty chat is explicit; disconnect exits detail | `green-final.xcresult`: passed on iPhone iOS 27 simulator; `device-final.xcresult`: passed on physical iPhone 15 / iOS 18.7.3; `ipad.xcresult`: passed on iPad iOS 26.5 |
| A fresh realtime handshake/state push does not return to the root screen | `green-final.xcresult` and `device-final.xcresult`: passed using synthetic realtime callbacks |
| Existing create/send, uncertain-send protection, account isolation and reconnect draft behavior | Four existing ChatUITests passed in `green.xcresult` and again after the final lifecycle change in `chat-regression-final.xcresult` |

The first implementation runs (`green.xcresult`, `device.xcresult`) exposed a disconnect/navigation lifecycle assertion failure. Moving startup and lifecycle modifiers to the persistent container fixed it; final conversation runs pass without skipped tests. The synthetic fixture includes 33 chats and distinct per-context responses, with delayed snapshots; it never uses a real server or owner data.

Measured focused coverage from `green-final.xcresult`: ConversationView.swift 124/149 executable lines (83.2%), root app source 344/368 (93.5%). No core protocol behavior changed and no fresh core-suite run is claimed. Test fixes and coverage evidence are retained on disk; this workspace is not a Git repository, so no TDD checkpoint commits exist.

## Build and visual verification

Development physical-device and simulator builds pass. Unsigned Release simulator build passes (`release-build.log`). Synthetic iPhone and iPad screenshots were inspected together: native navigation, selected title/content and preserved draft are visible. The captured iPhone and iPad layouts use Light Mode. Known warnings remain: iPad orientations, Release linker ambiguous target atom, and skipped AppIntents metadata extraction.

The updated development app is installed and launched normally on the owner's phone, outside XCTest. Owner confirmation of existing live-chat content is pending. The synthetic realtime test validates coordinator/UI behavior, not the real Socket.IO adapter. No live message/task, server source change, new dependency, commit/push or distribution was performed.
