# Dynamic model catalogs and activity refinement

## Scope

Provider choices mirror Agent Zero WebUI's `model_config_get` chat/embedding catalogs. `model_search` supplies provider-specific model names using the selected API base, with chat search for Main/Utility/Vision and embedding search for Embed. Utility's empty provider/base follows Main for discovery. The native editor preserves exact custom model IDs and sparse definitions; changing provider clears prior base/kwargs as WebUI does, while retaining the explicit model name until a replacement is selected.

The collapsed activity panel shows one meaningful latest recorded step. Expanded activity uses a compact symbol-led timeline with agent attribution, inline detail expansion and secondary/raw actions behind disclosure. Browser capture previews remain visible and retain their scoped authenticated transport.

## Evidence

- RED checkpoint `69aa720`: three new catalog tests failed to compile because the catalog types/API did not exist.
- GREEN: five catalog tests cover WebUI list decoding, selected provider/type/base payloads, provider mismatch rejection, malformed/oversized result rejection and auth/CSRF session invalidation. The full Swift package run passes 203 tests (184 core + 19 generated UI).
- Reference source: Agent Zero checkout at `6a6cecff8527b164668c7a6ab2f76b6b1ed7cfa1`, `plugins/_model_config/api/model_config_get.py`, `model_search.py`, and `webui/model-field.html`. The backend checkout is read-only for this slice.
- Catalog line coverage: 46/47 executable lines (97.87%); region coverage 40/42 (95.24%).
- Final iPhone iOS 27 run: all four selected tests passed (shared preset editing/inheritance, provider-specific search plus custom ID, retry without selection loss, and tool summaries/native headings). Result: `test_sim_2026-09-29T03-25-50-198Z_pid93812_c1052c6c.xcresult`.
- iPad iOS 26.5 with accessibility XXXL text/dark appearance: tool summaries and retry passed in `test_sim_2026-09-29T03-18-00-607Z_pid93812_012e84e9.xcresult`; the provider/custom-ID flow then passed after the final custom-entry fix in `test_sim_2026-09-29T03-24-44-950Z_pid93812_163868d6.xcresult`. These are separate focused runs, not an all-green iPad full suite.
- Both devices exercised portrait/landscape. Local screenshots beside this receipt show the collapsed timeline, expanded details and filtered model list; raw images/test bundles stay ignored under repository policy. Timeline symbols scale with accessibility text; the custom-ID action remains above a 322-model synthetic catalog and switches to a stable entry form.
- Xcode emitted an unlocated “Invalid frame dimension (negative or non-finite)” runtime warning during preset editor presentation. The tested interactions passed, but the warning is not resolved by this slice.

## Local artifacts and cleanup

Final result bundles live under `~/Library/Developer/XcodeBuildMCP/workspaces/agent-zero-c7da5e82a1b4/result-bundles/`. Preserve selected screenshots and final results as verification evidence. Temporary Jev source/build and credential copy were removed; the owner `.env` and release archives remain unchanged. No version/build bump or TestFlight upload is part of this source update.

Synthetic tests do not prove live provider discovery or physical-device acceptance. No live presets were modified. Jev remains a separate [synthetic experiment](../../experiments/jev-a2ui/README.md); no TypeSafe credential or production chat routing was added to the app.
