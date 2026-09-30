import Foundation
import Testing
@testable import A0Core

@Suite struct ServerThemeTests {
    func css(_ id:String = "aurora") -> String {
        ["dark","light"].map { mode in
            "body[data-selectable-theme=\"\(id)\"].\(mode)-mode {" + ServerTheme.keys.map { "--color-\($0): #123456;" }.joined() + "--st-gradient: linear-gradient(160deg, #112233 0%, rgba(30, 40, 50, 0.5) 45%, #556677 100%); }"
        }.joined(separator:"\n")
    }
    func response(_ json:String) -> HTTPResponse { HTTPResponse(data:Data(json.utf8),status:200,headers:["Content-Type":"application/json"]) }
    @Test func builtinsUseCurrentServerCSSAndPreserveGradientStops() throws {
        let theme = try ServerTheme.resolve(config:["theme":.string("ocean")],css:css("ocean"))
        #expect(theme.name == "Ocean");#expect(theme.dark.colors["text"] == "#123456")
        #expect(theme.dark.gradient?.angle == 160)
        #expect(theme.dark.gradient?.locations == [0,0.45,1])
        #expect(theme.dark.gradient?.colors[1] == "rgba(30, 40, 50, 0.5)")
    }
    @Test func customThemesPreserveCSSColorsAndTransparency() throws {
        let colors = Dictionary(uniqueKeysWithValues:ServerTheme.keys.map { ($0,JSONValue.string($0 == "border" ? "#62598aa8":"hsl(285 50% 30%)")) })
        let custom:[String:JSONValue] = [
            "id":.string("custom-rose"),"name":.string("Rose"),"dark":.object(colors),"light":.object(colors),
            "gradient":.object(["enabled":.bool(true),"angle":.number(90),"stops":.array([.string("rebeccapurple"),.string("#ffffffff")])])]
        let theme = try ServerTheme.resolve(config:["theme":.string("custom-rose"),"custom_themes":.array([.object(custom)])],css:css())
        #expect(theme.id == "custom-rose");#expect(theme.dark.colors["border"] == "#62598aa8")
        #expect(theme.light.gradient?.locations == [0,1])
    }
    @Test func unknownSelectionUsesPluginDefaultAndMalformedPayloadFails() throws {
        #expect(try ServerTheme.resolve(config:["theme":.string("gone")],css:css()).id == "aurora")
        #expect(throws:(any Error).self) { try ServerTheme.resolve(config:["theme":.string("../x")],css:css()) }
        #expect(throws:(any Error).self) { try ServerTheme.resolve(config:[:],css:String(repeating:"x",count:131073)) }
        #expect(throws:(any Error).self) { try ServerTheme.resolve(config:[:],css:css().replacingOccurrences(of:"#123456",with:"url(https://example.test/tracker)")) }
        #expect(ServerTheme.parseGradient("linear-gradient(20deg, #fff 100%, #000 0%)") == nil)
        let huge = try #require(ServerTheme.parseGradient("linear-gradient(1e308deg, #fff 0%, #000 100%)"))
        #expect(huge.angle.isFinite && abs(huge.angle) < 360)
    }
    @Test func disabledPluginStopsWithoutReadingConfigurationOrCSS() async throws {
        let transport = ScriptTransport(loginResponses()+[response(#"{"ok":true,"status":"disabled"}"#)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        #expect(try await client.serverTheme() == nil)
        let calls = await transport.requests
        #expect(calls.count == loginResponses().count+1)
        #expect(String(decoding:try #require(calls.last?.httpBody),as:UTF8.self).contains("get_toggle_status"))
    }
    @Test func readsOnlyScopedConfigAndFixedSameOriginCSS() async throws {
        let transport = ScriptTransport(loginResponses()+[
            response(#"{"ok":true,"status":"enabled"}"#),response(#"{"ok":true,"data":{"theme":"aurora"}}"#),
            HTTPResponse(data:Data(css().utf8),status:200,headers:["Content-Type":"text/css; charset=utf-8"])])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        try await client.connect(username:"fixture",password:"fixture")
        #expect(try await client.serverTheme()?.name == "Aurora")
        let calls = await transport.requests
        let config = try #require(calls.dropLast().last),stylesheet = try #require(calls.last)
        #expect(config.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
        let body = try JSONDecoder().decode([String:JSONValue].self,from:try #require(config.httpBody))
        #expect(body["action"] == .string("get_config"));#expect(body["project_name"] == .string(""));#expect(body["agent_profile"] == .string(""))
        #expect(stylesheet.httpMethod == "GET");#expect(stylesheet.url?.absoluteString == "https://server.test/plugins/selectable_theme/webui/themes.css")
        #expect(stylesheet.value(forHTTPHeaderField:"Cookie")?.isEmpty == false)
    }
    @Test func redirectedCSSAndTunnelHTMLAreRejectedWithoutRetry() async throws {
        for response in [HTTPResponse(data:Data(),status:302,headers:["Location":"https://external.test/colors"]),HTTPResponse(data:Data("<html>Continue</html>".utf8),status:200,headers:["Content-Type":"text/html"])] {
            let transport = ScriptTransport(loginResponses()+[self.response(#"{"ok":true,"status":"enabled"}"#),self.response(#"{"ok":true,"data":{}}"#),response])
            let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
            try await client.connect(username:"fixture",password:"fixture")
            await #expect(throws:(any Error).self) { try await client.serverTheme() }
            #expect(await transport.requests.count == loginResponses().count+3)
        }
    }
}
