# Agents, direct media and theme verification

Gate 1 approved implementation. Gate 2 subsequently approved commit, push, merge and TestFlight release; distribution receipts are recorded in docs/TESTFLIGHT.md.

## Scope and behavior

- Agents uses existing scoped navigation/presentation theme through header, content and safe areas.
- Ordinary assistant direct-file audio/video links retain prose and offer explicit native Load cards. Explicit A2UI/Jev surfaces retain precedence. The Agents inspector permits passive media while draft-producing controls remain read-only.
- Verified visible subordinate chats appear in a compact Subagents control with newly discovered children, related chat cards and parent return. Normal selection preserves draft/attachment ownership. No automatic navigation, fabricated completion, server changes or additional provider calls.

## Test-first evidence

See [parser and media](media.md), [relationship and discovery](subagents.md), and [native journeys](ui.md) for actual RED outcomes and fixture corrections. Build/setup failures are distinguished from behavioral failures.

`swift test --enable-code-coverage` passed 286 tests: 219 core and 67 generated UI. The focused new parser suite passed 10 tests and measured 100% line/region/function coverage; relationship/discovery has 11 new tests. Full package tests include the unchanged auth, mutation receipt, queue/steer, cancellation, URL/download and generation isolation contracts. No dependencies or version changed.

Final iPhone 14 Plus / iOS 26.5 dark run passed all 10 selected journeys: seven `AgentsMediaUITests`, `ChartMediaUITests.testAudioAndVideoRequireExplicitLoadingAndStopOnBackground`, and the Queue/Steer persistence and Stop/draft cases in `SendModeUITests`. Runtime: 260.9 seconds, zero failures. Result bundle was `/tmp/a0-agents-media-phone-final.xcresult`.

Signed Release build and strict signature verification passed with version 0.1.0 (5). All seven new flows also passed on iPad Pro 13-inch (M5) / iOS 26.5 light: 184.9 seconds, zero failures (`/tmp/a0-agents-media-ipad-final.xcresult`). See [iPad theme](../../evidence/agents-media-theme/ipad-agents-theme.png), [related chats](../../evidence/agents-media-theme/ipad-subagents.png) and [media cards](../../evidence/agents-media-theme/ipad-media-cards.png). Physical-device delivery is recorded in ACCEPTANCE.md.

Synthetic screenshots: [Agents theme](../../evidence/agents-media-theme/phone-agents-theme.png), [related chats](../../evidence/agents-media-theme/phone-subagents.png), [media cards](../../evidence/agents-media-theme/phone-media-cards.png), [preserved parent draft](../../evidence/agents-media-theme/phone-parent-draft.png), and [large text](../../evidence/agents-media-theme/phone-large-text.png).

## Review and limits

Independent code review identified activity media lifetime across log epochs and loss of discovery newness on foreground refresh. The Agents subtree now has connection/context/log identity; discovery uses authenticated-session scope. A native source replacement regression also verifies player release when URL and node ID remain the same. Security review checked bounded recognition, explicit payload precedence, credential-free download isolation, read-only action authority and media cancellation.

Fixtures are synthetic and local. This is not proof of live server relationship metadata, live A2UI/Jev generation, external media compatibility or hardware audio output. The public-media DNS preflight retains its documented limitations. Device installation, when successful, proves delivery only.

Code review approved after both lifecycle corrections; security review found no confirmed new blockers. `git diff --check` passed. No commit, push, server mutation or TestFlight upload was performed. Temporary result bundles, test exports and build products were removed after recording results and preserving selected screenshots.

The subsequent user-requested inline playback amendment replaces separate media screens; see [inline verification](inline.md) for its additional tests and final delivery.
