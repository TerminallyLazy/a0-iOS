# Media preview and read-only action verification

The parser is a pure local compatibility path for ordinary assistant responses. It creates no requests and changes neither response prose nor explicit A2UI validation. Explicit or candidate payloads, including incomplete/rejected payloads, retain precedence. The UI reuses the existing isolated downloader/player after explicit Load.

## Executed test-first sequence

- New `ReplyMediaPreviewTests` initially failed compilation because the preview API, media example and exact historical suffix did not exist. Evidence: `/tmp/a0-agents-media-parser-red.log`.
- Initial implementation passed all six new cases. A second adversarial test exposed previews inside multiline HTML and lazy blockquote continuations (three assertion failures). Evidence: `/tmp/a0-agents-media-exclusion-red.log`.
- HTML-bearing replies and quoted regions are conservatively excluded. A raw JSON test then failed before adding the non-prose JSON exclusion. Evidence: `/tmp/a0-agents-media-json-red.log`.
- The final parser uses Foundation Markdown attributed runs for both ordinary and explicit Markdown links. This removed a redundant manual URL scanner and its repeated parenthesis counting; bounded reply and candidate checks remain.
- Media instructions now request explicit components for final delegated replies and include a locally validated synthetic AudioPlayer/Video example. Exact earlier media and Jev instruction suffixes still collapse in the transcript.

## Focused GREEN and coverage

`swift test --enable-code-coverage --filter ReplyMediaPreviewTests` passed all 10 tests; log: `/tmp/a0-agents-media-parser-green.log`. The 100,000-closing-parenthesis malformed URL regression passed in 0.012 seconds on this Mac; this is an observation, not a brittle timing assertion. The suite also covers response-only admission, Markdown and bare links, supported extensions, ordering, duplicates, four-link/URL/reply bounds, explicit/candidate precedence, code/HTML/quote/JSON exclusions, and historical producer instructions.

`llvm-cov report` measured `ReplyMediaPreview.swift` at 72/72 lines, 50/50 regions and 11/11 functions (100%). The tool emitted no branch counters. This is focused parser coverage, not whole-app coverage. Summary: `/tmp/a0-agents-media-parser-coverage.txt`.

## Native read-only controls

The parent task executed a valid native RED assertion against the disabled Load audio button inside Agents (`/tmp/a0-agents-media-readonly-red.xcresult`, `XCTAssertTrue(load.isEnabled)`). Only afterward, `GeneratedReplyView` replaced blanket surface disabling with the pinned SDK's per-control overrides for Button, CheckBox, ChoicePicker and Slider. The custom TextField receives the same read-only flag. Passive charts/media remain usable. The action callback independently requires a draft handler before review or draft insertion. Native GREEN evidence belongs to the combined UI run recorded by the parent task.

These tests use synthetic data and local fixtures. They do not prove live media hosts, provider calls, or physical-device playback.
