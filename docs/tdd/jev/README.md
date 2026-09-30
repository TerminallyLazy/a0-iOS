# Jev TDD evidence

Source: [approved Jev plan](../../JEV-PLAN.md). User approved in chat after canvas review on September 30, 2026. Swift/XCTest are the actual runners; ECC npm detection was a default with no package.json. Plan shell examples were normalized to project test/build commands; no secrets, destructive validation or remote installers were used.

## Journeys and guarantees

| Plan task | Test target | RED evidence | GREEN evidence |
| --- | --- | --- | --- |
| Candidate contract and fallback | JevContractTests | Swift compile-time RED: missing JevClient, JevChoosing, JevChoice, JevBatch and JevCoordinator; underlying contract types also not implemented | Pending |
| Secure profile credentials | JevCredentialTests; JevUITests | Same compile-time missing implementation; UI run pending | Pending |
| Bounded choice transport and durable attempts | JevTransportTests; JevReceiptTests | Same compile-time missing implementation | Pending |
| One-attempt lifecycle and stale reply rejection | JevCoordinatorTests | Same compile-time missing implementation | Pending |

RED command: `swift test --enable-code-coverage --filter Jev` exited 1 because the new tests reference missing Jev types. Existing pinned dependencies resolved successfully. No production Jev code existed at this checkpoint. Raw regenerable output: `/tmp/a0-jev-red.log`.

Native UI RED command: `xcodebuild -project AgentZeroSpike.xcodeproj -scheme AgentZeroSpike -destination 'platform=iOS Simulator,id=0758A3EE-44E9-4645-AEC3-8CA818DBF74C' -derivedDataPath /tmp/a0-jev-derived -only-testing:A0UITests/JevUITests test`. Result pending; UI test registration is included in this checkpoint and does not claim runtime RED yet.

Coverage, live API checks and physical-device acceptance remain unverified. Only synthetic credentials are in tests. Local checkpoints are retained on codex/jev-ios; no push or release is included.
