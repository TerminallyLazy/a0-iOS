# App Store screenshots

Capture actual SwiftUI views with `AppStoreScreenshotUITests`, using the DEBUG-only `--synthetic-app-store` fixture and isolated persistence. Fictional local conversations avoid exposing user data or requiring a live model/server. `--synthetic-brand-screenshot` renders the existing `LaunchSplashView` as an optional visual reference; it never changes production startup timing or demonstrates authentication.

The September 30 capture uses an iPhone 14 Plus simulator (1284 × 2778) and iPad Pro 13-inch simulator (2064 × 2752), both iOS 26.5, in dark appearance. These are accepted portrait sizes for the requested 6.5-inch iPhone and 13-inch iPad slots. Export XCTest PNG attachments unchanged and verify dimensions and `hasAlpha: no` with `sips`. Keep raw bundles/logs and the screenshot package under ignored `docs/verification/`.

The primary images show an actual native chat with fictional content. The optional launch images reproduce the native branding from the user's supplied 602 × 1306 attachment at device resolution. The original attachment is retained in the package's reference folder, not treated as a dimension-compliant upload.

Use the chat image in each required slot. Apple guideline 2.3.3 calls for app-in-use screenshots rather than merely title/login/splash images; the launch option is not a substitute for the chat image. Captures are preparation only, not an upload, submission, release or approval receipt. Do not show unreleased plugin controls in screenshots for an earlier submitted build.

Sources: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata).
