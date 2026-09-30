# Charts and media TDD

Journeys derived from the user's request: use appropriate native charts for comparisons, trends, composition, distributions, relationships and ranges; play supplied audio/video explicitly with accessible descriptions and isolated downloads.

## RED
`swift test --filter ChartMediaTests` executed 4 tests with 18 intended failures: 11 new chart kinds and 2 media components unavailable; existing chart semantics lacked duplicate/series bounds; producer guidance lacked new types. Initial test-comment syntax was corrected before this runtime RED, and is not counted as evidence.

Media transport tests specify bounded credential-free file downloads, rejection of unsupported MIME/redirect/private DNS/oversize data, cancellation and file lifetime. The transport implementation is intentionally absent at this checkpoint.

`swift test --filter MediaDownloadTests` reached the intentional missing-implementation compile RED (`cannot find type MediaDownloads`, `MediaFile`). Two earlier invocations overlapped file additions and failed during discovery; those setup failures are excluded.

## Core GREEN
`swift test --enable-code-coverage`: 51 generative tests plus 208 core tests passed. All 4 catalog/guidance regressions and all 3 media transport tests passed. Coverage and native results follow below when verified.
