import SwiftUI

/// Branded cover for actual startup work; no invented progress or timed gate.
struct LaunchSplashView: View {
    @Environment(\.a0Theme) private var theme
    let status: String
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("AgentZeroMark").resizable().scaledToFit().frame(width: 76, height: 104)
                .accessibilityHidden(true)
            Image("AgentZeroWordmark").resizable().scaledToFit().frame(width: 224, height: 44)
                .accessibilityLabel("Agent Zero")
            Spacer()
            ProgressView(status == "Restoring session" ? "Restoring your session" : "Opening Agent Zero")
                .font(.subheadline).padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { ThemeBackdrop().ignoresSafeArea() }
        .accessibilityIdentifier("launchSplash")
    }
}
