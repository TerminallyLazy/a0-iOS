# Physical-device acceptance

## Purpose
Keep owner-assisted camera and authenticated HTTPS checks separate from automatic synthetic regression tests.

## Ownership
`DeviceLiveUITests` owns camera import, destination review, owner sign-in, and observation of full realtime state. The `AgentZeroDeviceAcceptance` scheme runs this target explicitly.

## Local Contracts
- Run only with the owner available and an explicitly designated physical device/server.
- Supply only the HTTPS origin through `TEST_RUNNER_A0_DEVICE_LIVE_ORIGIN`; never put credentials in environment variables, arguments, fixtures, logs, or chat.
- The owner grants camera permission, scans the supplied QR, and enters credentials on the phone. The harness verifies the reviewed origin before applying it.
- Do not submit messages, create chats, select unrelated conversations, restart servers, or weaken auth/TLS to pass acceptance.
- Automatic XCTest failure artifacts may include private UI data. Keep them local; report sanitized status/results instead of dumping live logs or screenshots.
- Tell the owner that XCTest may close the app when the test finishes. After an interactive check, launch the app normally without test arguments so it is available for ordinary use. If the owner reports a crash, inspect process/crash evidence before attributing it to teardown.
- Camera/sign-in waits are bounded. A timeout is incomplete acceptance, never evidence that the feature passed.

## Work Guidance
Use the regular `AgentZeroSpike` scheme for synthetic tests. Hardware validation uses the separate scheme and existing authorized development signing. Record real device/OS, server origin, observed transport, and evidence limits in docs/ACCEPTANCE.md.

## Verification
Build and run `AgentZeroDeviceAcceptance` with the named physical destination and select one test explicitly. `testCameraImportAndOwnerSignIn` covers camera review plus sign-in; `testOwnerSignInWithoutCamera` fills the designated origin and covers sign-in only. A passing sign-in verifies authenticated full Socket.IO state, not agent execution, network interruption, or locked-device protection.

## Child DOX Index
None.
