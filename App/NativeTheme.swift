import SwiftUI
import WebKit
import A0Core

struct NativeTheme {
    var colors:[String:Color] = [:]
    var gradient:ServerTheme.Gradient?
    var gradientColors:[Color] = []
    var isActive:Bool { !colors.isEmpty }
    var canvas:Color { colors["background"] ?? Color("A0Canvas") }
    var panel:Color { colors["panel"] ?? Color("A0Panel") }
    var text:Color { colors["text"] ?? .primary }
    var muted:Color { colors["text-muted"] ?? .a0Supporting }
    var tint:Color { colors["primary"] ?? Color("A0Tint") }
    var input:Color { colors["input"] ?? Color("A0Panel") }
    var inputFocus:Color { colors["input-focus"] ?? input }
    var border:Color { colors["border"] ?? tint.opacity(0.2) }
    var message:Color { colors["message-bg"] ?? panel }
    var messageText:Color { colors["message-text"] ?? text }
    var onTint:Color {
        // Use contrasting ink for native filled controls rather than assuming a dark palette.
        guard let primary = colors["primary"] else { return Color("A0Canvas") }
        var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0
        UIColor(primary).getRed(&r,green:&g,blue:&b,alpha:&a)
        func linear(_ c:CGFloat)->CGFloat { c <= 0.04045 ? c/12.92 : pow((c+0.055)/1.055,2.4) }
        return 0.2126*linear(r)+0.7152*linear(g)+0.0722*linear(b) > 0.179 ? .black : .white
    }
}
private struct NativeThemeKey:EnvironmentKey { static let defaultValue = NativeTheme() }
extension EnvironmentValues {
    var a0Theme:NativeTheme { get { self[NativeThemeKey.self] } set { self[NativeThemeKey.self] = newValue } }
}
struct ThemeBackdrop:View {
    @Environment(\.a0Theme) private var theme
    var body:some View {
        GeometryReader { geometry in
            if let gradient = theme.gradient,theme.gradientColors.count == gradient.locations.count {
                let radians = gradient.angle * .pi / 180
                let width = max(1,geometry.size.width),height = max(1,geometry.size.height)
                let length = abs(width * sin(radians)) + abs(height * cos(radians))
                let dx = sin(radians)*length/(2*width),dy = -cos(radians)*length/(2*height)
                LinearGradient(stops:zip(theme.gradientColors,gradient.locations).map { .init(color:$0,location:$1) },startPoint:UnitPoint(x:0.5-dx,y:0.5-dy),endPoint:UnitPoint(x:0.5+dx,y:0.5+dy))
            } else { theme.canvas }
        }.accessibilityHidden(true)
    }
}

@MainActor @Observable final class ServerThemeStore {
    private(set) var owner:UUID?
    private(set) var name:String?
    private(set) var notice = "Uses the app’s default colors when Selectable Theme is unavailable."
    private var dark = NativeTheme()
    private var light = NativeTheme()
    private var requestID = UUID()
    func palette(darkMode:Bool,owner:UUID,enabled:Bool)->NativeTheme {
        guard enabled,self.owner == owner else { return NativeTheme() }
        return darkMode ? dark : light
    }
    func clear() { requestID = UUID(); owner = nil; name = nil; dark = NativeTheme();light = NativeTheme();notice = "Uses the app’s default colors when Selectable Theme is unavailable." }
    func refresh(_ model:SpikeModel) async {
        let generation = model.connectionGeneration,id = UUID(); requestID = id
        guard model.connected,!model.demo,let client = model.controlClient else { clear();return }
        do {
            guard let raw = try await client.serverTheme() else {
                if id == requestID,generation == model.connectionGeneration { clear();notice = "Selectable Theme is disabled. Using the app’s default colors." };return
            }
            var strings = Array(Set(raw.dark.colors.values).union(raw.light.colors.values))
            strings += (raw.dark.gradient?.colors ?? []) + (raw.light.gradient?.colors ?? [])
            let resolved = try await ThemeColorResolver().resolve(strings)
            try Task.checkCancellation()
            guard id == requestID,generation == model.connectionGeneration,model.connected else { return }
            func palette(_ value:ServerTheme.Palette)->NativeTheme {
                NativeTheme(colors:value.colors.mapValues { resolved[$0]! },gradient:value.gradient,gradientColors:(value.gradient?.colors ?? []).map { resolved[$0]! })
            }
            dark = palette(raw.dark);light = palette(raw.light);owner = generation;name = raw.name
            notice = "Matching \(raw.name). Light and dark appearance follow your selection below."
        } catch {
            guard !Task.isCancelled,id == requestID,generation == model.connectionGeneration else { return }
            clear();notice = "Server theme unavailable. Using the app’s default colors."
        }
    }
}

