#if DEBUG
import Foundation
import UIKit
import A0Core
import A0GenerativeUI

/// Deterministic UI test server; no network, credentials, or model execution.
actor PreviewHTTPTransport: HTTPTransport {
    private var loggedIn = false
    private var pluginEnabled = true
    private var pluginRemoved = false
    private var pluginUpdated = false
    private var hubInstalled = false
    private var pluginOverride = true
    private var stoppedContexts = Set<String>()
    private var contexts: [String] = []
    private var jevReplies: [String:Int] = [:]
    private var polls = 0
    private var teamParentSelectedAt:Date?
    private var mediaResponseSelectedAt:Date?
    private var pollFailures = 0
    private var recoveredFullSnapshot = false
    private var modelPresets: [[String:Any]] = [
        ["name":"Default", "chat":["provider":"fixture", "name":"main-model", "ctx_length":200000, "vision":true, "kwargs":["temperature":0.3]], "utility":["provider":"fixture", "name":"utility-model"], "embedding":["provider":"fixture", "name":"embedding-model"], "custom_setting":"preserve"],
        ["name":"Focused", "chat":["provider":"fixture", "name":"focused-model"]]
    ]
    private var presetOverrides: [String:String] = [:]
    private var globalPreset = "Default"
    private var modelSearchRequests = 0
    private var projectDocuments: [String: [String: Any]] = [
        "research": ["name":"research", "title":"Research", "description":"Sources and discoveries", "color":"#06d6a0", "instructions":"Compare primary sources.", "mcp_servers":"", "variables":"", "secrets":"", "include_agents_md":true, "instruction_files_count":2, "knowledge_files_count":3, "plugin_fixture":["preserve":true]],
        "workshop": ["name":"workshop", "title":"Workshop", "description":"Build and experiment", "color":"#8338ec", "instructions":"", "mcp_servers":"", "variables":"", "secrets":""]
    ]
    private var contextProjects = ["chat-alpha":"research", "chat-beta":"workshop"]
    private var seededContexts = false
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        let payload = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
        let data: [String: Any]
        switch request.url?.path {
        case "/plugins/_fixture_core/webui/thumbnail.png", "/plugins/fixture-plugin/webui/thumbnail.png", "/plugins/hub-fixture/webui/thumbnail.png":
            return HTTPResponse(data:await Self.screenshotFixture(),status:200,headers:["Content-Type":"image/png"])
        case "/api/plugins_list":
            var rows:[[String:Any]] = [["name":"_fixture_core","display_name":"Core Fixture","thumbnail_url":"/plugins/_fixture_core/webui/thumbnail.png","always_enabled":true,"is_custom":false,"toggle_state":"enabled"]]
            if !pluginRemoved { rows.append(["name":"fixture-plugin","display_name":"Fixture Plugin","thumbnail_url":"/plugins/fixture-plugin/webui/thumbnail.png","description":"Synthetic plugin for lifecycle verification.","is_custom":true,"has_main_screen":true,"has_config_screen":true,"per_project_config":true,"per_agent_config":true,"toggle_state":pluginEnabled ? "enabled":"disabled","version":"1.0","current_commit":pluginUpdated ? "new":"old","current_commit_timestamp":"2026-09-29T00:00:00Z"]) }
            if hubInstalled { rows.append(["name":"hub-fixture","display_name":"Hub Fixture","thumbnail_url":"/plugins/hub-fixture/webui/thumbnail.png","description":"Installed from the synthetic Hub.","is_custom":true,"toggle_state":"enabled"]) }
            data = ["ok":true,"plugins":rows]
        case "/plugins/selectable_theme/webui/themes.css":
            return HTTPResponse(data:Data("/* Synthetic custom palette */".utf8),status:200,headers:["Content-Type":"text/css"])
        case "/api/plugins":
            let action = payload["action"] as? String ?? ""
            if action == "get_config", payload["plugin_name"] as? String == "selectable_theme", (ProcessInfo.processInfo.arguments.contains("--synthetic-expanded-ui") || ProcessInfo.processInfo.arguments.contains("--synthetic-expanded-theme")) {
                func colors(_ light:Bool)->[String:String] {
                    var colors = Dictionary(uniqueKeysWithValues:ServerTheme.keys.map { ($0,light ? "#edf8ff":"#102737") })
                    for key in ["text","message-text"] { colors[key] = light ? "#102737":"#edf8ff" }
                    colors["text-muted"] = light ? "#365a72":"#abc9dc"
                    colors["primary"] = light ? "#245e8c":"#83c9fa"
                    colors["background"] = light ? "#d9edf9":"#071c28"
                    return colors
                }
                data = ["ok":true,"data":["theme":"custom-catalog","custom_themes":[["id":"custom-catalog","name":"Catalog Ocean","dark":colors(false),"light":colors(true)]]]]
            } else if action == "get_toggle_status" {
                data = ["ok":true,"status":pluginEnabled ? "enabled":"disabled","loaded_project_name":"","loaded_agent_profile":"","loaded_path":pluginOverride ? "usr/plugins/fixture-plugin/.toggle-1":""]
            } else {
                if ProcessInfo.processInfo.arguments.contains("--synthetic-plugin-uncertain") { throw ClientError.disconnected }
                if action == "toggle_plugin" { pluginEnabled = payload["enabled"] as? Bool ?? false }
                if action == "delete_plugin" { if payload["plugin_name"] as? String == "hub-fixture" { hubInstalled = false } else { pluginRemoved = true } }
                if action == "delete_config" { pluginOverride = false }
                data = ["ok":true]
            }
        case "/api/agents": data = ["ok":true,"data":[["key":"analyst","label":"Analyst"]]]
        case "/api/plugins/_plugin_installer/plugin_install":
            if payload["action"] as? String == "fetch_index" {
                data = ["success":true,"index":["plugins":["fixture-plugin":["title":"Fixture Plugin","thumbnail":"/plugins/fixture-plugin/webui/thumbnail.png","github":"https://github.com/example/fixture","commit":"new","updated":"2026-09-30T00:00:00Z"],"hub-fixture":["title":"Hub Fixture","thumbnail":"/plugins/hub-fixture/webui/thumbnail.png","description":"A synthetic Hub entry.","author":"Fixture","github":"https://github.com/example/fixture","tags":["Utilities"]],"suspended-fixture":["title":"Suspended Fixture","thumbnail":"/plugins/hub-fixture/webui/thumbnail.png","github":"https://github.com/example/suspended","suspended":"Under review"]]],"installed_plugins":hubInstalled ? ["hub-fixture"]:[]]
            } else { if payload["action"] as? String == "update_plugin" { pluginUpdated = true } else { hubInstalled = true }; data = ["success":true] }
        case "/api/image_get":
            guard loggedIn, ProcessInfo.processInfo.arguments.contains("--synthetic-browser-screenshot") else { return HTTPResponse(data:Data(),status:401) }
            return HTTPResponse(data:await Self.screenshotFixture(),status:200,headers:["Content-Type":"image/png"])
        case "/api/csrf_token":
            if ProcessInfo.processInfo.arguments.contains("--synthetic-session-restore"),
               request.value(forHTTPHeaderField: "Cookie")?.contains("session_fixture=fixture") == true {
                loggedIn = true
            }
            if loggedIn, polls > 0, ProcessInfo.processInfo.arguments.contains("--synthetic-realtime-auth-expired") {
                return HTTPResponse(data:Data(),status:401)
            }
            guard loggedIn else { return HTTPResponse(data: Data(), status: 302, headers: ["Location": "/login"]) }
            return HTTPResponse(data: Data(#"{"ok":true,"token":"fixture-csrf","runtime_id":"fixture"}"#.utf8), status: 200,
                                headers: ["Content-Type": "application/json", "Set-Cookie": "session_fixture=fixture; Path=/; Secure; HttpOnly"])
        case "/login":
            loggedIn = true
            return HTTPResponse(data: Data(), status: 302, headers: ["Location": "/"])
        case "/api/message_queue_remove": data = ["ok":true,"remaining":0]
        case "/api/stop":
            if ProcessInfo.processInfo.arguments.contains("--synthetic-stop-failure") { return HTTPResponse(data:Data(),status:503) }
            let context = payload["context"] as? String ?? ""
            stoppedContexts.insert(context)
            data = ["context":context,"stopped":true]
        case "/api/pause": data = ["pause":payload["paused"] as? Bool ?? false]
        case "/api/nudge": data = ["ctxid":payload["ctxid"] as? String ?? ""]
        case "/api/history_get": data = ["history":"Synthetic conversation history", "tokens":42]
        case "/api/plugins/_context_window/context_window":
            data = ["tokens":37500,"context_window":200000,"usage":["messages":2200,"system_tools":8100,"skills":680,"mcp_tools":24500,"system_prompt":1782,"extras":238],"provider_usage":["input_tokens":31700,"cached_tokens":29164,"output_tokens":1200]]
        case "/api/ctx_window_get": data = ["content":"Synthetic active context", "tokens":12]
        case "/api/plugins/_model_config/model_config_get":
            data = ["chat_providers":[["value":"fixture","label":"Fixture Provider"],["value":"another","label":"Another Provider"]],
                    "embedding_providers":[["value":"fixture","label":"Fixture Embeddings"],["value":"embedding-only","label":"Embedding Only"]]]
        case "/api/plugins/_model_config/model_search":
            modelSearchRequests += 1
            if ProcessInfo.processInfo.arguments.contains("--synthetic-model-search-retry"),modelSearchRequests == 1 {
                return HTTPResponse(data:Data(),status:503)
            }
            let provider = payload["provider"] as? String ?? ""
            let embedding = payload["model_type"] as? String == "embedding"
            let models = embedding ? ["embedding-model","embedding-large"] : provider == "another" ? ["another-fast","another-reasoning"] + (0..<320).map { "another-zz-\($0)" } : ["main-model","utility-model","focused-model"]
            data = ["provider":provider,"models":models,"source":"fixture","error":""]
        case "/api/plugins/_model_config/model_presets":
            switch payload["action"] as? String {
            case "save":
                modelPresets = payload["presets"] as? [[String:Any]] ?? modelPresets
                for rename in payload["renames"] as? [[String:String]] ?? [] {
                    if let from = rename["from"],let to = rename["to"] {
                        presetOverrides = presetOverrides.mapValues { $0 == from ? to : $0 }
                        if globalPreset == from { globalPreset = to }
                    }
                }
                let names = Set(modelPresets.compactMap { $0["name"] as? String })
                presetOverrides = presetOverrides.mapValues { names.contains($0) ? $0 : "Default" }
                data = ["ok":true,"presets":modelPresets]
            case "select":
                globalPreset = payload["name"] as? String ?? "Default"
                data = ["ok":true,"selected_preset":globalPreset]
            default: data = ["ok":true,"presets":modelPresets,"configured_preset":globalPreset,"selected_preset":globalPreset]
            }
        case "/api/plugins/_model_config/model_override":
            let context = payload["context_id"] as? String ?? ""
            switch payload["action"] as? String {
            case "set_preset":
                let name = payload["preset_name"] as? String ?? "Default"
                presetOverrides[context] = name; data = ["ok":true,"preset_name":name]
            case "clear": presetOverrides.removeValue(forKey:context); data = ["ok":true,"effective_preset":globalPreset]
            default: data = ["allowed":true,"override":presetOverrides[context].map { ["preset":$0] as Any } ?? NSNull(),"configured_preset":globalPreset,"effective_preset":presetOverrides[context] ?? globalPreset]
            }
        case "/api/projects":
            let name = payload["name"] as? String ?? ""
            let context = payload["context_id"] as? String ?? ""
            var result: Any = NSNull()
            switch payload["action"] as? String {
            case "list_options": result = [["key":"research","label":"Research"]]
            case "list": result = projectDocuments.keys.sorted().compactMap { projectDocuments[$0] }
            case "load": result = projectDocuments[name] ?? [:]
            case "create", "clone", "update":
                var document = payload["project"] as? [String: Any] ?? [:]
                let id = document["name"] as? String ?? ""
                document.removeValue(forKey:"git_token")
                projectDocuments[id] = document; result = document
            case "delete":
                projectDocuments.removeValue(forKey:name)
                contextProjects = contextProjects.filter { $0.value != name }; result = name
            case "activate": contextProjects[context] = name
            case "deactivate": contextProjects.removeValue(forKey:context)
            case "file_structure": result = "project/\n  AGENTS.md\n  README.md"
            default: throw ClientError.unexpectedResponse
            }
            data = ["ok":true,"data":result]
        case "/api/chat_create":
            let id = payload["new_context"] as? String ?? ""
            contexts.append(id); data = ["ok": true, "ctxid": id]
        case "/api/upload":
            let raw = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
            let names = raw.components(separatedBy: "filename=\"").dropFirst().compactMap { $0.components(separatedBy: "\"").first }
            data = ["filenames": names]
        case "/api/message_async":
            if let context = payload["context"] as? String, let text = payload["text"] as? String, text.contains("a2ui-candidates") { jevReplies[context,default:0] += 1 }
            if ProcessInfo.processInfo.arguments.contains("--synthetic-send-timeout") { throw URLError(.timedOut) }
            let raw = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
            let multipartContext = raw.components(separatedBy: "name=\"context\"\r\n\r\n").dropFirst().first?.components(separatedBy: "\r\n").first
            data = ["context": payload["context"] as? String ?? multipartContext ?? ""]
        case "/api/message_queue_add":
            if let context = payload["context"] as? String, let text = payload["text"] as? String, text.contains("a2ui-candidates") { jevReplies[context,default:0] += 1 }
            data = ["ok": true, "item_id": payload["item_id"] as? String ?? ""]
        case "/api/poll":
            polls += 1
            let args = ProcessInfo.processInfo.arguments
            if polls >= 4 {
                if args.contains("--synthetic-poll-auth-expired") { return HTTPResponse(data:Data(),status:401) }
                let failures = args.contains("--synthetic-poll-exhaust") ? 5 : args.contains("--synthetic-poll-recovery") ? 4 : 0
                if pollFailures < failures { pollFailures += 1; throw URLError(.networkConnectionLost) }
                if pollFailures > 0, !recoveredFullSnapshot {
                    guard payload["log_from"] as? Int == 0, payload["notifications_from"] as? Int == 0 else {
                        throw ClientError.incompatiblePayload
                    }
                    recoveredFullSnapshot = true
                }
            }
            let conversationFixture = args.contains("--synthetic-chat-selection")
            if conversationFixture && !seededContexts {
                contexts = ["chat-alpha", "chat-beta", "chat-empty"] + (0..<30).map { "extra-\($0)" }; seededContexts = true
            }
            let recoveryFixture = args.contains("--synthetic-poll-recovery") || args.contains("--synthetic-poll-exhaust")
            let context = payload["context"] as? String ?? ""
            if args.contains("--synthetic-agent-team") {
                if !contexts.contains("chat-existing") { contexts.append("chat-existing") }
                if context == "chat-alpha", teamParentSelectedAt == nil { teamParentSelectedAt = Date() }
                if let began = teamParentSelectedAt, Date().timeIntervalSince(began) >= 8, !contexts.contains("chat-new") { contexts.append("chat-new") }
            }
            if conversationFixture, !context.isEmpty { try await Task.sleep(for: .milliseconds(500)) }
            var entries: [[String: Any]] = conversationFixture && !context.isEmpty && context != "chat-empty"
                ? [["no": 0, "type": "response", "content": "Conversation content for " + context]] : []
            if args.contains("--synthetic-browser-screenshot"), !context.isEmpty {
                entries = [["no":0,"type":"tool","heading":"A0: Using browser","content":"Opened the design reference.","kvps":["tool_name":"browser","browser_snapshot":["path":"/a0/tmp/synthetic-browser.png","mime":"image/png","context_id":context]]]]
            }
            if args.contains("--synthetic-rich-transcript"), !context.isEmpty {
                entries = [["no":0,"type":"response","content":"## Release notes\n\nThis is **bold**, *italic* and `inline code`.\n\n- Native chat navigation\n- Markdown and collapsible messages\n\n> Your work stays on your server.\n\n```swift\nlet agent = \"Agent Zero\"\nprint(agent)\n```\n\n| Feature | Status |\n| --- | --- |\n| Chat | Ready |\n\n" + String(repeating:"A longer explanation with useful details. ",count:30)]]
            }
            if args.contains("--synthetic-activity-transcript"), !context.isEmpty {
                entries = [["no":0,"type":"tool","heading":"[Reference](https://example.com)","content":"```text\nSynthetic tool output\n```","kvps":["result":"Synthetic result detail"]]]
            }
            if args.contains("--synthetic-grouped-activity"), !context.isEmpty {
                entries = [["no":0,"type":"agent","content":"Considering the request"],
                           ["no":1,"type":"tool","content":"Synthetic tool result"],
                           ["no":2,"type":"response","content":"Here is the answer."]]
            }
            if args.contains("--synthetic-polished-tools"), !context.isEmpty {
                entries = [
                    ["no":0,"type":"agent","heading":"icon://psychology A0: Using search_engine","content":"{\"tool_name\":\"search_engine\",\"tool_args\":{\"query\":\"Weather in Bloomington\"}}","kvps":["tool_name":"search_engine","tool_args":["query":"Weather in Bloomington"]]],
                    ["no":1,"type":"tool","heading":"icon://construction A0: Using tool 'search_engine'","content":"Found three forecast sources.","kvps":["_tool_name":"search_engine","query":"Weather in Bloomington"]],
                    ["no":2,"type":"response","heading":"icon://chat A0: Responding","content":"## Forecast summary\n\nA synthetic response for interface testing."]
                ]
            }
            if args.contains("--synthetic-agent-work"), !context.isEmpty {
                entries = [["no":0,"type":"agent","agentno":0,"heading":"Coordinating research","content":"Reviewing the request"],
                           ["no":1,"type":"tool","agentno":1,"heading":"Using search_engine","content":"Comparing forecast sources","kvps":["tool_name":"search_engine","query":"Bloomington forecast"]],
                           ["no":2,"type":"tool","agentno":2,"heading":"Using code_execution_tool","content":"Preparing temperature chart","kvps":["tool_name":"code_execution_tool"]]]
            }
            if args.contains("--synthetic-generative-ui"), !context.isEmpty {
                entries = [["no":0,"type":"response","heading":"icon://chat A0: Responding","content":"```a2ui\n" + GenerativeGuide.example + "\n```"]]
            }
            if args.contains("--synthetic-rich-ui"), !context.isEmpty {
                entries = [["no":0,"type":"response","heading":"icon://chat A0: Responding","content":"Synthetic dashboard example.\n```a2ui\n" + GenerativeGuide.richExample + "\n```"]]
            }
            if args.contains("--synthetic-expanded-ui"), !context.isEmpty {
                entries = [["no":0,"type":"response","content":"Synthetic planning overview.\n```a2ui\n" + GenerativeGuide.expandedExample + "\n```"]]
            }
            if let index = args.firstIndex(of:"--synthetic-charts-media"), index+1 < args.count, !context.isEmpty {
                entries = [["no":0,"type":"response","content":"Synthetic chart and media example.\n```a2ui\n" + (try ChartMediaPreview.surface(kind:args[index+1])) + "\n```"]]
            }
            if args.contains("--synthetic-direct-media"), !context.isEmpty {
                entries = [["no":0,"type":"response","agentno":1,"content":"MP4 direct URL:\nhttps://media.example.com/flower.mp4\n\nMP3 direct URL:\nhttps://media.example.com/song.mp3\n\nBoth source links remain readable."]]
            }
            if args.contains("--synthetic-readonly-media"), !context.isEmpty {
                if mediaResponseSelectedAt == nil { mediaResponseSelectedAt = Date() }
                var surface = try JSONSerialization.jsonObject(with:Data(ChartMediaPreview.surface(kind:"audio").utf8)) as! [[String:Any]]
                var update = surface[1]["updateComponents"] as! [String:Any]
                var media = (update["components"] as! [[String:Any]])[0]; media["id"] = "audio"
                if args.contains("--synthetic-media-replacement"), let started = mediaResponseSelectedAt, Date().timeIntervalSince(started) >= 25 {
                    media["title"] = "Revised synthetic audio"
                }
                update["components"] = [
                    ["id":"root","component":"Column","children":["review","audio"]],
                    ["id":"review","component":"Button","child":"reviewLabel","action":["event":["name":"review_fixture","context":[:]]]],
                    ["id":"reviewLabel","component":"Text","text":"Review fixture action"], media
                ]
                surface[1]["updateComponents"] = update
                let payload = String(decoding:try JSONSerialization.data(withJSONObject:surface,options:.sortedKeys),as:UTF8.self)
                entries = [["no":0,"type":"response","agentno":1,"content":"Synthetic subordinate audio.\n```a2ui\n" + payload + "\n```"]]
            }
            if args.contains("--synthetic-agent-team"), !context.isEmpty {
                entries = [["no":0,"type":"response","agentno":0,"content":context == "chat-new" ? "New child conversation content":"Parent conversation stays here."],
                           ["no":1,"type":"tool","agentno":1,"heading":"Local agent activity","content":"An agent number alone is not a child chat."]]
            }
            if args.contains("--synthetic-jev"), let count = jevReplies[context], count > 0 {
                let surface = try JSONSerialization.jsonObject(with:Data(GenerativeGuide.expandedExample.utf8))
                let envelope:[String:Any] = ["version":1,"intent":"A useful overview","candidates":[["id":"overview","description":"Metrics, comparisons, events and tasks","surface":surface]]]
                let json = String(decoding:try JSONSerialization.data(withJSONObject:envelope,options:.sortedKeys),as:UTF8.self)
                entries.append(["no":count,"type":"response","content":"Your readable overview is ready.\n```a2ui-candidates\n" + json + "\n```"])
            }
            if args.contains("--synthetic-scroll-transcript"), !context.isEmpty {
                entries = (0..<20).map { ["no":$0,"type":"response","content":"History item \($0)\n\n" + String(repeating:"A readable conversation entry. ",count:10)] }
                if polls >= 5 { entries.append(["no":20,"type":"response","content":"Newest update"]) }
            }
            if args.contains("--synthetic-app-store") {
                contexts = ["chat-alpha", "chat-beta"]
                if !context.isEmpty {
                    entries = [
                        ["no":0,"type":"user","content":"Help me plan a focused afternoon with time to recharge."],
                        ["no":1,"type":"response","heading":"icon://chat A0: Responding","content":"## Your afternoon, simplified\n\n**1:00 · Focus**\nOne task. Fifty minutes. Notifications off.\n\n**2:00 · Recharge**\nTake a walk and step away from your screen.\n\n**2:30 · Wrap up**\nReview progress and choose tomorrow’s first step."]
                    ]
                }
            }
            let replacedMedia = args.contains("--synthetic-media-replacement") && mediaResponseSelectedAt.map { Date().timeIntervalSince($0) >= 25 } == true
            data = ["context": context, "deselect_chat": false,
                    "contexts": contexts.map { id -> [String:Any] in
                        var row: [String:Any] = ["id": id, "name": conversationFixture ? id : "HTTP fixture chat", "running": false]
                        if args.contains("--synthetic-agent-team"), ["chat-existing","chat-new"].contains(id) {
                            row["name"] = id == "chat-new" ? "Media researcher":"Earlier researcher"
                            row["parent_context_id"] = "chat-alpha"; row["parent_agent_number"] = 0
                            row["parent_context_kind"] = "subordinate"; row["parent_context_label"] = "Agent Zero"
                            row["subordinate_slot"] = id == "chat-new" ? 2:1
                        }
                        if args.contains("--synthetic-app-store") { row["name"] = id == "chat-alpha" ? "Your afternoon":"Ideas for the weekend" }
                        if args.contains("--synthetic-projects"),let name = contextProjects[id],let project = projectDocuments[name] { row["project"] = project }
                        return row
                    }, "tasks": [],
                    "logs": entries, "log_guid": conversationFixture ? "fixture-log-" + context : "fixture-log", "log_version": recoveryFixture ? 1 : entries.count + (replacedMedia ? 1:0),
                    "log_progress": args.contains("--synthetic-agent-work") && !stoppedContexts.contains(context) ? "icon://psychology A1: Reviewing sources" : "", "log_progress_active": args.contains("--synthetic-agent-work") && !stoppedContexts.contains(context), "paused": false,
                    "notifications": [], "notifications_guid": "fixture-notices", "notifications_version": recoveryFixture ? 1 : 0]
        default: throw ClientError.unexpectedResponse
        }
        return HTTPResponse(data: try JSONSerialization.data(withJSONObject: data), status: 200, headers: ["Content-Type": "application/json"])
    }
    @MainActor private static func screenshotFixture() -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size:CGSize(width:960,height:600),format:format).pngData { renderer in
            UIColor(red:0.96,green:0.96,blue:0.94,alpha:1).setFill(); renderer.fill(CGRect(x:0,y:0,width:960,height:600))
            UIColor(red:0.12,green:0.15,blue:0.17,alpha:1).setFill(); renderer.fill(CGRect(x:0,y:0,width:960,height:54))
            for x in [24,44,64] { UIColor.gray.setFill(); UIBezierPath(ovalIn:CGRect(x:x,y:22,width:10,height:10)).fill() }
            func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ color:UIColor,_ weight:UIFont.Weight = .regular) {
                (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color])
            }
            text("example.test / field-notes",110,15,18,.white)
            text("FIELD NOTES",56,98,18,.darkGray,.semibold)
            text("A quieter way to explore.",56,141,45,.black,.bold)
            text("Independent ideas, thoughtfully collected.",56,205,22,.darkGray)
            for i in 0..<3 {
                let x = CGFloat(56 + i * 292)
                UIColor(red:0.73-Double(i)*0.08,green:0.80-Double(i)*0.03,blue:0.73+Double(i)*0.05,alpha:1).setFill()
                UIBezierPath(roundedRect:CGRect(x:x,y:270,width:264,height:190),cornerRadius:14).fill()
                UIColor.white.withAlphaComponent(0.45).setFill()
                UIBezierPath(ovalIn:CGRect(x:x+70,y:302,width:124,height:124)).fill()
                text(["Everyday discoveries","Open landscapes","Small details"][i],x,480,21,.black,.semibold)
                text("Explore the collection →",x,516,17,.darkGray)
            }
        }
    }

}
actor PreviewFailingStore: SessionStoring {
    func load(_ profile: ProfileIdentity) -> SessionArchive? { nil }
    func save(_ archive: SessionArchive) throws { throw PersistenceError.writeFailed }
}
#endif
