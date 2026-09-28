import Foundation

/// Agent Zero WebUI icon tokens are presentation metadata, never URLs to open.
public struct LogHeading: Sendable, Equatable {
    public let text: String
    public let symbol: String?
    public init(_ source: String) {
        let expression = try! NSRegularExpression(pattern: #"icon://([a-zA-Z0-9_]+)(\[(?:\\.|[^\]])*\])?"#)
        let range = NSRange(source.startIndex...,in:source)
        let firstMatch = expression.firstMatch(in:source,range:range)
        if let match = firstMatch, let name = Range(match.range(at:1),in:source) {
            symbol = Self.symbols[String(source[name])] ?? "circle.grid.2x2"
        } else { symbol = nil }
        let cleaned = expression.stringByReplacingMatches(in:source,range:range,withTemplate:"")
            .trimmingCharacters(in:.whitespacesAndNewlines)
        if cleaned.isEmpty, let match = firstMatch, let tooltip = Range(match.range(at:2),in:source) {
            text = String(source[tooltip].dropFirst().dropLast())
                .replacingOccurrences(of:"\\[",with:"[").replacingOccurrences(of:"\\]",with:"]")
                .replacingOccurrences(of:"\\\\",with:"\\")
        } else { text = cleaned }
    }
    private static let symbols = [
        "chat":"bubble.left.and.bubble.right", "construction":"wrench.and.screwdriver",
        "psychology":"brain", "lightbulb":"lightbulb", "step":"arrow.right.circle",
        "terminal":"terminal", "code":"chevron.left.forwardslash.chevron.right",
        "search":"magnifyingglass", "language":"globe", "public":"globe",
        "memory":"brain.head.profile", "communication":"person.2",
        "warning":"exclamationmark.triangle", "error":"exclamationmark.octagon",
        "info":"info.circle", "timer":"timer", "done_all":"checkmark.circle", "check":"checkmark"
    ]
}

public struct ActivityPresentation: Sendable {
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let summary: String
    public let isStructuredContent: Bool
    public let fields: [String:JSONValue]
    public let heading: LogHeading
    public let agentNumber: Int?
    public var agentLabel: String? { agentNumber.map { "Agent \($0)" } }