struct ServerThemeHost:ViewModifier {
    let model:SpikeModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @AppStorage("matchServerTheme",store:DisplayPreferences.store) private var enabled = true
    private var palette:NativeTheme { model.serverTheme.palette(darkMode:scheme == .dark,owner:model.connectionGeneration,enabled:enabled && model.connected && phase == .active) }
    private var refreshKey:String { "\(model.connectionGeneration)-\(model.connected)-\(phase == .active)-\(enabled)-\(model.themeRefreshRevision)" }
    func body(content:Content)->some View {
        content.environment(\.a0Theme,palette)
            .foregroundStyle(palette.text,palette.muted)
            .tint(palette.tint)
            .task(id:refreshKey) {
                guard enabled,phase == .active,model.connected else { model.serverTheme.clear();return }
                while !Task.isCancelled {
                    await model.serverTheme.refresh(model)
                    do { try await Task.sleep(for:.seconds(30)) } catch { return }
                }
            }
    }
}

/// A credential-free, network-disabled document resolves CSS colors (including HSL,
/// named colors and display-p3) to sRGB. Only bundled JavaScript runs; color strings
/// are passed as arguments, never interpolated into code or HTML.
@MainActor private final class ThemeColorResolver:NSObject,WKNavigationDelegate {
    private var ready:CheckedContinuation<Void,any Error>?
    private var timeout:Task<Void,Never>?
    private let web:WKWebView
    override init() {
        let config = WKWebViewConfiguration();config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame:.zero,configuration:config)
        super.init();web.navigationDelegate = self
    }
    func resolve(_ values:[String]) async throws -> [String:Color] {
        defer { web.stopLoading();web.navigationDelegate = nil;timeout?.cancel() }
        try await withCheckedThrowingContinuation { continuation in
            ready = continuation
            web.loadHTMLString("<html><head><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'none'\"></head><body></body></html>",baseURL:nil)
            timeout = Task { [weak self] in
                try? await Task.sleep(for:.seconds(8))
                guard !Task.isCancelled else { return };self?.finish(ClientError.unexpectedResponse)
            }
        }
        try Task.checkCancellation()
        let result = try await web.callAsyncJavaScript("""
            const canvas = document.createElement('canvas'); canvas.width=1; canvas.height=1;
            const ctx = canvas.getContext('2d',{willReadFrequently:true});
            return values.map(value => {
              if (!CSS.supports('color',value) || /^(currentcolor|inherit|initial|unset|revert.*)$/i.test(value.trim())) throw new Error('Unsupported theme color');
              ctx.clearRect(0,0,1,1);ctx.fillStyle=value;ctx.fillRect(0,0,1,1);
              return Array.from(ctx.getImageData(0,0,1,1).data);
            });
            """,arguments:["values":values],in:nil,contentWorld:.defaultClient)
        guard let rows = result as? [[Double]],rows.count == values.count,rows.allSatisfy({ $0.count == 4 && $0.allSatisfy { $0.isFinite && (0...255).contains($0) } }) else { throw ClientError.incompatiblePayload }
        return Dictionary(zip(values,rows).map { ($0,Color(.sRGB,red:$1[0]/255,green:$1[1]/255,blue:$1[2]/255,opacity:$1[3]/255)) },uniquingKeysWith:{ first,_ in first })
    }
    private func finish(_ error:(any Error)? = nil) {
        guard let continuation = ready else { return };ready = nil;timeout?.cancel()
        if let error { continuation.resume(throwing:error) } else { continuation.resume() }
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) { finish() }
    func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:any Error) { finish(error) }
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:any Error) { finish(error) }
}

struct ThemeNavigationChrome:ViewModifier {
    @Environment(\.a0Theme) private var theme
    func body(content:Content)->some View {
        content.toolbarBackground(theme.panel,for:.navigationBar)
            .toolbarBackground(theme.isActive ? .visible : .automatic,for:.navigationBar)
            .background { ThemeBackdrop().ignoresSafeArea() }
            .presentationBackground { ThemeBackdrop() }
    }
}


