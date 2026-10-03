# TestFlight preparation

## Build 9 release scope — October 3, 2026

Build 9 makes model presets selectable on the new-chat screen as soon as the
server collection loads. The composer immediately shows the choice and retains
it with the profile-isolated draft. Explicit first Send creates the chat,
applies its preset, then submits the message. Rejected or unconfirmed preset
changes retain the draft and do not fall back to a different model or replay.
Use inherited clears the draft choice; existing chat selection and shared
preset editing retain their current scope.

App Store Connect reported build 8 as the latest processed and uploaded build
before selecting build 9. Local verification passed 316 package tests and all
four preset UI cases. The final cold-launch simulator rerun completed with
TEST SUCCEEDED; the earlier four-case runner was stopped after all cases passed
because its result collection stalled. These are synthetic checks, not physical
device or live-provider acceptance. Archive and distribution receipts are recorded below.

## Build 9 distribution — October 3, 2026

[PR #6](https://github.com/TerminallyLazy/a0-iOS/pull/6) merged the startup preset
selection fix and build bump. The signed **0.1.0 (9)** archive came from exact
merge revision `d693f3d08773a448cd3e735c272f36a4181a1582` and passed
`scripts/verify-release.py`. The Codex TestFlight Release workflow used the
existing Xcode signing account; its separate API-key env file was absent.
Upload returned `Uploaded package is processing`, `Upload succeeded` and
`EXPORT SUCCEEDED`.

App Store Connect build `4761c754-0e06-48e7-89c4-16ae913b85fb` finished as
`VALID`, with `APP_STORE_ELIGIBLE` audience and exempt encryption. English
What to Test notes were saved and read back exactly. Both existing **Internal
Testers** and **Public Beta** groups have explicit assignment. Following beta
review submission, the API confirmed `IN_BETA_TESTING` for internal and external
distribution. No testers were added and no existing build was expired.

Release verification passed 316 package tests, six WebUI adapter tests and the
native preset cases described above. RecurseML analysis errored and CodeRabbit
skipped review; neither is counted as completed hosted review. PR #6 merged
normally without a branch-protection override. TestFlight availability does not
establish physical-device installation or live-provider acceptance.

Retained local evidence includes `build/AgentZero-0.1.0-9.xcarchive` with dSYMs,
archive/upload/test logs, `build/build-9-source.txt`,
`build/build-9-upload-receipt.json`, and App Store Connect note/group/state
read-backs under `build/build-9-*`. Project-owned build caches and disposable
test bundles were removed; the signed archive passed verification again.
`build/cleanup-build-9-receipt.json` records the scoped cleanup. Owner
configuration, credentials, older archives and unrelated work were preserved.

## Build 8 release scope — October 1, 2026

Build 8 includes the merged chat-independent Computer status correction: explicit
Launcher permissions display as Allowed/Off, missing information is Not reported,
and host-ID-matched setup results can display Prepared/Tested before selecting a
chat. Presence never enables a targeted host send without a reviewed chat target.
The existing live viewer, exclusive takeover, themes and guided setup remain.

The matching desktop connector persistence fix is merged in
[connector fork PR #3](https://github.com/TerminallyLazy/a0-connector/pull/3).
It adds idle heartbeat, stale CDP recovery, a bounded screenshot-compatible
message size and extended Launcher gateway retries. The final connector suite
passed 1,070 tests with 11 skips against the complete matching Core plugin fixture.
The installed macOS preview passed browser typing/capture and computer capture;
a Chrome socket remained idle for six minutes and answered on the same connection.
No Core changes were needed for persistence. This iOS upload does not install
desktop components: upstream connector PR #28 and Launcher PR #23 are still
pending, and not all public companion installers contain these changes.

App Store Connect confirmed 7 as the latest processed/uploaded build before
selecting build 8. Release checks passed 307 package tests, six WebUI adapter
tests and four focused iPhone setup/viewer UI tests, including both appearance
modes. Distribution and archive receipts are recorded separately.

## Build 8 distribution — October 1, 2026

[PR #5](https://github.com/TerminallyLazy/a0-iOS/pull/5) merged the build bump and
beta notes. The signed **0.1.0 (8)** archive came from exact merge revision
`558bfbdafcc50c8da80aa51b54742ddc2ee9f3b7`; `scripts/verify-release.py` passed.
Xcode upload reported `Upload succeeded` and `EXPORT SUCCEEDED`. App Store
Connect build `864fb560-1c9b-4d23-85c8-7fe33f3388f4` finished processing as
`VALID` with `APP_STORE_ELIGIBLE` audience and exempt encryption. English test
notes were saved and read back exactly. Both existing **Internal Testers** and
**Public Beta** groups were assigned; after beta review submission, the API
confirmed `IN_BETA_TESTING` for both internal and external distribution.
No testers were added and no existing build was expired.

The release passed 307 package tests, six WebUI adapter tests and four focused
iPhone setup/viewer UI tests. Optional RecurseML analysis errored and CodeRabbit
skipped review; neither is counted as completed hosted review. PR #5 merged
normally without a branch-protection override. TestFlight availability is not
physical-device installation acceptance of the distributed build. The separately
installed Mac connector passed the live checks described above; broader desktop
installer rollout still depends on the upstream companion PRs.

Retained local evidence: `build/AgentZero-0.1.0-8.xcarchive` with dSYMs,
`build/testflight-archive-8.log`, `build/testflight-upload-8.log`,
`build/build-8-source.txt`, `build/build-8-upload-receipt.json`, and App Store
Connect note/group/state receipts under `build/build-8-*`. Project-owned release
caches were removed and the archive verified again. Owner configuration,
credentials, older archives and unrelated work were preserved.

## App identity

- GitHub: public `TerminallyLazy/a0-iOS`.
- App Store Connect name: **Agent Zero Mobile** (the original requested name was unavailable).
- Home Screen display name: **Agent Zero**.
- App Store Connect Apple ID: `6817147730`; SKU: `a0-ios`; primary language: English (U.S.).
- Permanent bundle ID: `com.terminallylazy.a0-ios`.
- Current source release version/build: **0.1.0 (9)**; see the upload receipt below for distribution status.
- Minimum deployment: iOS 17, iPhone and iPad.
- Existing Xcode project/scheme names remain `AgentZeroSpike` for build/test continuity; these are not the displayed app name or bundle ID.

The new bundle ID is a separate app from the earlier `local.agentzero.AgentZeroSpike` development installation. Its sandbox and Keychain access are separate; first launch requires sign-in. Keep the earlier app if its local drafts are still needed.

## Source and local signing

`project.yml` owns version/build values. `App/Info.plist` uses their build-setting substitutions. When bumping a build, edit `project.yml`, run `xcodegen generate`, then commit both generated and source changes. Preserve both package lockfiles.

Set `A0_DEVELOPMENT_TEAM` locally to the intended Apple Developer team. Do not put its value, signing profiles or API credentials in Git. `Config/Signing.example.xcconfig` describes an optional ignored local file for Xcode.

```sh
export A0_DEVELOPMENT_TEAM=YOUR_TEAM_ID
scripts/prepare-testflight.sh
```

This script uses the release skill's archive workflow, never uploads, and refuses to overwrite an existing archive. Build products stay under ignored `build/`. It verifies identity, versions, standard-encryption declaration, privacy resources, bundled notices, app dSYM and local code signature.

To prepare an App Store-signed IPA locally after archiving:

```sh
xcodebuild -exportArchive \
  -archivePath build/AgentZero-0.1.0-2.xcarchive \
  -exportOptionsPlist Config/ExportOptions-TestFlight.plist \
  -exportPath build/TestFlight-0.1.0-2 \
  -allowProvisioningUpdates
```

The committed export options use `destination=export`, not upload. They do not permanently restrict the build to internal-only testing. No testers are invited or notified by either command.

## Distribution preparation

The app declares no tracking, app-owned local preferences (`CA92.1`), metadata for app-container files (`C617.1`) and explicitly selected documents (`3B52.1`). These correspond to the code's actual UserDefaults and bounded file-import/storage use; see [Apple's reason descriptions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons). Starscream supplies its own bundled privacy manifest. HTTPS, Keychain and platform encryption are used; no custom non-exempt encryption is implemented.

The icon is 1024 square with no alpha channel. Its original pixels were already fully opaque; only the redundant channel was removed. Full SDK and Agent Zero artwork notices ship in the app and Settings → Acknowledgments. The synthetic demo stays explicitly labeled and offline; Debug automation transports remain gated.

Before uploading, select the existing [Agent Zero Mobile app record](https://appstoreconnect.apple.com/apps/6817147730/distribution/info) and confirm the intended Apple team, version and unused build number. The Codex TestFlight Release skill (`codex-ios-api-build`) workflow supports API-key archive/export/upload and beta notes; keep credentials outside this repository. The installed skill's uploader uploads immediately, so do not run it during preparation-only work.

Use [prepared What to Test notes](TESTFLIGHT-WHAT-TO-TEST.md). Apple processing, export compliance, group assignment and beta review are distinct gates. A signed local archive or exported IPA is not evidence that a build is in TestFlight. Apple requires a [matching app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app).

Before external beta review, publish a reviewed privacy policy and support contact, expose the policy in the app, and supply appropriate review access to an authenticated HTTPS server. Do not commit review credentials or owner server data. Live screenshot rendering, actual attachment processing and queue/interruption behavior remain beta acceptance items; synthetic checks do not establish them.

## Preparation receipt

On September 28, 2026, Xcode 27.0 (27A266a) produced and verified a signed Release archive and App Store export for **0.1.0 (1)**:

- Local archive: `build/AgentZero-0.1.0-1.xcarchive`.
- Local exported IPA: `build/TestFlight-0.1.0-1/AgentZeroSpike.ipa`.
- Archive verification passed identity/version checks, exempt-encryption value, app and Starscream privacy manifests, notices, app dSYM and code-signature validation.
- Export completed with `EXPORT SUCCEEDED`; the exported IPA was independently checked for bundle ID, version/build and included privacy/notices resources.
- The status dot now sits at the upper-right inside the input card; test-first RED exposed its former location, and the corrected iPhone and maximum-text iPad geometry/long-draft tests passed.

No upload, tester assignment, invitation or beta-review submission was performed. The initial read-only App Store Connect app query returned no matching app record; the owner subsequently authorized creating it in Chrome (see record-creation receipt below). Xcode's existing signing account successfully handled archive/export; the separate CLI provisioning query rejected its current API credentials, and its configured key-file fallback was absent. Repair that authentication before using the plugin's API uploader, or use Xcode Organizer after creating the matching app record. Never share credentials in chat or commit them.

The 192 package tests from the implementation slice remain the current core/generated baseline; this preparation changed app layout, release metadata and bundled resources. Raw local logs and archives remain ignored. The test reports in `docs/tdd` are authored summaries, not redistributable raw owner-device logs.

Exported IPA SHA-256: `fe99dfdf65d9efddeb028b71946e7b5e69aa129f9dbb77501d91c7648880ffef`.

## App Store Connect record — September 28, 2026

Created the iOS app through the owner-authorized Chrome session. Apple rejected the name **Agent Zero** as already used; the owner selected **Agent Zero Mobile**, which succeeded. App Information confirms bundle ID `com.terminallylazy.a0-ios`, SKU `a0-ios`, primary language English (U.S.) and Apple ID `6817147730`.

TestFlight now has an **Internal Testers** group with automatic distribution disabled. The confirmed state is **0 testers, 0 builds**. No build was uploaded, no testers were invited and no review was submitted. The site-created App Store version remains its default 1.0 draft; the prepared TestFlight binary remains 0.1.0 (1). These are separate tracks.

Browser proof screenshots remain local under ignored `build/asc-record/`. The new app record removes the registration prerequisite for uploading the prepared archive. Xcode account signing worked during preparation; the API uploader still needs a valid configured key as documented above.


## Build 2 upload and public source — September 28, 2026

The owner authorized making the source repository public; GitHub confirms PUBLIC. The README and [installation guide](INSTALL.md) provide TestFlight status and an immediate Xcode source-build route without claiming an App Store IPA is directly installable.

Apple rejected the first upload because the app had no supported orientation declaration for iPad multitasking. `project.yml` now explicitly declares all four orientations, and `scripts/verify-release.py` checks them. Xcode regenerated the project and produced a verified signed **0.1.0 (2)** archive. Upload through the existing Xcode account completed with `Uploaded package is processing`, `Upload succeeded`, and `EXPORT SUCCEEDED`. App Store Connect subsequently shows upload **Complete** and build **Ready to Submit**. This proves Apple processing, not beta-review approval or device installation.

Current archive: `build/AgentZero-0.1.0-2.xcarchive`. Upload logs and Photos exports remain local under ignored `build/`. Public TestFlight invitations remain unavailable until the external beta is configured and approved. Historical build-1 receipts above describe preparation at that time.


The processed build's Agent Zero icon was visually verified in App Store Connect's build picker. English (U.S.) What to Test notes were saved. An empty **Public Beta** external group was created; adding its first build requires beta description, feedback email, review contact and sign-in access. These owner-specific fields are not invented. No beta review has been submitted and no public invitation is active.

Three original 1179 × 2556 PNG screenshots were exported from the owner's September 28 Photos captures: chat, model presets and sidebar. The Settings image was excluded because it exposes the owner's server address. App Store Connect confirms **3 of 10 screenshots** in the English (U.S.) 6.3-inch slot. The upload was verified visually after the owner enabled Chrome file access. Larger iPhone and iPad screenshots remain separate App Store submission requirements; they are not fabricated by stretching the originals.


## External review and public invitation

On the next owner-authorized continuation, App Store Connect showed **0.1.0 (2) — Waiting for Review**, assigned to **Public Beta**. The review information had been completed and the build submitted between checks; no credentials were read or copied into this repository.

Created the public invitation, open to anyone, without an additional tester limit: https://testflight.apple.com/join/xqAFS5er. App Store Connect explicitly states that testers cannot join until the group has an approved build. The public URL currently shows Apple's general TestFlight page. README and INSTALL expose the link with this pending-review status and the source-build fallback. No approval, tester installation or App Store release is claimed. Local proof: `build/asc-release/public-link-pending.png`.


## Release verification and cleanup

Rechecked the live TestFlight iOS build list: **0.1.0 (2)** upload **Complete**, assigned to **Public Beta**, **Waiting for Review**. The same build is now attached and saved under the App Store 1.0 draft, where its Agent Zero icon appears under Included Assets. The app-record header still displayed a placeholder; this is distinct from the verified bundled icon. No duplicate upload or rebuild was needed because app sources, project configuration and package locks are unchanged since the verified build-2 source commit `0b47222`.

GitHub has no open pull requests or additional local branches to merge. Release work is committed directly on `main`; the remote ref is verified after pushing. The public prerelease `v0.1.0-beta.2` provides GitHub's source archives, an installation guide and the public TestFlight invitation. It does not offer an App Store-signed IPA as a direct-install download. Personal Xcode signing is the pre-approval installation route; public TestFlight awaits Beta App Review.

Cleanup removed 302 verified disposable targets, about **4.09 GiB** of allocated storage: SwiftPM build cache, this project's identified Xcode DerivedData, raw XCTest result bundles/logs, and the superseded build-1 archive/export. Preserved all tracked source and authored reports, the signed build-2 archive and dSYMs, selected Photos exports, release upload receipts, proof screenshots and local signing configuration. Historical raw-test and build-1 paths above are no longer expected to exist after cleanup. The retained build-2 archive passed the release verification script again.

## Build 3 — composer Stop

On September 28, 2026, source commit `797c69f` was archived as **0.1.0 (3)** using Xcode 27.0 and the existing signing account. This build includes the composer Stop implementation in `eac4510`: scoped task-tree cancellation, queue clearing, local voice stop, draft preservation and explicit unknown-outcome handling. The implementation passed 198 package tests and three focused simulator checks before the version-only release preparation.

The signed archive passed `scripts/verify-release.py`; upload completed with `Uploaded package is processing`, `Upload succeeded` and `EXPORT SUCCEEDED`. App Store Connect then reported **Complete**. English (U.S.) Stop-focused What to Test notes were saved, and build 3 was assigned to the existing **Internal Testers** group (one tester), where its status is **Testing**. No new testers or account access were added.

Apple disabled assignment to **Public Beta** because build 2 from version 0.1.0 is still **Waiting for Review**. Its UI permits only one build of this version in Beta App Review until approval. Build 3 is uploaded and internally distributed, but has not been submitted for external beta review. The existing public link and build-2 submission were preserved.

Cleanup removed **2.11 GiB** of regenerated SwiftPM and project-owned Xcode DerivedData caches. Retained both signed release archives and dSYMs, upload receipts, screenshots and local signing configuration. The build-3 archive passed verification again after cleanup. Local evidence remains under ignored `build/`: `AgentZero-0.1.0-3.xcarchive`, `testflight-upload-3.log`, `cleanup-build-3-receipt.json`, and `asc-release/build-3-internal-testflight.png`. Device installation and real-server Stop acceptance are separate from this distribution receipt.


## Build 4 preparation — model catalogs and activity

Build 4 packages implementation `3990d74`: WebUI provider catalogs, provider-specific model suggestions/search/custom IDs, and the refined expandable agent activity timeline. The implementation passed 203 package tests and focused iPhone/iPad UI checks recorded in `docs/tdd/model-catalog/README.md`. Jev remains a synthetic experiment, not production routing. This release preparation changes version metadata and test notes only. Archive, upload and distribution are verified separately below.


On September 28, 2026, release source `49d066d` produced the signed **0.1.0 (4)** archive. `scripts/verify-release.py` passed, and upload through the existing Xcode signing account reported `Uploaded package is processing`, `Upload succeeded` and `EXPORT SUCCEEDED`. App Store Connect independently showed build 4 as **Processing**.

Cleanup removed **2.15 GiB** of regenerated project-owned SwiftPM and Xcode DerivedData caches after upload completed. Signed build-2, build-3 and build-4 archives/dSYMs, selected screenshots, Photos exports, local signing configuration and the owner `.env` were preserved. The build-4 archive passed verification again after cleanup. Local receipts: `build/AgentZero-0.1.0-4.xcarchive`, `testflight-archive-4.log`, `testflight-upload-4.log`, `build-4-upload-receipt.json` and `cleanup-build-4-receipt.json`.


## Build 5 preparation — plugins, Workspace and themes

Build 5 packages native Custom/Built-in/Plugin Hub management, thumbnails and journaled lifecycle commands; isolated embedded plugin settings/main screens; the draggable A0 Workspace tab and registered tool tiles; panel-only plugin support; and native Selectable Theme matching with themed controls and sheet safe areas. DEBUG-only screenshot fixtures and synthetic verification evidence are included in source, not activated in production.

Release preflight on September 30 passed 208 package tests and six WebUI adapter tests. Focused iPhone/iPad UI and direct iPhone installation receipts are recorded in ACCEPTANCE.md. App Store Connect was checked live before choosing build 5: build 4 is Testing for Internal Testers and Public Beta, with no build 5 present. The plugin API-key configuration is absent; use its archive/export/upload workflow with the existing Xcode account and the authenticated App Store Connect browser for notes and group verification. Publication receipts will be recorded after upload.


## Build 5 distribution — September 30, 2026

[PR #1](https://github.com/TerminallyLazy/a0-iOS/pull/1) merged plugin, Workspace and theme work plus release metadata into `main`. Archive source is exactly `f7c28c8a72384a8228cf7a76e825ad8f1ab2cdf8`. The signed **0.1.0 (5)** archive passed `scripts/verify-release.py`, including identity/build, all four iPad orientations, exempt-encryption declaration, privacy/notices resources, dSYM and code signature. Both bundled WebUI adapters match source.

The Codex TestFlight Release archive/export workflow used the existing Xcode signing account because its API-key configuration is absent. Upload returned `Uploaded package is processing`, `Upload succeeded` and `EXPORT SUCCEEDED`. The authenticated App Store Connect browser independently confirmed **Complete** and then **Testing**, with **Internal Testers** and **Public Beta** attached and two invitations shown. English (U.S.) What to Test notes were saved. Build 4 remains available; no existing build was expired and no new tester or access grant was created. This is TestFlight distribution, not App Store production submission or installation acceptance for build 5.

The [build-5 GitHub prerelease](https://github.com/TerminallyLazy/a0-iOS/releases/tag/v0.1.0-beta.5) targets that exact merge revision. README and INSTALL now describe the available public beta rather than the historical build-2 review wait.

Local retained artifacts: `build/AgentZero-0.1.0-5.xcarchive` with dSYMs, `build/testflight-archive-5.log`, `build/testflight-upload-5.log`, `build/build-5-source.txt`, and `build/build-5-upload-receipt.json`. Local plans, owner environment/signing configuration, old archives and credentials were not added to Git. The release check ran 208 package tests and six JavaScript adapter tests; earlier focused UI/device evidence remains in ACCEPTANCE.md.


## Build 6 preparation — Jev, rich replies and inline media

Build 6 packages optional per-profile Jev setup, the expanded native A2UI and chart catalog, inline audio/video with shared foreground audio ownership, discoverable subagent chats, themed Agents surfaces and combined Send/Stop composer controls. Implementation and focused iPhone/iPad evidence are recorded in `docs/tdd/jev`, `docs/tdd/charts-media`, `docs/tdd/composer-jev` and `docs/tdd/agents-media-theme`.

Release preflight passed 286 package tests (219 core, 67 generated UI). App Store Connect was checked live before choosing build 6: build 5 was the newest upload and was Testing for Internal Testers and Public Beta. Archive and distribution receipts follow separately; synthetic media/speech checks do not establish live provider or physical-device audio acceptance.


## Build 6 distribution — September 30, 2026

[PR #2](https://github.com/TerminallyLazy/a0-iOS/pull/2) merged the Jev, A2UI, composer, inline media, subagent and theme changes into `main`. Archive source is exactly `62c2f502453a1b396cbfc2eaf07461ebb2d23333`. Local release checks passed 286 package tests and six WebUI adapter tests. Recurse's hosted analysis returned a service error, CodeRabbit skipped automatic review, and Qodo was unavailable; these are not counted as successful hosted review. The PR had no required checks and was merged normally after the recorded local code/security reviews and verification.

The signed **0.1.0 (6)** archive passed `scripts/verify-release.py`. The Codex TestFlight Release workflow used the existing Xcode signing account because its API-key configuration is absent. Upload reported `Uploaded package is processing`, `Upload succeeded` and `EXPORT SUCCEEDED`. App Store Connect independently confirmed **Complete** and then **Testing**, with **Internal Testers** and **Public Beta** attached and three invitations shown. English (U.S.) What to Test notes were saved. Build 5 remains Testing; this release did not expire an existing build or add testers. This is TestFlight distribution, not App Store production submission or physical-device acceptance of the distributed build.

Retained local artifacts: `build/AgentZero-0.1.0-6.xcarchive` with dSYMs, `build/testflight-archive-6.log`, `build/testflight-upload-6.log`, `build/build-6-source.txt` and `build/build-6-upload-receipt.json`. Task-owned temporary DerivedData and upload configuration were removed; the signed archive passed verification again afterward. Owner configuration, credentials, other release archives and unrelated work were preserved.

The merged feature branch was removed locally and remotely after release. Final distribution evidence is retained in ignored `build/asc-release/build-6-testing.jpg`.


## Build 7 distribution — October 1, 2026

[PR #3](https://github.com/TerminallyLazy/a0-iOS/pull/3) merged the Browser/Computer live viewer, exclusive takeover/recovery, theme and control-tray refinements, native Computer setup and contextual TipKit guidance. The signed **0.1.0 (7)** archive came from exact merge revision `60ef30d69f73fb33981ee576f3db4d9879e25300`; `scripts/verify-release.py` passed. Upload using the existing Xcode signing account reported `Upload succeeded` and `EXPORT SUCCEEDED`. App Store Connect finished processing, saved the English (U.S.) What to Test notes, and showed **Testing** with both existing **Internal Testers** and **Public Beta** groups assigned. No existing build was expired and no new tester was added. This is beta distribution, not App Store production release or installation acceptance of the distributed build.

The matching [Core PR #21](https://github.com/TerminallyLazy/agent-zero/pull/21) and [connector fork PR #1](https://github.com/TerminallyLazy/a0-connector/pull/1) are merged. [Connector upstream PR #28](https://github.com/agent0ai/a0-connector/pull/28) and [Launcher upstream PR #23](https://github.com/agent0ai/a0-launcher/pull/23) await maintainer review. Launcher source is pushed at `4d8267ad178298012ab5ad80c605637adacd1361`; no new public companion installer/package has been published. Host features require matching companion capabilities; older installations retain ordinary chat/history. Packaged browser-to-OS app-link dispatch was not conclusively verified, and Windows/Linux native setup acceptance remains pending. The manual setup-code path is available.

Release checks passed 237 Swift package tests, six WebUI adapter tests, 52 focused Core tests, 29 connector tests, and 183 Launcher tests (one skip). The full connector suite retains the identical 75 failures found on unchanged upstream in the same environment; this is not a green full-suite claim. Hosted review integrations were unavailable or skipped and are not counted as completed reviews. Owned PRs were merged normally without overriding branch protections. The Mac setup checks and physical iPhone recovery/Return to A0 acceptance are recorded in ACCEPTANCE.md, separately from build-7 distribution.

Retained artifacts: `build/AgentZero-0.1.0-7.xcarchive` with dSYMs, `build/testflight-archive-7.log`, `build/testflight-upload-7.log`, `build/build-7-source.txt`, `build/build-7-upload-receipt.json`, and `build/asc-release/build-7-testing.png`. The isolated packaged Launcher test was stopped and unregistered; its local link-test server was stopped. The installed Launcher connection, its existing scopes, tunnel, owner credentials/configuration and unrelated working-tree changes were preserved.
