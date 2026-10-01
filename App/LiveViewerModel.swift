import SwiftUI
import WebKit
import A0Core

@MainActor @Observable final class LiveViewerModel {
    let viewerID = UUID().uuidString.replacingOccurrences(of:"-",with:"").lowercased()
    var status: LiveViewerStatus?
    var frame: LiveFrame?
    var source = "browser"
    var notice: String?
    var busy = false
    var watching = false
    var expanded = false
    var inspect = false
    var pending: ControlJournal.Receipt?
    var receivedAt: Date?
    var framesReceived = 0
    var bytesReceived = 0
    var measuredLatency: Double = 0
    var captureStartedAt: Date?
    var lastInputLatency: Double?
    private var owner: String?
    private var poll: Task<Void,Never>?
    private var revision = UUID()
    private(set) var webView: WKWebView?
    private var bridge: LiveViewerBridge?
    var canInput: Bool { watching && status?.controlling == true && pending == nil && !busy && !inspect && receivedAt.map { Date().timeIntervalSince($0) < 5 } == true }
    var held: Bool { status.map { $0.phase != "watching" } ?? false }
    func identity(_ model: SpikeModel) -> String { model.connectionGeneration.uuidString + "|" + (model.state.context ?? "") }

    func start(_ model: SpikeModel) {
        guard poll == nil, model.canSubmit, !model.demo, let context = model.state.context, !context.isEmpty else { return }
        let current = identity(model)
        if owner != current { clear(); owner = current }
        watching = true
        captureStartedAt = Date(); framesReceived = 0; bytesReceived = 0
        makeWebView(model)
        poll = Task { [weak self] in
            guard let self else { return }
            var cycle = 0
            while !Task.isCancelled && self.watching && self.owner == self.identity(model) {
                if !self.busy {
                    if cycle % 6 == 0 { await self.refresh(model) }
                    if self.status?.controlling == true && cycle % 6 == 0 && self.pending == nil {
                        await self.mutate("heartbeat", model:model)
                    }
                    if self.status?.supported == true && (self.status?.phase == "watching" || self.status?.controlling == true) && self.pending == nil {
                        await self.capture(model)
                    }
                    cycle += 1
                }
                try? await Task.sleep(for:.milliseconds(650))
            }
        }
    }
    func suspend() {
        watching = false; poll?.cancel(); poll = nil; revision = UUID()
        frame = nil; receivedAt = nil; webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName:"viewer")
        webView = nil; bridge = nil
        // The heartbeat expires on the host. A0 remains held; no Return is sent.
    }
    func clear() { suspend(); status = nil; pending = nil; notice = nil; owner = nil }
    func select(_ source: String) {
        self.source = source; frame = nil; receivedAt = nil; revision = UUID()
        render()
    }
    private func profile(_ model: SpikeModel) -> ProfileIdentity? { try? ProfileIdentity(origin:ServerOrigin(model.origin),username:model.username) }
    func refresh(_ model: SpikeModel) async {
        let identity = identity(model)
        guard let client = model.controlClient, let context = model.state.context, let profile = profile(model) else { return }
        do {
            let saved = try await ControlReceipts.journal.pending(profile)
            let response = try await client.hostViewer(context:context,viewer:viewerID,command:"status",source:source)
            guard owner == identity, watching else { return }
            pending = saved; status = try LiveViewerStatus(response)
        } catch {
            guard owner == identity, watching else { return }
            notice = error.localizedDescription; receivedAt = nil
        }
        render()
    }
    func acknowledgeUncertain(_ model: SpikeModel) async {
        guard let pending else { return }
        do { try await ControlReceipts.journal.resolve(pending); self.pending = nil; notice = nil; await refresh(model) }
        catch { notice = "Could not update the receipt. Unlock the device and try again." }
    }
    private func capture(_ model: SpikeModel) async {
        let stamp = revision, identity = identity(model), source = source
        guard let client = model.controlClient, let context = model.state.context else { return }
        do {
            let response = try await client.hostViewer(context:context,viewer:viewerID,command:"frame",source:source)
            guard owner == identity, revision == stamp, watching, !busy,
                  case .object(let value) = response["frame"] else { return }
            let frame = try LiveFrame(value)
            guard frame.source == self.source else { return }
            self.frame = frame; receivedAt = Date(); framesReceived += 1; bytesReceived += frame.data.count
            notice = nil; render()
        } catch {
            guard owner == identity, revision == stamp, watching else { return }
            notice = error.localizedDescription; receivedAt = nil; render()
        }
    }
    func mutate(_ command: String, model: SpikeModel, input: [String:JSONValue]? = nil, displayedFrame: String? = nil) async {
        guard !busy, pending == nil, watching, owner == identity(model), model.canSubmit,
              let client = model.controlClient, let context = model.state.context, let profile = profile(model) else { return }
        if command == "input" && !canInput { return }
        let identity = identity(model), frame = frame
        busy = true; revision = UUID(); render()
        let title = command == "input" ? "Remote input" : command == "acquire" ? "Take over host" : command == "return" ? "Return to A0" : "Keep host control"
        let receipt = ControlJournal.Receipt(title:title,context:context,profile:profile)
        let started = Date()
        do {
            try await ControlReceipts.journal.begin(receipt)
            pending = receipt
            guard owner == identity, watching, model.canSubmit else {
                try await ControlReceipts.journal.resolve(receipt); pending = nil; busy = false; return
            }
            var fields: [String:JSONValue] = ["request_id":.string(receipt.id.uuidString.replacingOccurrences(of:"-",with:"").lowercased())]
            if let input, let frame {
                fields["input"] = .object(input); fields["frame"] = .string(displayedFrame ?? frame.id)
                fields["sequence"] = .number(Double((status?.sequence ?? 0) + 1))
            }
            let response = try await client.hostViewer(context:context,viewer:viewerID,command:command,source:source,fields:fields)
            try await ControlReceipts.journal.resolve(receipt)
            guard owner == identity else { return }
            pending = nil; status = try LiveViewerStatus(response); notice = nil
            measuredLatency = Date().timeIntervalSince(started)
            if command == "input" { lastInputLatency = measuredLatency }
            if command == "acquire" { expanded = true; inspect = false }
        } catch {
            guard owner == identity else { return }
            pending = try? await ControlReceipts.journal.pending(profile)
            notice = error.localizedDescription + (pending == nil ? "":" Inspect the host before allowing another action. Nothing was replayed.")
        }
        if owner == identity { busy = false; render() }
    }
    func render() {
        guard let webView else { return }
        let payload: [String:Any] = ["frame":frame?.id ?? "", "image":frame.map { "data:image/jpeg;base64," + $0.data.base64EncodedString() } ?? "", "enabled":canInput,
                                   "drag":source == "browser", "inspect":inspect]
        guard let bytes = try? JSONSerialization.data(withJSONObject:payload),let json = String(data:bytes,encoding:.utf8) else { return }
        webView.evaluateJavaScript("window.receiveFrame && window.receiveFrame(\(json))",completionHandler:nil)
    }
    private func makeWebView(_ model: SpikeModel) {
        guard webView == nil else { return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let bridge = LiveViewerBridge(viewer:self,model:model)
        configuration.userContentController.add(bridge,name:"viewer")
        let web = WKWebView(frame:.zero,configuration:configuration)
        web.accessibilityIdentifier = "hostCaptureWebView"
        web.navigationDelegate = bridge; web.isOpaque = false; web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        self.bridge = bridge; webView = web
        if let url = Bundle.main.url(forResource:"live-viewer",withExtension:"html"), let html = try? String(contentsOf:url,encoding:.utf8) {
            web.loadHTMLString(html,baseURL:nil)
        }
    }
}

@MainActor final class LiveViewerBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    weak var viewer: LiveViewerModel?
    weak var model: SpikeModel?
    init(viewer: LiveViewerModel, model: SpikeModel) { self.viewer = viewer; self.model = model }
    func userContentController(_ userContentController: WKUserContentController,didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String:Any], let viewer, let model,
              let bytes = try? JSONSerialization.data(withJSONObject:body), bytes.count < 10_000,
              let input = try? JSONDecoder().decode([String:JSONValue].self,from:bytes) else { return }
        guard case .string(let frameID) = input["frame"], frameID.count == 32 else { return }
        var event = input; event.removeValue(forKey:"frame")
        Task { await viewer.mutate("input",model:model,input:event,displayedFrame:frameID) }
    }
    func webView(_ webView: WKWebView,didFinish navigation: WKNavigation!) { viewer?.render() }
    func webView(_ webView: WKWebView,decidePolicyFor navigationAction: WKNavigationAction,decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow:.cancel)
    }
}