/// Per-instance UIKit styling avoids leaking one server's palette through UIAppearance.
struct ThemeSegments<Value:Hashable>:View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    let title:String
    let labels:[String]
    let values:[Value]
    @Binding var selection:Value
    let identifier:String
    var body:some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing:8) {
                ForEach(values.indices,id:\.self) { index in
                    Button { selection = values[index] } label: {
                        HStack {
                            Text(labels[index]).multilineTextAlignment(.leading)
                            Spacer(minLength:8)
                            if selection == values[index] { Image(systemName:"checkmark").accessibilityHidden(true) }
                        }.padding(12).frame(maxWidth:.infinity,minHeight:44)
                            .foregroundStyle(selection == values[index] ? theme.onTint:theme.text)
                            .background(selection == values[index] ? theme.tint:theme.input,in:RoundedRectangle(cornerRadius:10))
                    }.buttonStyle(.plain).accessibilityAddTraits(selection == values[index] ? .isSelected:[])
                }
            }.accessibilityElement(children:.contain).accessibilityLabel(title).accessibilityIdentifier(identifier)
        } else {
            ThemeSegmentControl(title:title,labels:labels,values:values,selection:$selection,identifier:identifier)
        }
    }
}
private struct ThemeSegmentControl<Value:Hashable>:UIViewRepresentable {
    @Environment(\.a0Theme) private var theme
    let title:String
    let labels:[String]
    let values:[Value]
    @Binding var selection:Value
    let identifier:String
    func makeCoordinator()->Coordinator { Coordinator(selection:$selection,values:values) }
    func makeUIView(context:Context)->UISegmentedControl {
        let control = UISegmentedControl(items:labels)
        control.addTarget(context.coordinator,action:#selector(Coordinator.changed(_:)),for:.valueChanged)
        control.setContentHuggingPriority(.defaultLow,for:.horizontal)
        return control
    }
    func updateUIView(_ control:UISegmentedControl,context:Context) {
        context.coordinator.selection = $selection
        context.coordinator.values = values
        control.selectedSegmentIndex = values.firstIndex(of:selection) ?? UISegmentedControl.noSegment
        control.accessibilityLabel = title
        control.accessibilityIdentifier = identifier
        control.backgroundColor = theme.isActive ? UIColor(theme.input) : nil
        control.selectedSegmentTintColor = theme.isActive ? UIColor(theme.tint) : nil
        let font = UIFont.preferredFont(forTextStyle:.subheadline)
        control.setTitleTextAttributes([.foregroundColor:theme.isActive ? UIColor(theme.text) : UIColor.label,.font:font],for:.normal)
        control.setTitleTextAttributes([.foregroundColor:theme.isActive ? UIColor(theme.onTint) : UIColor.label,.font:font],for:.selected)
    }
    func sizeThatFits(_ proposal:ProposedViewSize,uiView:UISegmentedControl,context:Context)->CGSize? {
        CGSize(width:proposal.width ?? uiView.intrinsicContentSize.width,height:max(44,uiView.intrinsicContentSize.height))
    }
    @MainActor final class Coordinator:NSObject {
        var selection:Binding<Value>
        var values:[Value]
        init(selection:Binding<Value>,values:[Value]) { self.selection = selection;self.values = values }
        @objc func changed(_ sender:UISegmentedControl) {
            guard values.indices.contains(sender.selectedSegmentIndex) else { return }
            selection.wrappedValue = values[sender.selectedSegmentIndex]
        }
    }
}

struct ThemeSearchField:View {
    @Environment(\.a0Theme) private var theme
    @Binding var text:String
    let prompt:String
    var body:some View {
        HStack(spacing:8) {
            Image(systemName:"magnifyingglass").foregroundStyle(theme.muted).accessibilityHidden(true)
            TextField("",text:$text,prompt:Text(prompt).foregroundStyle(theme.muted))
                .foregroundStyle(theme.text).tint(theme.tint)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search).accessibilityLabel(prompt).accessibilityIdentifier("pluginSearch")
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName:"xmark.circle.fill").foregroundStyle(theme.muted).frame(width:44,height:44) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }.padding(.leading,12).padding(.trailing,text.isEmpty ? 12:0).frame(minHeight:44)
            .background(theme.input,in:RoundedRectangle(cornerRadius:12))
            .overlay { RoundedRectangle(cornerRadius:12).strokeBorder(theme.border,lineWidth:1) }
    }
}


/// Apply the palette to every row, including conditional notices and pickers.
struct ThemeForm<Content:View>:View {
    @Environment(\.a0Theme) private var theme
    @ViewBuilder let content:Content
    var body:some View {
        Form { content.listRowBackground(theme.isActive ? theme.panel:nil).listRowSeparatorTint(theme.isActive ? theme.border:nil) }
            .scrollContentBackground(.hidden).background { ThemeBackdrop() }
            .modifier(ThemeNavigationChrome())
    }
}
struct ThemeList<Content:View>:View {
    @Environment(\.a0Theme) private var theme
    @ViewBuilder let content:Content
    var body:some View {
        List { content.listRowBackground(theme.isActive ? theme.panel:nil).listRowSeparatorTint(theme.isActive ? theme.border:nil) }
            .scrollContentBackground(.hidden).background { ThemeBackdrop() }
            .modifier(ThemeNavigationChrome())
    }
}
