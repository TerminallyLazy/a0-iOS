import SwiftUI

/// Keep the primary action visible above the keyboard as the form scrolls.
struct ConnectionActionBar: View {
    let model: SpikeModel
    var body: some View {
        Button { model.connect() } label: {
            HStack {
                if model.connecting { ProgressView() }
                Text(model.localDevelopment ? "Connect to local development server" : "Connect securely")
            }.frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canConnect)
        .accessibilityIdentifier("connectServer")
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
