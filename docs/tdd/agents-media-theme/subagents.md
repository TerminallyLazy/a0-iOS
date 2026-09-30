# Subagent relationship and discovery regressions

The tests use synthetic context dictionaries only. No server or owner chat data was accessed.

## RED

- `swift test --filter SubagentRelationshipsTests` failed because the new `SubagentRelationships` and `SubagentDiscovery` types did not exist. Captured locally in `/tmp/a0-subagents-red.log`.
- After the first implementation, a new negative case for a BACKGROUND context failed two assertions: the hidden context was still navigable and appeared among children. Captured in `/tmp/a0-subagents-extra-red.log`; explicit background exclusion fixed it.
- A rename regression failed because the original assignment label overrode the current server chat name. Captured in `/tmp/a0-subagents-name-red.log`; current name now wins, with assignment label as fallback.

## GREEN

`swift test --enable-code-coverage --filter SubagentRelationshipsTests` passed 11 tests. The coverage run is local evidence in `/tmp/a0-subagents-green.log`.

Coverage includes exact hierarchy metadata, nested relationships, positive working/paused status, no inferred completion, missing parents, self-links, cycles, ambiguous duplicate IDs, invalid IDs/types, hidden background contexts, bounded input/depth, Unicode/plain-text labels, renames, cold-start baselines, genuinely new children, incomplete sync, scope reset, child-only acknowledgment, and deletion.

A bounded 4,096-context case checks preserved ordering and discovery of the one newly added child. Indexing children once reduced the observed focused case from 3.760 seconds to 0.034 seconds on the development Mac; this is a local observation, not a device performance guarantee.

## Integration contract

Only exact `parent_context_kind = subordinate` and valid `parent_context_id` links between available visible contexts create navigation. Agent names/numbers never infer a link. Missing `running` and explicit false remain neutral: direct subordinate execution can run without its own task object.

Discovery state stays in memory, scoped to the authenticated session, and updates only after complete fresh state. Every known parent—including those with no children—is baselined on first hydration. Opening a child acknowledges only that child; opening the sheet does not clear other unread children. Native navigation reuses normal chat selection and preserves existing per-chat draft/attachment ownership.

Native UI and physical-device acceptance are recorded separately by the coordinating task after executed checks.

## Foreground discovery regression

The coordinated native `testNewSubagentBadgeSurvivesForegroundRefresh` failed at its post-foreground badge assertion in `/tmp/a0-agents-media-review-red.xcresult`. Transport generations rotate during suspension, which had erased unread-child discovery. `SpikeModel` now uses a separate authenticated-session discovery scope: disconnect/new connection/profile selection and authenticated session restoration reset it; ordinary background/foreground transport refresh preserves it. Centralized native verification owns the subsequent GREEN result.
