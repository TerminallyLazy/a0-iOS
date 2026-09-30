# Jev presentation selection experiment

Status: evaluated with the official Swift CLI; **not wired to production chats**. No Jev dependency or credential is bundled in the iOS app.

The [json-render Jev approach](https://json-render.dev/docs/jev) is applicable to the native A2UI catalog: construct valid candidates from existing data, ask Jev to choose, then validate and render the chosen surface. The experimental json-render APIs are not an iOS SDK and are documented as unreleased; they must not be treated as a dependency required by this app.

## Recorded check

`request.json` contains six wholly synthetic scenarios and one batched choice question per scenario. `expected.json` is the independently specified expected routing. `result.json` records the live TypeSafe response, version and measured process elapsed time. All six choices matched: forecast, image carousel, chart, combined dashboard, prose, and missing-data fallback. Model `jev-1.13.0` took 0.48 seconds including CLI startup/network, using 1,726 input and 323 output tokens in this one call. This is feasibility evidence, not a latency benchmark or an accuracy estimate. Reported confidence is an assessment, not proof that data is valid.

The [swift-jev CLI](https://github.com/d-date/swift-jev) was built from revision `d5d2280c01a33b08888958bbeb866ae7ca50f883`. It was invoked with `--input request.json --api-key-file PATH`; the temporary credential file was outside both repositories, mode 0600, and removed immediately afterwards. The owner-managed `.env` was unchanged. Only synthetic state went to TypeSafe.

## Historical integration proposal

This experiment preceded the user-approved device-key implementation documented in [native generated replies](../../GENERATIVE-UI.md). Its original server-side proposal below is historical, not the current app contract.

The original proposal was:

1. Build complete Forecast, ImageCarousel, Chart or Dashboard candidates from retrieved data. Exclude candidates with absent values, units, sources or invalid media URLs before calling Jev. Markdown is always eligible.
2. Send minimal candidate descriptions and the requested presentation intent, not full chat history, provider credentials, private tool output or generated form input. Keep TypeSafe authentication server-side.
3. Ask one bounded choice among eligible candidate IDs; resolve that ID back to its original data. Never let the judgement fabricate measurements, URLs, actions, additional candidates or new tool authority.
4. On timeout, unsupported choice, missing answer or uncertain judgement, preserve the ordinary Markdown response. Do not delay a usable answer indefinitely or retry a user mutation. Any confidence threshold needs representative evaluation before release.
5. Emit the existing self-contained `a2ui` response envelope. The iOS `GeneratedDocument` validator, media policy, reviewed action flow and profile/context isolation remain authoritative.

This experiment does not add a second on-device network call, transmit user chats to TypeSafe, modify the Agent Zero backend or change existing generation behavior. Current optional app behavior is documented in the linked native generated replies contract.
