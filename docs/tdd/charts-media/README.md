# Charts and media TDD

Journeys derived from the user's request: use appropriate native charts for comparisons, trends, composition, distributions, relationships and ranges; play supplied audio/video explicitly with accessible descriptions and isolated downloads.

## RED
`swift test --filter ChartMediaTests` executed 4 tests with 18 intended failures: 11 new chart kinds and 2 media components unavailable; existing chart semantics lacked duplicate/series bounds; producer guidance lacked new types. Initial test-comment syntax was corrected before this runtime RED, and is not counted as evidence.

Media transport tests specify bounded credential-free file downloads, rejection of unsupported MIME/redirect/private DNS/oversize data, cancellation and file lifetime. The transport implementation is intentionally absent at this checkpoint.

`swift test --filter MediaDownloadTests` reached the intentional missing-implementation compile RED (`cannot find type MediaDownloads`, `MediaFile`). Two earlier invocations overlapped file additions and failed during discovery; those setup failures are excluded.

## Core GREEN
`swift test --enable-code-coverage`: 51 generative tests plus 208 core tests passed. All 4 catalog/guidance regressions and all 3 media transport tests passed. Coverage and native results follow below when verified.

## Native RED
The simulator executed `ChartMediaUITests/testLargeTextChart` and failed its `View values` assertion for the absent donut fixture/rendering. Command: `xcodebuild -project AgentZeroSpike.xcodeproj -scheme AgentZeroSpike -destination 'platform=iOS Simulator,id=0758A3EE-44E9-4645-AEC3-8CA818DBF74C' -derivedDataPath /tmp/a0-charts-derived -disableAutomaticPackageResolution -skipPackageUpdates -only-testing:A0UITests/ChartMediaUITests/testLargeTextChart test`.

## Media routing RED
Native testing exposed that the SDK reserves `AudioPlayer`/`Video` names and bypasses the custom catalog for those built-ins. Added `mediaAlwaysUsesTrustedLocalPlayerInsteadOfSDKBuiltins`; `swift test --filter mediaAlwaysUsesTrustedLocalPlayerInsteadOfSDKBuiltins` executed one test with two intended routing failures. The fix must remap both types before any SDK processing, preserving the bounded local-file-only player.

## Routing GREEN and expanded coverage
`swift test --enable-code-coverage` now passes 57 generative tests plus 208 core tests (265 total), including trusted SDK remapping, media candidate privacy, all MIME mappings, chunked disk writes and extended chart bounds. ChartContent/MediaContent/MediaDownloads combined coverage is 91.89% lines, 91.84% regions; the transport's real TLS challenge and redirect delegate are source-reviewed rather than exercised against a live server.

## Native playback iteration
All 14 chart kinds, large text, 128-point scatter, the legacy rich-reply flow and transcript-following checks passed on the simulator. Initial chart assertions needed the combined accessible values row identifier. Native video exposed unreliable visibility of embedded AVKit transport controls, so both media types now use consistently accessible themed play/pause/seek controls around AVKit rendering, plus embedded caption selection where available. Audio/video both play; a new pre-play seek assertion found the short synthetic video remained at zero with AVPlayer's default keyframe tolerance (`ChartMediaUITests` line 50). This runtime RED is retained before tightening seek tolerance.

Xcode's failed-run `simctl diagnose` processes exceeded several minutes after tests completed. Only the three task-owned diagnostic subprocesses were terminated so their failed bundles could finalize; this is not counted as successful test completion.

## Native playback GREEN
`xcodebuild ... -only-testing:A0UITests/ChartMediaUITests/testAudioAndVideoRequireExplicitLoadingAndStopOnBackground test` passed on the iPhone 14 Plus / iOS 26.5 simulator after using zero seek tolerance. Both local synthetic audio and video remained paused until Play, sought forward before playback, played, and released the player on background. `testMediaFailureAndCancelLeaveUserInControl` passed separately; a canceled delayed load never opened a player. New native GeneratedMedia.swift measured 84.15% line coverage in the playback run. Embedded caption tracks and hardware audio interruptions remain unverified.


