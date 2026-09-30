import Foundation
import Testing
@testable import A0Core

@Suite struct PluginTests {
    func plugin(_ id:String = "example",custom:Bool = true,always:Bool = false) throws -> InstalledPlugin {
        try InstalledPlugin(fields:["name":.string(id),"is_custom":.bool(custom),"always_enabled":.bool(always),"per_project_config":.bool(true),"per_agent_config":.bool(true)])
    }
    func response(_ json:String,status:Int = 200) -> HTTPResponse { HTTPResponse(data:Data(json.utf8),status:status,headers:["Content-Type":"application/json"]) }
    @Test func inventoryUsesAuthenticatedCoreEndpoint() async throws {
        let transport = ScriptTransport(loginResponses()+[response(#"{"ok":true,"plugins":[{"name":"example","has_main_screen":true,"per_project_config":true}]}"#)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        let rows = try await client.installedPlugins()
        #expect(rows.count == 1); #expect(rows[0].hasMain); #expect(rows[0].hasSettings)
        let request = try #require(await transport.requests.last)
        #expect(request.url?.path == "/api/plugins_list")
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
        #expect(request.value(forHTTPHeaderField:"Cookie")?.contains("session_test-runtime") == true)
    }
    @Test(arguments:["../other","other/main","%2e%2e","a.b","a?x","a#x","a\\b",""])
    func untrustedIdentityCannotBecomePath(_ value:String) {
        #expect(throws:PluginError.invalidIdentity) { try PluginIdentity.validate(value) }
    }
    @Test func capabilityRestrictionsAndScopes() throws {
        #expect(throws:PluginError.protectedPlugin) { try PluginCommand.delete(plugin(custom:false)).validatedRequest() }
        #expect(throws:PluginError.protectedPlugin) { try PluginCommand.activate(plugin(always:true),false,PluginScope()).validatedRequest() }
        let call = try PluginCommand.activate(plugin(),false,PluginScope(project:"research",agent:"analyst")).validatedRequest()
        #expect(call.payload["clear_overrides"] == .bool(false))
        #expect(call.payload["project_name"] == .string("research"))
        #expect(call.payload["agent_profile"] == .string("analyst"))
        #expect(call.payload["enabled"] == .bool(false))
        let global = try InstalledPlugin(fields:["name":.string("global")])
        #expect(throws:PluginError.protectedPlugin) { try PluginCommand.activate(global,true,PluginScope(project:"research")).validatedRequest() }
    }
    @Test func inheritedToggleDoesNotOfferRemoval() async throws {
        let transport = ScriptTransport(loginResponses()+[response(#"{"ok":true,"status":"enabled","loaded_project_name":"","loaded_agent_profile":"","loaded_path":"usr/plugins/example/.toggle-1"}"#)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        let state = try await client.pluginStatus("example",scope:PluginScope(project:"research"))
        #expect(state.enabled); #expect(!state.hasOverride(in:PluginScope(project:"research")))
        #expect(state.hasOverride(in:PluginScope()))
    }
    @Test func installerUsesSuccessEnvelopeAndRejectsSuspension() async throws {
        let transport = ScriptTransport(loginResponses()+[response(#"{"success":true,"index":{"plugins":{"example":{"title":"Example","github":"https://github.com/test/example","suspended":"Under review"}}},"installed_plugins":[]}"#)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        let hub = try await client.pluginHub()
        #expect(hub.entries.count == 1)
        #expect(throws:PluginError.protectedPlugin) { try PluginCommand.install(hub.entries[0]).validatedRequest() }
        #expect(await transport.requests.last?.url?.path == "/api/plugins/_plugin_installer/plugin_install")
    }
    @Test(arguments:["http://github.com/test/example","https://token@github.com/test/example","https://github.com/test/example?token=secret","javascript:alert(1)"])
    func sourceMustBeCredentialFreeHTTPS(_ value:String) { #expect(PluginHubEntry.httpsURL(value) == nil) }
    @Test func updateComparisonMatchesCommitAndTimeRules() throws {
        let local = try InstalledPlugin(fields:["name":.string("example"),"current_commit":.string("old"),"current_commit_timestamp":.string("2026-09-30T01:00:00Z")])
        let older = try PluginHubEntry(id:"example",fields:["commit":.string("different"),"updated":.string("2026-09-29T01:00:00Z")])
        let newer = try PluginHubEntry(id:"example",fields:["commit":.string("new"),"updated":.string("2026-09-30T02:00:00.000Z")])
        #expect(!older.hasUpdate(for:local)); #expect(newer.hasUpdate(for:local))
        #expect(!newer.hasUpdate(for:try plugin())); #expect(!newer.hasUpdate(for:nil))
    }
    @Test(arguments:[401,403,503]) func commandsNeverRetry(_ status:Int) async throws {
        let transport = ScriptTransport(loginResponses()+[response("{}",status:status)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        await #expect(throws:(any Error).self) { try await client.performPluginCommand(.delete(plugin())) }
        #expect(await transport.requests.count == 4)
    }
    @Test func falseInstallerAcknowledgementIsNotSuccess() async throws {
        let transport = ScriptTransport(loginResponses()+[response(#"{"success":false,"error":"private server details"}"#)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        await #expect(throws:PluginError.rejected) { try await client.performPluginCommand(.update(plugin())) }
        #expect(!PluginError.rejected.localizedDescription.contains("private"))
    }
    @Test func duplicateInventoryAndInvalidSuccessAreRejected() async throws {
        let transport = ScriptTransport(loginResponses()+[response(#"{"ok":true,"plugins":[{"name":"example"},{"name":"example"}]}"#),response(#"{"ok":true,"index":{"plugins":{}},"installed_plugins":[]}"#)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        await #expect(throws:ClientError.incompatiblePayload) { try await client.installedPlugins() }
        await #expect(throws:ClientError.incompatiblePayload) { try await client.pluginHub() }
    }
    @Test func webRouteRequiresExactOriginAndPort() throws {
        let route = try PluginScreenRoute(pluginID:"example",title:"Example",kind:.main)
        let origin = try ServerOrigin("https://server.test:8443")
        #expect(route.allows(URL(string:"https://server.test:8443/")!,origin:origin))
        for url in ["https://other.test:8443/","https://server.test/","http://server.test:8443/","https://user@server.test:8443/"] {
            #expect(!route.allows(URL(string:url)!,origin:origin))
        }
    }
    @Test func webCookieIsHTTPOnlySecureAndProfileBound() throws {
        let origin = try ServerOrigin("https://server.test")
        let profile = ProfileIdentity(origin:origin,username:"fixture")
        let saved = SavedAuthentication(profile:profile,name:"session_fixture",value:"synthetic",expires:nil)
        let cookie = try saved.validatedCookie(for:profile,origin:origin)
        #expect(cookie.isHTTPOnly); #expect(cookie.isSecure)
        #expect(throws:ClientError.requiresLogin) { try saved.validatedCookie(for:ProfileIdentity(origin:origin,username:"other"),origin:origin) }
    }

    @Test func thumbnailsStayWithinTheirDeclaredOrigin() throws {
        let local = try InstalledPlugin(fields:["name":.string("example"),"thumbnail_url":.string("/plugins/example/webui/thumbnail.webp")])
        #expect(local.thumbnail?.serverPath == "/plugins/example/webui/thumbnail.webp")
        for path in ["/plugins/other/webui/thumbnail.png","/plugins/example/webui/../config.json","https://other.test/thumbnail.png"] {
            let invalid = try InstalledPlugin(fields:["name":.string("example"),"thumbnail_url":.string(path)])
            #expect(invalid.thumbnail == nil)
        }
        #expect(PluginThumbnail.reference("https://user:secret@images.test/image.png",pluginID:"example") == nil)
        #expect(PluginThumbnail.reference("http://images.test/image.png",pluginID:"example") == nil)
        let hub = try PluginHubEntry(id:"example",fields:["github":.string("https://github.com/owner/repo.git")])
        #expect(hub.thumbnail?.remoteURL?.absoluteString == "https://raw.githubusercontent.com/owner/repo/main/thumbnail.png")
        let explicit = try PluginHubEntry(id:"example",fields:["thumbnail":.string("https://images.test/example.png")])
        #expect(explicit.thumbnail?.remoteURL?.host == "images.test")
    }
    @Test func serverThumbnailsUseAuthenticatedBoundedRead() async throws {
        let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:Data([1,2,3]),status:200,headers:["Content-Type":"image/png"])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        let reference = try #require(PluginThumbnail.reference("/plugins/example/webui/thumbnail.png",pluginID:"example"))
        #expect(try await client.pluginThumbnail(reference) == Data([1,2,3]))
        let request = try #require(await transport.requests.last)
        #expect(request.url?.absoluteString == "https://server.test/plugins/example/webui/thumbnail.png")
        #expect(request.value(forHTTPHeaderField:"Cookie")?.contains("session_test-runtime") == true)
        let external = try #require(PluginThumbnail.reference("https://images.test/example.png",pluginID:"example"))
        await #expect(throws:ClientError.incompatiblePayload) { try await client.pluginThumbnail(external) }
        #expect(await transport.requests.count == 4)
    }
    @Test func thumbnailRedirectsAndNonImagesAreRejected() async throws {
        let transport = ScriptTransport(loginResponses()+[HTTPResponse(data:Data(),status:302,headers:["Location":"https://other.test/image.png"]),response("<html>not an image</html>")])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        let reference = try #require(PluginThumbnail.reference("/plugins/example/webui/thumbnail.png",pluginID:"example"))
        await #expect(throws:(any Error).self) { try await client.pluginThumbnail(reference) }
        await #expect(throws:(any Error).self) { try await client.pluginThumbnail(reference) }
        #expect(await transport.requests.count == 5)
    }

    @Test func initialPluginNavigationSkipsOnlyTheDevTunnelsBrowserNotice() throws {
        let route = try PluginScreenRoute(pluginID:"example",title:"Example",kind:.settings)
        let tunnel = try ServerOrigin("https://fixture-5000.use.devtunnels.ms")
        let request = route.initialRequest(origin:tunnel)
        #expect(request.url?.absoluteString == "https://fixture-5000.use.devtunnels.ms/index.html")
        #expect(request.value(forHTTPHeaderField:"X-Tunnel-Skip-AntiPhishing-Page") == "true")
        #expect(request.value(forHTTPHeaderField:"Cookie") == nil)
        for address in ["https://server.test","https://devtunnels.ms.attacker.test","https://notdevtunnels.ms"] {
            #expect(route.initialRequest(origin:try ServerOrigin(address)).value(forHTTPHeaderField:"X-Tunnel-Skip-AntiPhishing-Page") == nil)
        }
    }

    @Test func workspaceRetainsContextAndUsesTheAuthenticatedShell() throws {
        let draft = PluginScreenRoute.workspace()
        let selected = PluginScreenRoute.workspace(contextID:"fixture-chat")
        #expect(draft.contextID == nil)
        #expect(selected.contextID == "fixture-chat")
        #expect(draft.id != selected.id)
        #expect(selected.kind == .workspace)
        let origin = try ServerOrigin("https://server.test:8443")
        #expect(selected.initialRequest(origin:origin).url?.absoluteString == "https://server.test:8443/index.html")
        #expect(!selected.allows(URL(string:"https://server.test/")!,origin:origin))
    }

    @Test func workspaceDownloadsStayWithinTheAuthenticatedOrigin() throws {
        let route = PluginScreenRoute.workspace()
        let origin = try ServerOrigin("https://server.test:8443")
        for value in ["https://server.test:8443/api/download", "blob:https://server.test:8443/fixture"] {
            #expect(route.allowsDownload(URL(string:value)!,origin:origin))
        }
        for value in ["https://server.test/api/download", "blob:https://other.test:8443/fixture", "blob:https://user:secret@server.test:8443/fixture", "blob:null/fixture", "file:///tmp/export", "data:text/plain,example"] {
            #expect(!route.allowsDownload(URL(string:value)!,origin:origin))
        }
    }

}
