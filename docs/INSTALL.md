# Install Agent Zero Mobile

Agent Zero Mobile is a native companion for your own Agent Zero server. It runs on **iPhone and iPad with iOS/iPadOS 17 or later**. You will need an authenticated Agent Zero instance reachable over HTTPS to use live chats.

## TestFlight beta

**Public invitations are not available yet.** The first build, **0.1.0 (2)**, has finished processing in TestFlight. Beta review must complete before the public beta opens; there is no confirmed availability date.

When the beta is ready:

1. Install [Apple TestFlight](https://apps.apple.com/app/testflight/id899247664) on your iPhone or iPad.
2. Open the Agent Zero Mobile invitation from the [repository's Get the app section](../README.md#get-the-app).
3. Accept the invitation in TestFlight, tap **Install**, then open Agent Zero.
4. [Connect to your server](#connect-to-your-server).

Installing TestFlight alone does not add the app. A source ZIP is for building on a Mac, and an App Store-signed IPA is not a direct-install download. Until a verified beta invitation is published, the source-build route below is the available option.

## Build from source

You need a Mac with **Xcode 27**. The app supports iOS 17+, but its current Swift package dependencies require the newer development toolchain. Xcode downloads those pinned packages automatically; no manual dependency installation or XcodeGen setup is needed.

1. [Download the source ZIP](https://github.com/TerminallyLazy/a0-iOS/archive/refs/heads/main.zip) and unzip it, or clone `https://github.com/TerminallyLazy/a0-iOS.git`.
2. Open **AgentZeroSpike.xcodeproj** in Xcode. Allow package resolution to finish.
3. Select the **AgentZeroSpike** scheme in the toolbar.
4. Choose an iPhone/iPad Simulator and click **Run**. Choose **Explore synthetic preview** in the app to look around without a server, or connect to your HTTPS server.

To run on your own device instead of Simulator:

1. Connect and unlock your iPhone or iPad. Add your Apple account in Xcode's settings if needed.
2. Select the **AgentZeroSpike** app target, open **Signing & Capabilities**, enable automatic signing and choose your development team.
3. Use a unique bundle identifier for your personal build if your team cannot sign `com.terminallylazy.a0-ios`, for example `com.yourname.agentzero`. Keep these personal signing changes local.
4. Select your device in the toolbar and click **Run**. Follow any device-trust or Developer Mode prompts from Xcode and iOS.

Development signing may require periodic reinstallation. TestFlight will be the simpler route when the public invitation becomes available. Changing the bundle identifier creates a separate installation with separate local drafts and Keychain access.

## Connect to your server

The mobile app needs your existing Agent Zero server to be running. Enable Agent Zero login, and provide an HTTPS address the phone can reach. If the server runs on your computer, use your configured HTTPS tunnel or another reachable HTTPS endpoint.

1. Open the server address in Safari on the phone and confirm the Agent Zero sign-in page is reachable.
2. Enter the **origin only** in the app, such as `https://your-agent.example.com`. Leave out paths, query parameters and embedded credentials. You can also scan a plain HTTPS URL QR code and review it before applying.
3. Enter your Agent Zero username and password directly in the app. Password saving is optional.
4. Tap **Connect securely** above the keyboard, then open an existing chat or start a new one.

The app requires authenticated HTTPS even when a tunnel is used. `localhost` on your phone refers to the phone, not your computer. A tunnel address changing or expiring requires updating the saved server address.

## If something does not work

| What you see | What to do |
| --- | --- |
| No Agent Zero app in TestFlight | A public invitation has not been published yet, or has not been accepted. Check the README's beta status. |
| Server cannot be reached | Open its URL in Safari on the same device; confirm the server and tunnel are running. |
| Sign-in or HTTPS error | Use the HTTPS origin and Agent Zero credentials. Check that server login is enabled and its certificate is valid. |
| Polling connection status | Polling is a supported connection mode. Tap the composer status dot for details. |
| A send has an unknown outcome | Check the conversation before trying again. The app retains its delivery record and does not automatically replay it. |
| Xcode cannot resolve packages | Check your connection and Xcode version, then retry package resolution. Keep the supplied package lockfiles. |
| Signing fails | Choose your own team and a bundle identifier it can sign. Simulator runs do not require physical-device signing. |

For a bug report, include the app version, device/iOS version, steps and the visible error text in a [GitHub issue](https://github.com/TerminallyLazy/a0-iOS/issues). Remove credentials, private server addresses and chat content from reports and screenshots.

See [known limits and acceptance](ACCEPTANCE.md) for feature verification, or [TestFlight preparation](TESTFLIGHT.md) for maintainer release instructions.