## Final verification

| Guarantee | Executed check | Result |
| --- | --- | --- |
| Chart semantics, bounds, catalog compatibility, media routing and minimized Jev projection | `swift test --enable-code-coverage` | 265 tests passed (57 generative + 208 core) |
| Fourteen chart styles render and expose readable values | `testComparisonAndTrendCharts`, `testCompositionAndNumericCharts` | Each case passed on iPhone; these cases ran in a mixed run whose earlier media failure was subsequently fixed |
| Large text, server palette and 128-point scatter stay usable | `testLargeTextChart`, `testDenseChart` | Passed; large text also passed on iPad |
| Audio/video do not autoplay; seeking, playing and background teardown work | `testAudioAndVideoRequireExplicitLoadingAndStopOnBackground` | Final standalone iPhone run passed; final iPad run passed |
| Invalid media is recoverable and cancel cannot open a late player | `testMediaFailureAndCancelLeaveUserInControl` | Passed on both devices |
| Existing rich replies and history-follow behavior remain functional | `GenerativeUITests/testForecastChartCarouselAndSourceConfirmation`, `ChatInterfaceUITests/testReadingHistoryPausesFollowingUntilLatestIsTapped` | Passed on iPad / iPhone respectively |
| Heatmap minimum values remain visible; circular charts do not claim a horizontal axis | `testHeatmapContrast`, `testLargeTextChart` plus screenshot review | Final two-test iPhone run passed |

Native command base actually used:

```sh
xcodebuild -project AgentZeroSpike.xcodeproj -scheme AgentZeroSpike \
  -destination 'platform=iOS Simulator,id=0758A3EE-44E9-4645-AEC3-8CA818DBF74C' \
  -derivedDataPath /tmp/a0-charts-derived \
  -disableAutomaticPackageResolution -skipPackageUpdates -enableCodeCoverage YES \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
  -only-testing:A0UITests/ChartMediaUITests/testHeatmapContrast \
  -only-testing:A0UITests/ChartMediaUITests/testLargeTextChart test
```

Earlier full chart runs used the same base with a 240-second test allowance and the full `ChartMediaUITests` selector. The final iPad run used destination `256E8E14-492E-4A80-B1F1-B3EF18E1FA90`, `test-without-building`, and the three media/background, cancellation and large-text selectors. Its result was three tests, zero failures, `TEST EXECUTE SUCCEEDED`. Both simulators run iOS 26.5; iPhone is dark and iPad light, with the synthetic Catalog Ocean server theme. [Retained screenshots](../../evidence/charts-media/) are synthetic.

[Coverage](coverage.md): new package chart/media files are 91.89% covered by lines; native media is separately 84.15%. This is not whole-app coverage. Hardware output/interruption behavior, caption-track selection, real public media hosts, authenticated server media and live Jev/model generation were not verified. Xcode simulator archives, failed-run diagnostics, exported recordings and temporary playback fixtures are disposable; compact evidence and selected PNGs are retained.

## Physical-device handoff

Source `1fd0b93` built successfully as a signed Release with the pinned dependencies; `codesign --verify --deep --strict` passed. `devicectl` installation and ordinary launch both succeeded on the physical iPhone 15 / iOS 27.2. The installed app retains identity `com.terminallylazy.a0-ios` and version 0.1.0 (5), without fixture launch arguments. This is installation evidence, not live-feature acceptance or a TestFlight release. Task-owned device DerivedData was removed after delivery; private signing and raw device metadata are not committed.

## Local checkpoint chain

- `6e61529`: chart/media catalog runtime RED.
- `9d22ac3`: missing media transport compile RED.
- `b64830d`: core catalog/transport GREEN.
- `6260a62`: native presentation RED.
- `1ffafb3`: reserved SDK media-routing RED.
- `f38fad7`: trusted routing GREEN.
- `4ea4829`: native seek RED and chart evidence.
- `4f6ffde`: native chart/media GREEN.

These are local checkpoints on `codex/jev-ios`; none were pushed or merged in this task. Preserve this RED/GREEN record if later squashing.
