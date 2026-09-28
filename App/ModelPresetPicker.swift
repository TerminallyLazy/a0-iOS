import SwiftUI
import A0Core

struct ModelPresetPicker:View {
    let model:SpikeModel
    @State private var workspace = ModelPresetWorkspace()
    @State private var presented = false
    @State private var editing = false
    @State private var confirmsResolved = false
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo:.body) private var popupHeight:CGFloat = 400
    var body:some View {
        Button { presented.toggle() } label: {
            HStack(spacing:6) {
                Image(systemName:"brain")
                Text(workspace.closedLabel).lineLimit(1)
                Image(systemName:"chevron.down").font(.caption2.weight(.semibold))
            }.font(.caption).foregroundStyle(Color.a0Supporting).frame(minHeight:44)
        }.accessibilityLabel("Model presets, \(workspace.closedLabel)").accessibilityIdentifier("modelPresetPicker")
            .popover(isPresented:$presented) {
                VStack(alignment:.leading,spacing:0) {
                    HStack {
                        Text("Model presets").font(.headline)
                        Spacer()
                        Button { presented = false } label: { Image(systemName:"xmark").frame(width:44,height:44) }.accessibilityLabel("Close model presets")
                    }.padding(.horizontal,16)
                    Divider()
                    ScrollView {
                        VStack(alignment:.leading,spacing:0) {
                            scopeStatus.padding(.horizontal,16).padding(.vertical,12)
                            if workspace.busy { ProgressView("Loading models…").frame(maxWidth:.infinity).padding() }
                            if let notice = workspace.notice {
                                Text(notice).font(.callout).padding(.horizontal,16).padding(.bottom,12).accessibilityIdentifier("modelPresetNotice")
                                Button("Refresh",systemImage:"arrow.clockwise") { Task { await workspace.load(model) } }.padding(.horizontal,16).disabled(workspace.busy)
                            }
                            if let pending = workspace.pending {
                                VStack(alignment:.leading,spacing:8) {
                                    Text("\(pending.title) has an unconfirmed outcome. Check the server before allowing another action.").font(.callout)
                                    Button("I checked the outcome") { confirmsResolved = true }
                                }.padding(16)
                            }
                            ForEach(workspace.presets,id:\.name) { preset in
                                Button { select(preset.name) } label: {
                                    ModelPresetSummary(preset:preset,defaultPreset:workspace.defaultPreset,selected:workspace.effectiveName == preset.name)
                                        .padding(.horizontal,16).padding(.vertical,14).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(!canSelect).accessibilityIdentifier("selectPreset-"+preset.name)
                                Divider().padding(.leading,16)
                            }
                            if workspace.presets.isEmpty && !workspace.busy {
                                Text("No model presets available.").font(.callout).foregroundStyle(Color.a0Supporting).padding(16)
                            }
                        }
                    }
                    .accessibilityIdentifier("modelPresetList")
                    Divider()
                    Button { presented = false; editing = true } label: {
                        Label("Edit presets",systemImage:"slider.horizontal.3").font(.callout.weight(.medium)).frame(maxWidth:.infinity,alignment:.leading).frame(minHeight:44)
                    }.padding(.horizontal,16).padding(.vertical,4).disabled(workspace.presets.isEmpty || !workspace.canMutate).accessibilityIdentifier("editModelPresets")
                }
                .frame(idealWidth:360,maxWidth:420).frame(height:min(popupHeight,620))
                .presentationCompactAdaptation(.popover)
                .task { await workspace.load(model) }
                .confirmationDialog("Have you checked the result on the server?",isPresented:$confirmsResolved,titleVisibility:.visible) {
                    Button("Allow another action") { Task { await workspace.resolve(model) } }
                }
            }
            .sheet(isPresented:$editing) { ModelPresetEditor(model:model,workspace:workspace) }
            .task(id:loadIdentity) { await workspace.load(model) }
            .onChange(of:model.canSubmit) { _,ready in if ready { Task { await workspace.load(model) } } }
            .onChange(of:workspace.busy) { _,busy in
                if !busy && model.canSubmit && workspace.needsReload(model) { Task { await workspace.load(model) } }
            }
            .onChange(of:scenePhase) { _,phase in if phase == .background { presented = false; editing = false; workspace.clear() } }
            .onChange(of:loadIdentity) { _,_ in presented = false; editing = false }
    }
    private var loadIdentity:String { model.connectionGeneration.uuidString + ":" + (model.chat?.selectedContext ?? "") }
    private var canSelect:Bool { workspace.canMutate && model.canSubmit && model.chat?.selectedContext != nil && workspace.overrideState?.allowed == true }
    @ViewBuilder private var scopeStatus:some View {
        if let state = workspace.overrideState {
            VStack(alignment:.leading,spacing:8) {
                Text(state.override == nil ? "Using inherited preset: \(state.configuredPreset)" : "Selection applies to this chat").font(.caption).foregroundStyle(Color.a0Supporting)
                if state.override != nil {
                    Button("Use inherited \(state.configuredPreset)",systemImage:"arrow.uturn.backward") { clearOverride() }
                        .font(.callout).frame(minHeight:44).disabled(!workspace.canMutate || !model.canSubmit).accessibilityIdentifier("inheritModelPreset")
                }
                if !state.allowed { Text("Model overrides are disabled for this chat.").font(.caption).foregroundStyle(Color.a0Supporting) }
            }
        } else {
            Text(model.chat?.selectedContext == nil ? "Create a chat to choose its model preset. Preset definitions are shared across Agent Zero." : "Checking the current chat’s model selection…").font(.caption).foregroundStyle(Color.a0Supporting)
        }
    }
    private func select(_ name:String) {
        guard canSelect,let context = model.chat?.selectedContext else { return }
        let generation = model.connectionGeneration
        Task {
            guard generation == model.connectionGeneration,context == model.chat?.selectedContext else { return }
            if await workspace.mutate(.setOverride(name:name,context:context),model:model) { presented = false }
        }
    }
    private func clearOverride() {
        guard let context = model.chat?.selectedContext else { return }
        let generation = model.connectionGeneration
        Task {
            guard generation == model.connectionGeneration,context == model.chat?.selectedContext else { return }
            if await workspace.mutate(.clearOverride(context:context),model:model) { presented = false }
        }
    }
}

struct ModelPresetSummary:View {
    let preset:ModelPresetDocument
    let defaultPreset:ModelPresetDocument?
    var selected = false
    @ScaledMetric(relativeTo:.caption) private var labelWidth:CGFloat = 48
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(preset.name).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                Spacer(minLength:6)
                if selected { Image(systemName:"checkmark").font(.callout.weight(.semibold)).accessibilityLabel("Selected") }
            }
            ForEach(preset.summaryRows(defaultPreset:defaultPreset)) { row in
                HStack(alignment:.firstTextBaseline,spacing:10) {
                    Text(row.id == "embedding" ? "Embed" : row.id == "vision" ? "Vision" : row.title).font(.caption.weight(.medium)).foregroundStyle(Color.a0Supporting).frame(width:labelWidth,alignment:.leading)
                    VStack(alignment:.leading,spacing:2) {
                        Text(row.name.isEmpty ? "Not configured" : row.name).font(.caption).foregroundStyle(.primary).lineLimit(2)
                        if !row.provider.isEmpty { Text(row.provider).font(.caption2).foregroundStyle(Color.a0Supporting) }
                    }
                    Spacer(minLength:0)
                }
            }
        }.accessibilityElement(children:.combine)
    }
}
