import SwiftUI
import A0Core

struct ConnectionStatusButton: View {
    let model: SpikeModel
    @State private var showingDetails = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var tone: ConnectionIndicator.Tone {
        ConnectionIndicator(status:model.status,ready:model.canSubmit,synchronizing:model.state.needsFullSync).tone
    }
    private var color: Color {
        switch tone {
        case .live: .green
        case .polling: .blue
        case .working: .orange
        case .attention: .red
        case .offline: .secondary
        }
    }
    var body: some View {
        Button { showingDetails.toggle() } label: {
            Circle().fill(color).frame(width:10,height:10)
                .overlay { Circle().strokeBorder(Color.primary.opacity(0.22),lineWidth:1) }
                .frame(width:44,height:44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Connection status").accessibilityValue(model.status)
        .accessibilityHint("Shows connection details and recovery options")
        .accessibilityIdentifier("connectionStatus")
        .popover(isPresented:$showingDetails,arrowEdge:.bottom) {
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    HStack(alignment:.top) {
                        Label(model.status,systemImage:tone == .live ? "bolt.horizontal.circle" : tone == .attention ? "exclamationmark.circle" : "network")
                            .font(.headline).fixedSize(horizontal:false,vertical:true)
                            .layoutPriority(1)
                        Spacer(minLength:8)
                        Button { showingDetails = false } label: {
                            Label("Close",systemImage:"xmark").labelStyle(.iconOnly)
                                .frame(width:44,height:44).contentShape(Rectangle())
                        }
                    }
                    Text(model.detail).font(.subheadline).foregroundStyle(Color.a0Supporting)
                        .fixedSize(horizontal:false,vertical:true)
                    if model.state.paused { Label("Agent is paused",systemImage:"pause.circle").font(.subheadline) }
                    if model.recoveryStopped {
                        Button { model.retrySync() } label: {
                            Label("Retry sync",systemImage:"arrow.clockwise").frame(minHeight:44).contentShape(Rectangle())
                        }.accessibilityIdentifier("retryConnectionSync")
                    }
                }.padding(16)
            }.frame(idealWidth:dynamicTypeSize.isAccessibilitySize ? 420 : 300,
                    maxWidth:dynamicTypeSize.isAccessibilitySize ? 480 : 340,
                    maxHeight:dynamicTypeSize.isAccessibilitySize ? 520 : 360)
                .fixedSize(horizontal:false,vertical:true)
                .presentationCompactAdaptation(.popover)
        }
    }
}