    public init(_ entry: LogEntry) {
        heading = LogHeading(entry.heading ?? "")
        agentNumber = Self.agentNumber(for: entry)
        if heading.text.range(of:"^A[0-9]+: Using .+$",options:.regularExpression) != nil {
            let agent = heading.text.prefix(while: { $0 != ":" })
            subtitle = "\(agent) · \(entry.type == "agent" ? "Agent step" : "Tool call")"
        } else { subtitle = heading.text }
        let content = entry.content ?? ""
        let trimmed = content.trimmingCharacters(in:.whitespacesAndNewlines)
        isStructuredContent = trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
        // Structured server fields take precedence; decoding content only supports
        // older events. Bound work for long outputs and incomplete streaming JSON.
        let decoded = content.utf8.count <= 64_000
            ? (try? JSONDecoder().decode([String:JSONValue].self,from:Data(content.utf8))) : nil
        let metadata = (decoded ?? [:]).merging(entry.kvps ?? [:]) { _,structured in structured }
        let tool = metadata["_tool_name"]?.stringValue ?? metadata["tool_name"]?.stringValue ?? ""
        var values = metadata
        if case .object(let arguments) = metadata["tool_args"] { values = arguments }
        fields = values.filter { !$0.key.hasPrefix("_") && !["tool_name","tool_args","headline","step"].contains($0.key) }
        let known = Self.tools[tool]
        let fallbackTitles = ["response":"Response", "agent":"Agent step", "tool":"Tool call", "code_exe":"Run code", "util":"Context", "browser":"Browse web", "mcp":"Connected tool", "subagent":"Subagent", "warning":"Warning", "error":"Error", "info":"Information", "progress":"Progress"]
        title = known?.0 ?? (tool.isEmpty ? fallbackTitles[entry.type] ?? "Activity" : tool.replacingOccurrences(of:"_",with:" ").prefix(1).uppercased() + tool.replacingOccurrences(of:"_",with:" ").dropFirst())
        if entry.type == "error" { symbol = "exclamationmark.octagon" }
        else if entry.type == "warning" { symbol = "exclamationmark.triangle" }
        else { symbol = known?.1 ?? heading.symbol ?? Self.typeSymbols[entry.type] ?? "circle.grid.2x2" }
        let argument = ["query","url","text","code","message"].compactMap { values[$0]?.stringValue }.first { !$0.isEmpty }
        if let argument { summary = String(argument.prefix(180)) }
        else if let step = metadata["step"]?.stringValue, !step.isEmpty { summary = LogHeading(step).text }
        else if !trimmed.isEmpty && !isStructuredContent { summary = String(LogHeading(trimmed).text.prefix(180)) }
        else if isStructuredContent { summary = decoded == nil && metadata.isEmpty ? "Receiving activity…" : "Expand to inspect this step" }
        else { summary = "Expand to inspect this step" }
    }
    public static func agentNumber(for entry: LogEntry) -> Int? {
        if let number = entry.agentno, number >= 0 { return number }
        let heading = LogHeading(entry.heading ?? "").text
        guard let colon = heading.firstIndex(of: ":"), heading.first == "A" else { return nil }
        let digits = heading[heading.index(after: heading.startIndex)..<colon]
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(digits), value >= 0 else { return nil }
        return value
    }
    private static let tools: [String:(String,String)] = [
        "search_engine":("Search web","globe"), "browser_agent":("Browse web","globe"),
        "code_execution_tool":("Run code","terminal"), "response":("Compose response","text.bubble"),
        "memory_load":("Search memory","brain.head.profile"), "memory_save":("Save memory","brain.head.profile"),
        "memory_delete":("Update memory","brain.head.profile"), "memory_forget":("Update memory","brain.head.profile"),
        "call_subordinate":("Delegate to agent","person.2"),
        "delegate_parallel":("Delegate in parallel","person.3"), "skills_tool":("Load skill","books.vertical"),
        "vision_load":("Inspect image","photo"), "wait":("Wait","timer")
    ]
    private static let typeSymbols = ["agent":"brain", "tool":"wrench.and.screwdriver", "code_exe":"terminal", "util":"tray.full", "browser":"globe", "subagent":"person.2", "mcp":"point.3.connected.trianglepath.dotted", "info":"info.circle", "progress":"ellipsis.circle"]
}

private extension JSONValue {
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
}

/// Last recorded activity per attributed agent; this does not infer agent liveness.
public struct AgentActivitySummary: Identifiable, Sendable {
    public var id: Int { agentNumber }
    public let agentNumber: Int
    public let latest: LogEntry
    public let count: Int
    public static func make(_ logs: [LogEntry]) -> [Self] {
        var byAgent: [Int: [LogEntry]] = [:]
        for log in logs where log.type != "user" {
            guard let number = ActivityPresentation.agentNumber(for: log) else { continue }
            byAgent[number, default: []].append(log)
        }
        return byAgent.keys.sorted().compactMap { number in
            guard let entries = byAgent[number], let last = entries.last else { return nil }
            return Self(agentNumber: number, latest: last, count: entries.count)
        }
    }
}

/// Working state comes from the server's active flag, not a historical tool row.
public struct AgentWorkPresentation: Sendable {
    public let title: String
    public let symbol: String
    public let isWorking: Bool
    public init(progress: JSONValue, active: Bool, paused: Bool, synchronizing: Bool) {
        let heading = LogHeading(progress.string ?? "")
        isWorking = active && !paused && !synchronizing
        if synchronizing { title = "Updating conversation"; symbol = "arrow.triangle.2.circlepath" }
        else if paused { title = "Agent paused"; symbol = "pause.circle" }
        else if active { title = heading.text.isEmpty ? "Agent Zero is working" : heading.text; symbol = heading.symbol ?? "brain" }
        else { title = "Ready for your next message"; symbol = "bubble.left" }
    }
}
