import SwiftUI
import A0Core

/// A bounded leading drawer, kept outside the conversation navigation stack.
struct ConversationDrawer: View {
    @Environment(\.a0Theme) private var theme
    let model: SpikeModel
    let onClose: () -> Void
    let onSelect: (String) -> Void
    let onNewChat: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Button(action: onClose) { Color.black.opacity(0.35).ignoresSafeArea() }
                    .buttonStyle(.plain).accessibilityLabel("Close sidebar")
                    .accessibilityIdentifier("sidebarDismiss")
                ChatSidebarView(model: model, onSelect: onSelect, onNewChat: onNewChat, onClose: onClose)
                    .tint(theme.tint)
                    .frame(width: min(400, max(0, geometry.size.width - 44)))
                    .frame(maxHeight: .infinity)
                    .background { ThemeBackdrop().ignoresSafeArea() }
                    .transition(reduceMotion ? .opacity : .move(edge: .leading))
                    .accessibilityAddTraits(.isModal)
            }
            .accessibilityAction(.escape, onClose)
        }.accessibilityIdentifier("conversationDrawer")
    }
}
