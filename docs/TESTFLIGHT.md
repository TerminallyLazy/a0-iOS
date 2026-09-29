# TestFlight preparation

## App identity

- GitHub: public `TerminallyLazy/a0-iOS`.
- App Store Connect name: **Agent Zero Mobile** (the original requested name was unavailable).
- Home Screen display name: **Agent Zero**.
- App Store Connect Apple ID: `6817147730`; SKU: `a0-ios`; primary language: English (U.S.).
- Permanent bundle ID: `com.terminallylazy.a0-ios`.
- Current source release version/build: **0.1.0 (4)**; see the upload receipt below for distribution status.
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
