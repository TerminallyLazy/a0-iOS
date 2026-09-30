import SwiftUI
import WebKit
import A0Core

/// Explicitly trusted server WebUI. Its actions retain WebUI semantics, not native command receipts.
struct PluginWebScreen:View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let model:SpikeModel
    let route:PluginScreenRoute
    @State private var session:SavedAuthentication?
    @State private var ready = false
    @State private var error:String?
    @State private var suspended = false
    @State private var closing = false
    @State private var owner:UUID?
    var body:some View {
        NavigationStack {
            ZStack {
                if let session,!suspended,error == nil {
                    PluginWebContainer(route:route,session:session,onEvent:event)
                        .opacity(ready ? 1:0)
                }
                if let error { ContentUnavailableView(route.kind == .workspace ? "Workspace unavailable":"Plugin screen unavailable",systemImage:"exclamationmark.triangle",description:Text(error)) }
                else if suspended { ContentUnavailableView(route.kind == .workspace ? "Workspace closed":"Plugin screen closed",systemImage:"lock",description:Text("For privacy, this screen was cleared when the app left the foreground. Close and open it again; check any action that was in progress.")) }
                else if !ready { ProgressView(route.kind == .workspace ? "Opening workspace…":"Opening plugin…") }
            }
            .navigationTitle(route.kind == .settings ? "\(route.title) Settings":route.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { closing = true }.accessibilityIdentifier("closePluginScreen") } }
            .confirmationDialog("Close this screen?",isPresented:$closing,titleVisibility:.visible) {
                Button("Close screen",role:.destructive) { session = nil; dismiss() }
            } message: { Text("Save any changes first. Closing does not cancel work already started on the server.") }
            .interactiveDismissDisabled()
            .onDisappear { model.themeRefreshRevision += 1 }
        .task(id:model.connectionGeneration) { await connect() }
            .onChange(of:scenePhase) { _,phase in if phase != .active { suspended = true; session = nil; ready = false } }
            .onChange(of:model.chat?.selectedContext) { _,context in if context != route.contextID { suspended = true; session = nil; ready = false } }
            .onDisappear { session = nil }
        }.pluginPresentationSize()
    }
    private func event(_ kind:String) {
        guard owner == model.connectionGeneration,!suspended else { return }
        switch kind {
        case "ready":ready = true
        case "closed":session = nil; dismiss()
        case "authentication":error = "The server session expired or was rejected. Reconnect before opening this screen. No HTTP request was retried."; session = nil
        case "timeout":error = "The server took too long to open this screen. Close it and try again when the connection is ready."; session = nil
        case "unexpected-document":error = "The server returned a tunnel notice or another page instead of the Agent Zero WebUI. Close this screen and reopen it. If it persists, reconnect to your server."; session = nil
        case "navigation":error = "The plugin replaced its WebUI page. Close this screen and reopen it to restore the plugin view. No action was retried."; session = nil
        case "bootstrap":error = "The server WebUI could not finish initializing this screen. Close it and try again, or check plugin compatibility."; session = nil
        default:error = "The plugin screen could not be opened. Its WebUI may be incompatible, or the connection may have failed."; session = nil
        }
    }
    private func connect() async {
        // Account changes destroy the old web view before any asynchronous session handoff.
        if owner != nil,owner != model.connectionGeneration { suspended = true; session = nil; return }
        let generation = model.connectionGeneration; owner = generation
        guard !suspended,model.canSubmit,let client = model.controlClient else { error = "Connect to Agent Zero first."; return }
        do {
            let profile = try ProfileIdentity(origin:ServerOrigin(model.origin),username:model.username)
            let saved = try await client.savedAuthentication(for:profile)
            guard generation == model.connectionGeneration,scenePhase == .active else { return }
            session = saved
        } catch { self.error = "The authenticated plugin session could not be opened. Reconnect and try again." }
    }
}

