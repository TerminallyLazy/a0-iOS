#if DEBUG
import Foundation
import UIKit
import A0Core
import A0GenerativeUI

/// Deterministic UI test server; no network, credentials, or model execution.
actor PreviewHTTPTransport: HTTPTransport {
    private var loggedIn = false
    private var stoppedContexts = Set<String>()
    private var contexts: [String] = []
    private var polls = 0
    private var pollFailures = 0
    private var recoveredFullSnapshot = false
    private var modelPresets: [[String:Any]] = [
        ["name":"Default", "chat":["provider":"fixture", "name":"main-model", "ctx_length":200000, "vision":true, "kwargs":["temperature":0.3]], "utility":["provider":"fixture", "name":"utility-model"], "embedding":["provider":"fixture", "name":"embedding-model"], "custom_setting":"preserve"],
        ["name":"Focused", "chat":["provider":"fixture", "name":"focused-model"]]
    ]
    private var presetOverrides: [String:String] = [:]
    private var globalPreset = "Default"
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
            if ProcessInfo.processInfo.arguments.contains("--synthetic-send-timeout") { throw URLError(.timedOut) }
            let raw = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
            let multipartContext = raw.components(separatedBy: "name=\"context\"\r\n\r\n").dropFirst().first?.components(separatedBy: "\r\n").first
            data = ["context": payload["context"] as? String ?? multipartContext ?? ""]
        case "/api/message_queue_add": data = ["ok": true, "item_id": payload["item_id"] as? String ?? ""]
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
            if args.contains("--synthetic-scroll-transcript"), !context.isEmpty {
                entries = (0..<20).map { ["no":$0,"type":"response","content":"History item \($0)\n\n" + String(repeating:"A readable conversation entry. ",count:10)] }
                if polls >= 5 { entries.append(["no":20,"type":"response","content":"Newest update"]) }
            }
            data = ["context": context, "deselect_chat": false,
                    "contexts": contexts.map { id -> [String:Any] in
                        var row: [String:Any] = ["id": id, "name": conversationFixture ? id : "HTTP fixture chat", "running": false]
                        if args.contains("--synthetic-projects"),let name = contextProjects[id],let project = projectDocuments[name] { row["project"] = project }
                        return row
                    }, "tasks": [],
                    "logs": entries, "log_guid": conversationFixture ? "fixture-log-" + context : "fixture-log", "log_version": recoveryFixture ? 1 : entries.count,
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
