import SwiftUI
import WebKit
import A0Core
import TipKit

private struct HostControlTip: Tip {
    var title:Text { Text("Switch control when you need to") }
    var message:Text? { Text("Take over pauses A0 while you interact. Return to A0 hands control back. Use the keyboard button for typing, or Capture options to inspect without clicking.") }
    var image:Image? { Image(systemName:"hand.draw") }
}

struct LiveViewerView: View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    let model: SpikeModel
    let workspaceOpen: Bool
    @State private var viewer = LiveViewerModel()
    @State private var history = false
    @State private var text = ""
    @State private var reviewed = false
    @State private var captureDetails = false
    @State private var keyboardOpen = false
    @FocusState private var typing: Bool
    @State private var height: CGFloat = 260
    @State private var resizeStart: CGFloat?
    private var captures: ConversationCaptures { ConversationCaptures(logs:model.state.logs,context:model.state.context ?? "") }
    private var fallback: BrowserScreenshot? { captures.latest(source:viewer.source == "computer_use" ? "computer":"browser") }
    private var paneHeight: CGFloat { sizeClass == .compact && (viewer.pending != nil || viewer.notice != nil) ? 180:height }
    var body: some View {
        Group {
            if !captures.history.isEmpty || viewer.held {
                VStack(spacing:0) {
                    if viewer.expanded {
                        HStack { Label(viewer.held ? "You’re in control · A0 held":"Live view expanded",systemImage:"rectangle.expand.vertical"); Spacer() }.font(.caption).padding(12)
                    } else { surface(fullScreen:false) }
                }
                .background(theme.panel).clipShape(RoundedRectangle(cornerRadius:24,style:.continuous))
                .overlay { RoundedRectangle(cornerRadius:24,style:.continuous).strokeBorder(theme.border,lineWidth:0.5) }
                .padding(.horizontal,12).padding(.vertical,6)
            }
        }
        .task(id:BrowserMediaScope(model:model).id) {
            viewer.clear()
            guard !captures.history.isEmpty,!workspaceOpen else { return }
            viewer.start(model)
        }
        .onChange(of:captures.history.first?.id) { _,_ in
            if !viewer.watching, !workspaceOpen, scenePhase == .active { viewer.start(model) }
        }
        .onChange(of:scenePhase) { _,phase in if phase != .active { viewer.suspend(); text = "" } }
        .onChange(of:workspaceOpen) { _,open in if open { viewer.suspend(); text = "" } }
        .onDisappear { viewer.suspend(); text = "" }
        .onChange(of:viewer.status?.controlling) { _,controlling in
            if controlling != true { keyboardOpen = false; text = ""; typing = false }
        }
        .fullScreenCover(isPresented:$viewer.expanded) {
            VStack(spacing:0) { surface(fullScreen:true) }
                .foregroundStyle(theme.text,theme.muted).tint(theme.tint)
                .background { ThemeBackdrop().ignoresSafeArea() }
                .interactiveDismissDisabled().onDisappear { text = "" }
        }


    }
    @ViewBuilder private func surface(fullScreen: Bool) -> some View {
        VStack(spacing:8) {
            HStack(spacing:8) {
                Label(viewer.source == "browser" ? "Browser":"Computer",systemImage:viewer.source == "browser" ? "globe":"desktopcomputer")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("liveViewerTitle")
                Text(viewer.frame != nil ? (viewer.status?.hostLabel ?? "Connected host") : (fallback?.hostLabel ?? "Captured session")).font(.caption).foregroundStyle(theme.muted).lineLimit(1)
                Spacer(minLength:0)
                Button { viewer.expanded.toggle() } label: {
                    Image(systemName:fullScreen ? "arrow.down.right.and.arrow.up.left":"arrow.up.left.and.arrow.down.right").frame(width:44,height:44)
                }.accessibilityLabel(fullScreen ? "Minimize live view":"Expand live view")
            }.padding(.horizontal,12)
            ThemeSegments(title:"Capture source",labels:["Browser","Computer"],values:["browser","computer_use"],
                          selection:Binding(get:{ viewer.source },set:{ viewer.select($0) }),identifier:"captureSource")
                .padding(.horizontal,12).disabled(viewer.busy)
            VStack(spacing:0) {
            ZStack {
                theme.canvas
                if viewer.watching, viewer.status?.supported == true, viewer.frame != nil, let web = viewer.webView { LiveWebSurface(webView:web) }
                else if let fallback {
                    BrowserScreenshotView(screenshot:fallback,scope:BrowserMediaScope(model:model),height:fullScreen ? nil:paneHeight,showsDetails:false)
                } else { ContentUnavailableView("No capture yet",systemImage:"display") }
            }.frame(maxWidth:.infinity,maxHeight:fullScreen ? .infinity:paneHeight)
                .frame(height:fullScreen ? nil:paneHeight).contentShape(Rectangle())
                .clipShape(RoundedRectangle(cornerRadius:12,style:.continuous))
                .overlay { RoundedRectangle(cornerRadius:12,style:.continuous).strokeBorder(theme.border,lineWidth:0.75) }
                controlTab.frame(maxWidth:.infinity)
            }.padding(.horizontal,12)
            if !fullScreen, sizeClass == .regular {
                Capsule().fill(theme.muted.opacity(0.4)).frame(width:50,height:5).padding(8)
                    .gesture(DragGesture().onChanged { value in
                        if resizeStart == nil { resizeStart = height }
                        height = min(500,max(180,(resizeStart ?? height) + value.translation.height))
                    }.onEnded { _ in resizeStart = nil })
                    .accessibilityLabel("Resize capture").accessibilityAdjustableAction { direction in height = min(500,max(180,height + (direction == .increment ? 40:-40))) }
            }
            HStack(spacing:8) {
                TimelineView(.periodic(from:.now,by:1)) { timeline in
                    let fresh = viewer.receivedAt.map { timeline.date.timeIntervalSince($0) < 3 } == true
                    let held = viewer.held
                    Label(held ? (viewer.status?.controlling == true ? "You’re in control":"A0 held") : fresh ? "Live capture":"Last capture",
                          systemImage:held ? "hand.raised":fresh ? "dot.radiowaves.left.and.right":"clock")
                        .font(.caption).foregroundStyle(held || fresh ? theme.tint:theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.85)
                        .accessibilityValue(held ? "A0 is paused":"")
                }
                Spacer(minLength:0)
                if fullScreen, viewer.status?.controlling == true {
                    Button {
                        keyboardOpen.toggle()
                        if !keyboardOpen { typing = false; text = "" }
                    } label: { Image(systemName:keyboardOpen ? "keyboard.chevron.compact.down":"keyboard").frame(width:44,height:44) }
                        .accessibilityLabel(keyboardOpen ? "Hide keyboard controls":"Show keyboard controls")
                        .accessibilityIdentifier("viewerKeyboard")
                }
                Menu {
                    if viewer.status?.controlling == true {
                        Toggle("Inspect / zoom without clicking",isOn:$viewer.inspect)
                    }
                    Button("Capture history",systemImage:"clock.arrow.circlepath") { viewer.suspend(); history = true }
                    Button("Capture details",systemImage:"info.circle") { captureDetails = true }
                } label: { Image(systemName:"ellipsis.circle").frame(width:44,height:44) }
                    .accessibilityLabel("Capture options")
            }.padding(.horizontal,16)
            if let pending = viewer.pending, !viewer.busy {
                VStack(alignment:.leading,spacing:4) {
                    HStack {
                        Label("Action needs review",systemImage:"exclamationmark.circle").font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Review") { reviewed = true }.frame(minHeight:44)
                            .accessibilityLabel("Review previous action")
                    }
                    Text("\(pending.title) may have completed. Check the host before continuing.")
                        .font(.caption).foregroundStyle(theme.muted).fixedSize(horizontal:false,vertical:true)
                }.padding(.horizontal,12).padding(.bottom,10)
                    .background(theme.panel,in:RoundedRectangle(cornerRadius:12,style:.continuous))
                    .overlay { RoundedRectangle(cornerRadius:12,style:.continuous).strokeBorder(theme.border,lineWidth:0.5) }
                    .padding(.horizontal,12).accessibilityIdentifier("viewerUncertain")
            } else if let notice = viewer.notice, !viewer.busy {
                Text(notice).font(.caption).foregroundStyle(theme.muted).lineLimit(fullScreen ? 5:2).padding(.horizontal,12)
            }
            if fullScreen, viewer.status?.controlling == true, keyboardOpen {
                VStack(spacing:8) {
                    HStack {
                        SecureField("",text:$text,prompt:Text("Type on host").foregroundStyle(theme.muted))
                            .accessibilityLabel("Text to type on the host")
                            .textFieldStyle(.plain).padding(10).frame(minHeight:44)
                            .background(theme.input,in:RoundedRectangle(cornerRadius:8))
                            .overlay { RoundedRectangle(cornerRadius:8).strokeBorder(theme.border,lineWidth:0.5) }
                            .textInputAutocapitalization(.never).autocorrectionDisabled().focused($typing)
                        Button("Type") {
                            let value = text; text = ""; typing = false
                            Task { await viewer.mutate("input",model:model,input:["kind":.string("text"),"text":.string(value)]) }
                        }.buttonStyle(.borderedProminent).foregroundStyle(theme.onTint)
                            .disabled(text.isEmpty || !viewer.canInput).frame(minHeight:44)
                    }
                    ScrollView(.horizontal) {
                        HStack {
                            Button("⌘A") { Task { await viewer.mutate("input",model:model,input:["kind":.string("key"),"keys":.array([.string("Meta"),.string("a")])]) } }.buttonStyle(.bordered).frame(minHeight:44)
                            ForEach(["Enter","Tab","Escape","Backspace","ArrowLeft","ArrowRight","ArrowUp","ArrowDown"],id:\.self) { key in
                                Button(key) { Task { await viewer.mutate("input",model:model,input:["kind":.string("key"),"keys":.array([.string(key)])]) } }.buttonStyle(.bordered).frame(minHeight:44)
                            }
                        }
                    }.scrollIndicators(.hidden).disabled(!viewer.canInput)
                }.padding(.horizontal,12).padding(.bottom,8)
            }
        }
        .padding(.bottom,12)
        .foregroundStyle(theme.text,theme.muted).tint(theme.tint)
        .onChange(of:viewer.inspect) { _,_ in viewer.render() }
        .sheet(isPresented:$history) { CaptureHistoryView(captures:captures.history,scope:BrowserMediaScope(model:model)) }
        .popover(isPresented:$captureDetails) {
            VStack(alignment:.leading,spacing:12) {
                Text("Live capture details").font(.headline)
                TipView(HostControlTip()).tipBackground(theme.panel)
                if let notice = viewer.notice { Text(notice).font(.caption).foregroundStyle(theme.muted) }
                Text(viewer.source == "computer_use" ? "Whole display · tap to click · two fingers to scroll. Desktop dragging is unavailable.":"Browser tab · tap to click · drag to move · two fingers to scroll.").font(.caption)
                if let date = fallback?.capturedAt, viewer.frame == nil { Text(date,style:.relative).font(.caption) }
                let elapsed = max(1, Date().timeIntervalSince(viewer.captureStartedAt ?? Date()))
                Text(String(format:"%.2f frames/s · %.1f KB/s",Double(viewer.framesReceived)/elapsed,Double(viewer.bytesReceived)/elapsed/1024))
                Text("\(viewer.framesReceived) frames received")
                if let received = viewer.receivedAt { Text(String(format:"Last received %.1f s ago",Date().timeIntervalSince(received))) }
                if let latency = viewer.lastInputLatency { Text(String(format:"Last input acknowledged in %.2f s",latency)) }
                Text("JPEG live capture; rates reflect this viewing period. Network overhead is excluded.").font(.caption)
                Button("Done") { captureDetails = false }.frame(minHeight:44)
            }.padding().frame(maxWidth:320).fixedSize(horizontal:false,vertical:true)
                .foregroundStyle(theme.text,theme.muted).tint(theme.tint)
                .presentationBackground(theme.panel).presentationCompactAdaptation(.popover)
        }
        .confirmationDialog("Have you checked the host?",isPresented:$reviewed,titleVisibility:.visible) {
            Button("I checked; allow another action") { Task { await viewer.acknowledgeUncertain(model) } }
        } message: { Text("The previous action may have happened. Clearing its receipt does not repeat it or resume A0.") }
    }
    @ViewBuilder private var controlTab: some View {
        if !viewer.watching {
            Button { viewer.start(model) } label: { Label("Watch live",systemImage:"play.circle") }
                .buttonStyle(LiveControlTabStyle())
        } else if viewer.status?.controlling == true || (viewer.held && viewer.status?.mine == true) {
            Button { Task { await viewer.mutate("return",model:model) } } label: {
                Label("Return to A0",systemImage:"arrow.uturn.backward")
            }.buttonStyle(LiveControlTabStyle())
                .disabled(viewer.busy || viewer.pending != nil)
                .accessibilityIdentifier("returnToA0")
        } else {
            Button { Task { await viewer.mutate("acquire",model:model) } } label: {
                Label(viewer.busy ? "Pausing A0…" : viewer.status?.recoverable == true ? "Recover control" : viewer.source == "browser" ? "Take over browser":"Take over computer",systemImage:"hand.draw")
            }.buttonStyle(LiveControlTabStyle())
                .disabled(viewer.busy || viewer.pending != nil || viewer.status?.supported != true || (!viewer.held && (viewer.frame == nil || viewer.receivedAt == nil)) || (viewer.held && viewer.status?.recoverable != true))
                .accessibilityIdentifier("takeOverHost")
        }
    }

}