private struct PluginWebContainer:UIViewRepresentable {
    let route:PluginScreenRoute
    let session:SavedAuthentication
    let onEvent:@MainActor (String)->Void
    func makeCoordinator() -> Coordinator { Coordinator(route:route,session:session,onEvent:onEvent) }
    func makeUIView(context:Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let source = Bundle.main.url(forResource:"PluginWebAdapter",withExtension:"js").flatMap { try? String(contentsOf:$0,encoding:.utf8) }
        let workspaceSource = Bundle.main.url(forResource:"WorkspaceWebAdapter",withExtension:"js").flatMap { try? String(contentsOf:$0,encoding:.utf8) }
        if let workspaceSource { configuration.userContentController.addUserScript(WKUserScript(source:workspaceSource,injectionTime:.atDocumentStart,forMainFrameOnly:true)) }
        if let source { configuration.userContentController.addUserScript(WKUserScript(source:source,injectionTime:.atDocumentStart,forMainFrameOnly:false)) }
        configuration.userContentController.add(context.coordinator,name:"pluginScreen")
        let web = WKWebView(frame:.zero,configuration:configuration)
        web.navigationDelegate = context.coordinator; web.uiDelegate = context.coordinator
        web.isOpaque = false; web.backgroundColor = .systemBackground
        context.coordinator.web = web
        if source == nil || workspaceSource == nil { Task { onEvent("error") }; return web }
        context.coordinator.start()
        return web
    }
    func updateUIView(_ web:WKWebView,context:Context) {}
    static func dismantleUIView(_ web:WKWebView,coordinator:Coordinator) {
        coordinator.active = false; coordinator.loading?.cancel(); coordinator.timeout?.cancel()
        web.stopLoading(); web.navigationDelegate = nil; web.uiDelegate = nil
        web.configuration.userContentController.removeScriptMessageHandler(forName:"pluginScreen")
        web.configuration.userContentController.removeAllUserScripts()
        web.configuration.websiteDataStore.removeData(ofTypes:WKWebsiteDataStore.allWebsiteDataTypes(),modifiedSince:.distantPast) {}
        coordinator.finishDialogs(); coordinator.downloads.clear()
    }
    @MainActor final class Coordinator:NSObject,WKNavigationDelegate,WKUIDelegate,WKScriptMessageHandler {
        let route:PluginScreenRoute
        let session:SavedAuthentication
        let origin:ServerOrigin?
        let onEvent:@MainActor (String)->Void
        weak var web:WKWebView?
        var active = true
        var bootstrapped = false
        var rootNavigation:WKNavigation?
        var loading:Task<Void,Never>?
        var timeout:Task<Void,Never>?
        var dialogCompletion:(()->Void)?
        lazy var downloads = WorkspaceDownloads(web:web)
        init(route:PluginScreenRoute,session:SavedAuthentication,onEvent:@escaping @MainActor (String)->Void) {
            self.route = route; self.session = session; self.onEvent = onEvent; origin = try? ServerOrigin(session.profile.origin)
        }
        func start() {
            loading = Task { [weak self] in
                guard let self,let origin,let web else { return }
                do {
                    let cookie = try session.validatedCookie(for:session.profile,origin:origin)
                    await web.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                    guard active,!Task.isCancelled else { return }
                    // No credentials are interpolated into scripts or navigation URLs.
                    rootNavigation = web.load(route.initialRequest(origin:origin))
                    timeout = Task { [weak self] in
                        // The shell loads several waves of authenticated modules and components.
                        try? await Task.sleep(for:.seconds(60))
                        guard !Task.isCancelled,let self,self.active else { return }
                        self.onEvent("timeout")
                    }
                } catch { if active { onEvent("error") } }
            }
        }
        func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
            guard active,message.frameInfo.isMainFrame,let url = message.frameInfo.request.url,let origin,route.allows(url,origin:origin),
                  let kind = message.body as? String,["ready","closed","error","authentication","unexpected-document"].contains(kind) else { return }
            if kind == "ready" { timeout?.cancel() }
            onEvent(kind)
        }
        func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping @MainActor @Sendable (WKNavigationActionPolicy)->Void) {
            guard active,let url = navigationAction.request.url,let origin else { decisionHandler(.cancel); return }
            if navigationAction.shouldPerformDownload,
               let source = navigationAction.sourceFrame.request.url,route.allows(source,origin:origin),
               route.allowsDownload(url,origin:origin) {
                decisionHandler(.download); return
            }
            if !route.allows(url,origin:origin) || navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                if navigationAction.navigationType == .linkActivated { openExternal(url) }
                return
            }
            guard url.path != "/login" else { decisionHandler(.cancel); onEvent("authentication"); return }
            decisionHandler(.allow)
        }
        func webView(_ webView:WKWebView,decidePolicyFor navigationResponse:WKNavigationResponse,decisionHandler:@escaping @MainActor @Sendable (WKNavigationResponsePolicy)->Void) {
            guard active,let url = navigationResponse.response.url,let origin,route.allows(url,origin:origin),
                  (navigationResponse.response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false else { decisionHandler(.cancel); onEvent("error"); return }
            if !navigationResponse.canShowMIMEType || (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField:"Content-Disposition")?.lowercased().hasPrefix("attachment") == true {
                decisionHandler(.download); return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView:WKWebView,navigationAction:WKNavigationAction,didBecome download:WKDownload) { downloads.accept(download) }
        func webView(_ webView:WKWebView,navigationResponse:WKNavigationResponse,didBecome download:WKDownload) { downloads.accept(download) }
        func webView(_ webView:WKWebView,didCommit navigation:WKNavigation!) {
            if active,bootstrapped { onEvent("navigation") }
        }
        func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
            guard active else { return }
            if bootstrapped { onEvent("navigation"); return }
            guard let navigation,let rootNavigation,navigation === rootNavigation,
                  let url = webView.url,let origin,route.allows(url,origin:origin) else { return }; bootstrapped = true
            let script = """
            const notify = kind => window.webkit.messageHandlers.pluginScreen.postMessage(kind);
            // A tunnel/interstitial HTML response must never be treated as the Agent Zero shell.
            if (globalThis.runtimeInfo?.loggedIn !== true || !document.querySelector('#right-panel')) {
              notify('unexpected-document');
              return false;
            }
            await import('/js/initFw.js');
            const chat = await import('/index.js');
            if(context) chat.setContext(context); else chat.deselectChat();
            const modals = await import('/js/modals.js');
            const workspace = await window.a0PrepareWorkspace();
            const closeOriginal = () => { if (!workspace.hasSurface()) notify('closed'); };
            if(kind === 'workspace') { notify('ready'); return true; }
            const target = kind === 'settings' ? '/components/plugins/plugin-settings.html' : '/plugins/' + plugin + '/webui/main.html';
            const toast = document.getElementById('toast'); if(toast) document.body.appendChild(toast);
            document.addEventListener('modal-content-loaded', event => {
              if(event.detail?.modalPath === target) notify('ready');
            });
            if(kind === 'settings') {
              const settings = await import('/components/plugins/plugin-settings-store.js');
              settings.store.openConfig(plugin, project, agent).then(closeOriginal).catch(() => notify('error'));
            } else {
              modals.openModal(target).then(closeOriginal).catch(() => notify('error'));
            }
            return true;
            """
            webView.callAsyncJavaScript(script,arguments:["plugin":route.pluginID,"kind":route.kind.rawValue,"project":route.scope.project,"agent":route.scope.agent,"context":route.contextID ?? ""],in:nil,in:.page) { [weak self] result in
                guard let self,self.active else { return }
                if case .failure = result {
                    self.onEvent("bootstrap")
                }
            }
        }
        func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error) { if active { onEvent("error") } }
        func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) { if active { onEvent("error") } }
        func webViewWebContentProcessDidTerminate(_ webView:WKWebView) { if active { onEvent("error") } }
        func finishDialogs() { let completion = dialogCompletion; dialogCompletion = nil; completion?() }
        private func present(_ alert:UIAlertController,fallback:@escaping ()->Void) {
            guard active,let root = web?.window?.rootViewController else { fallback(); return }
            var presenter = root
            while let next = presenter.presentedViewController { presenter = next }
            guard !(presenter is UIAlertController) else { fallback(); return }
            dialogCompletion = fallback; presenter.present(alert,animated:true)
        }
        private func openExternal(_ url:URL) {
            guard url.scheme == "https",url.user == nil,url.password == nil else { return }
            let alert = UIAlertController(title:"Open external link?",message:url.host,preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:"Cancel",style:.cancel))
            alert.addAction(UIAlertAction(title:"Open in browser",style:.default) { _ in UIApplication.shared.open(url) })
            present(alert,fallback:{})
        }
        func webView(_ webView:WKWebView,runJavaScriptTextInputPanelWithPrompt prompt:String,defaultText:String?,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping @MainActor @Sendable (String?)->Void) {
            let alert = UIAlertController(title:route.title,message:String(prompt.prefix(2000)),preferredStyle:.alert)
            alert.addTextField { $0.text = defaultText }
            var responded = false
            let respond:(String?)->Void = { [weak self] value in guard !responded else { return }; responded = true; self?.dialogCompletion = nil; completionHandler(value) }
            alert.addAction(UIAlertAction(title:"Cancel",style:.cancel) { _ in respond(nil) })
            alert.addAction(UIAlertAction(title:"OK",style:.default) { [weak alert] _ in respond(alert?.textFields?.first?.text) })
            present(alert,fallback:{ respond(nil) })
        }
        func webView(_ webView:WKWebView,runJavaScriptAlertPanelWithMessage message:String,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping @MainActor @Sendable ()->Void) {
            let alert = UIAlertController(title:route.title,message:String(message.prefix(2000)),preferredStyle:.alert)
            var responded = false
            let respond:()->Void = { [weak self] in guard !responded else { return }; responded = true; self?.dialogCompletion = nil; completionHandler() }
            alert.addAction(UIAlertAction(title:"OK",style:.default) { _ in respond() })
            present(alert,fallback:respond)
        }
        func webView(_ webView:WKWebView,runJavaScriptConfirmPanelWithMessage message:String,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping @MainActor @Sendable (Bool)->Void) {
            let alert = UIAlertController(title:route.title,message:String(message.prefix(2000)),preferredStyle:.alert)
            var responded = false
            let respond:(Bool)->Void = { [weak self] value in guard !responded else { return }; responded = true; self?.dialogCompletion = nil; completionHandler(value) }
            alert.addAction(UIAlertAction(title:"Cancel",style:.cancel) { _ in respond(false) })
            alert.addAction(UIAlertAction(title:"Continue",style:.default) { _ in respond(true) })
            present(alert,fallback:{ respond(false) })
        }
    }
}
