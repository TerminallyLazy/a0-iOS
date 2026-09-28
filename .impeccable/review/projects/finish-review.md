# Projects source and phone confirmation

Reviewed 2026-09-28. Scope: the four prior Projects findings, their correction batch, and the added compact tools/context presentation on iPhone. This is not full iPad, live-server, voice, or model-preset acceptance. No builds or server calls were performed by the reviewer.

## Verdict

1. **Resolved — stale project filter:** `ProjectChatFilter` retains an All projects reset while a selection exists and clears a selected name removed from the current project set.
2. **Resolved — foreground recovery:** `ProjectsView` reloads when `canSubmit` returns and after busy work finishes when the generation needs a load. `attemptedGeneration` bounds automatic retry. The duplicate readiness observer was removed.
3. **Resolved — pending new-chat recovery:** `ProjectWorkspace.load` restores the context from the persisted Create chat in project receipt. Projects offers Check chat without replaying creation or assignment.
4. **Resolved — accessible project association:** Root chat rows expose the project title through `accessibilityValue`; visual dots remain supplemental to text. Color buttons expose their selected state.

The source correction batch introduces no material regression identified in this bounded pass. The editor continues preserving untouched field dictionaries and validates MCP text only when changed.

The supplied phone captures show native Projects lists, a clearly selected palette swatch, a reachable Save changes action, project labels in conversations, and legible compact tools/context popovers. Context values are authored fixture data shown by the actual accounting UI, not evidence of live usage. The context meter's source now uses semantic caption2 with a scaled ring rather than a fixed 9-point label.

Inspected screenshot files:

- `docs/tdd/projects/phone-shots/1A787B65-1BC1-46FE-B60F-C7BB1774BFC1.png` — compact chats and project labels.
- `docs/tdd/projects/phone-shots/5D019788-892B-472B-B16C-808E843F4522.png` — Projects list.
- `docs/tdd/projects/phone-shots/6B0E1D01-4758-49B5-8A19-5D711C5CAB05.png` — editor and selected color.
- `docs/tdd/projects/phone-shots/5AE0A1D3-AFF7-47C2-AE20-CD8A90B05021.png` — project conversation.
- `docs/tdd/projects/device-shots/FDC4E470-2994-4D5F-A59F-4418B2555292.png` — context accounting popover on physical iPhone.
- `docs/tdd/projects/device-shots/5C2D47C5-2D40-489A-86E7-4DDBC72C0F2B.png` — tools popover on physical iPhone.

## Remaining

No unresolved finding from the four-item source review. Final iPad/maximum-text captures and the newly requested model-preset surface remain outside this confirmation. The tools panel was reduced from 340 to 300 points after the inspected capture; that small height adjustment is source-verified only. Test outcomes belong to the parent's receipts, not this visual review. This ship verdict covers the scored fixes and inspected phone presentation, not the whole application.

disposition: ship