private struct LiveWebSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView.removeFromSuperview(); return webView }
    func updateUIView(_ uiView: WKWebView,context: Context) {}
}

private struct CaptureHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let captures: [BrowserScreenshot]
    let scope: BrowserMediaScope
    @State private var selected: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:16) {
                    Picker("Capture",selection:$selected) {
                        ForEach(Array(captures.enumerated()),id:\.element.id) { index,item in
                            Text("\(index == 0 ? "Latest":"Earlier") · \(item.title) · \(index + 1)").tag(Optional(item.id))
                        }
                    }
                    if let item = captures.first(where:{ $0.id == selected }) ?? captures.first {
                        BrowserScreenshotView(screenshot:item,scope:scope,height:360)
                    }
                }.padding()
            }.navigationTitle("Capture history").toolbar { Button("Done") { dismiss() } }
                .modifier(ThemeNavigationChrome())
        }
    }
}


/// Straight top edge joins the capture; rounded lower corners mirror Workspace's edge tab.
private struct LiveControlTabStyle: ButtonStyle {
    @Environment(\.a0Theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius:16,bottomTrailingRadius:16)
        configuration.label
            .font(.subheadline.weight(.semibold)).foregroundStyle(theme.text)
            .multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
            .padding(.horizontal,20).padding(.vertical,10).frame(minHeight:44)
            .background {
                shape.fill(theme.panel)
                    .overlay {
                        shape.fill(LinearGradient(colors:[theme.tint.opacity(0.16),theme.tint.opacity(0.07)],startPoint:.top,endPoint:.bottom))
                    }
                    .shadow(color:theme.tint.opacity(isEnabled ? 0.18:0),radius:8,x:0,y:2)
                    .shadow(color:.black.opacity(0.18),radius:5,x:0,y:3)
            }
            .overlay { shape.strokeBorder(theme.tint.opacity(0.35),lineWidth:0.75) }
            .contentShape(shape).opacity(isEnabled ? (configuration.isPressed ? 0.75:1):0.45)
    }
}
