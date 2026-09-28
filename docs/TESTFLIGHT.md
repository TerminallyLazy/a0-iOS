# TestFlight preparation

## App identity

- GitHub: private `TerminallyLazy/a0-iOS`.
- App Store Connect name: **Agent Zero Mobile** (the original requested name was unavailable).
- Home Screen display name: **Agent Zero**.
- App Store Connect Apple ID: `6817147730`; SKU: `a0-ios`; primary language: English (U.S.).
- Permanent bundle ID: `com.terminallylazy.a0-ios`.
- Initial beta version/build: **0.1.0 (1)**.
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
  -archivePath build/AgentZero-0.1.0-1.xcarchive \
  -exportOptionsPlist Config/ExportOptions-TestFlight.plist \
  -exportPath build/TestFlight-0.1.0-1 \
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
