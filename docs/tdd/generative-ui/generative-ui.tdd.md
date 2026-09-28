# Native A2UI and rich replies — 2026-09-28

## Delivered behavior
Pinned A2UI-Swift to upstream commit `16476ba2cb3fcb4c4bcb141dfa4c2804adbdedb0`; no SDK source changes. Native response surfaces support standard forms plus forecasts, image carousels, Swift Charts line/bar/area plots and adaptive dashboards. Rich replies defaults on and includes the catalog contract with an ordinary explicit send. Sources remain visible and external navigation uses the existing confirmation. Generated form actions require review and append to the existing draft without sending.

Additional Goose sources informed message composition and review ownership; no Goose code, assets or dependencies were copied. See [reference mapping](../../GOOSE-REFERENCES.md) and [catalog contract](../../GENERATIVE-UI.md).

## Red → green evidence
- `red.log`: stable 0.3.5 dependency resolution fails because of its revision-based ICU dependency. The selected upstream fix removes it; Package.resolved records the exact graph.
- `red-pinned.log`: missing adapter types before implementation.
- `rich-red.log`: missing rich catalog types before implementation.
- `intermediate-red.log`: initially final-only graph validation accepted an unsafe intermediate graph. Validation now checks every component update before SDK processing.
- `core-final.log`: **19 A0GenerativeUI tests and 100 existing A0Core tests pass**. Validation, epoch/surface isolation, identical updates, local bindings, rejection/replacement/deletion, action bounds, preserved draft text, capability/queue identity and credential-isolated image transport are covered.
- `coverage-final.txt`: **95.19% executable-line coverage** for Sources/A0GenerativeUI (356/374 lines). This is module coverage, not whole-app or all dependency coverage.

## Native verification
| Evidence | Result | Scope |
| --- | --- | --- |
| `rich-ui-build.xcresult` | 3/3 pass | Phone simulator native form/review, Settings instructions, rich visual flow. |
| `device-rich.xcresult` | 6 pass, 1 fail | Four existing chat/delivery/isolation flows and two form flows passed on iPhone 15 / iOS 18.7.3. Initial rich source-link test used the wrong element type. |
| `ipad-rich-large.xcresult` | 2 pass, 1 fail | Form and Settings flow passed at maximum Dynamic Type; rich test needed reliable scrolling and source accessibility identity. |
| `device-rich-confirm.xcresult` | 1/1 pass | Final physical rich flow: forecast, chart values, next image, source confirmation/cancel. |
| `ipad-rich-final.xcresult`, `ipad-chart-confirm.xcresult` | 1/1 pass each | Final rich flow at maximum Dynamic Type on iPad Pro 13-inch simulator; latter supplies full chart viewport evidence. |
| `release-build.json` | pass | Unsigned Release simulator build from final app source. |
| `normal-launch.log` | pass | Latest development app installed by physical test and launched normally, without XCTest or synthetic arguments. |

Earlier runs remain as diagnostic evidence. They exposed placeholder-only SDK field labels, the review action below the large-text viewport, and aggregate accessibility IDs masking child source controls. Local native input labels, a pinned review action, flexible accessibility dashboard columns and independent source-link IDs resolve those findings. UI automation now explicitly scrolls controls above the composer before tapping. One physical rerun was interrupted by an OS banner and a chart disclosure outside the intended tap region; the final focused run passes. Failed-run attachments are not used as product screenshots.

The form flow still emitted an `Invalid frame dimension (negative or non-finite)` runtime warning during field/review transitions. No malformed form layout or failed final form assertion was observed. This receipt does not claim a warning-free runtime. An initial Release tool invocation duplicated the configuration argument; the corrected build passes.

## Design evidence and limits
Current synthetic captures and independent finish verdict live in `.impeccable/review/generative-ui/`. The final review disposition is **ship**: persistent labels, pinned review action and documentation findings are resolved; forecast, chart, carousel and dashboard captures have no remaining material visual findings. DESIGN.md and its sidecar document the catalog and existing Agent Zero visual language. The image preview deliberately says Synthetic image preview; it is not a screenshot of a downloaded Google result. No new shipping raster assets were created.

No live server messages, credentials or private transcripts were read or changed for this verification. The server and model must emit the documented payload for an ordinary forecast/image-search request to render natively. Live generation, real external image download/display, and real provider data accuracy remain unverified. Image transport tests use an injected URLProtocol and bounded synthetic responses; DNS tests use numeric addresses. DNS preflight is not a rebinding guarantee. This is a development install, not TestFlight/App Store distribution.
