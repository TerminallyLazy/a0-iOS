import Foundation
import A0Core

/// Only explicit assistant reply payloads opt into native rendering. Ordinary
/// JSON, quoted examples and user/tool content remain ordinary messages.
public struct GeneratedContent: Equatable, Sendable {
    public let prose: String
    public let source: String
    public let complete: Bool
    public static func extract(_ entry: LogEntry) -> Self? {
        guard entry.type == "response" else { return nil }
        let text = entry.content ?? ""
        if let value = entry.kvps?["a2ui"] {
            guard let data = try? JSONEncoder().encode(value) else { return nil }
            return Self(prose:text,source:String(decoding:data,as:UTF8.self),complete:true)
        }
        let lines = text.components(separatedBy:"\n")
        // Walk fences so an a2ui example nested inside another code block never opts in.
        var outerFence: String?
        for (index,line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in:.whitespaces)
            if let fence = outerFence {
                if trimmed == fence { outerFence = nil }
                continue
            }
            if trimmed == "```a2ui" {
                let end = lines.indices.dropFirst(index + 1).first { lines[$0].trimmingCharacters(in:.whitespaces) == "```" }
                let contentEnd = end ?? lines.count
                let source = lines[(index + 1)..<contentEnd].joined(separator:"\n")
                let tail = end.map { Array(lines.dropFirst($0 + 1)) } ?? []
                // Multiple surfaces belong in separate response entries, not ambiguous blocks.
                let multiple = tail.contains { $0.trimmingCharacters(in:.whitespaces) == "```a2ui" }
                return Self(prose:(Array(lines.prefix(index)) + tail).joined(separator:"\n"),source:multiple ? "" : source,complete:end != nil)
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let char = trimmed.first!
                outerFence = String(trimmed.prefix { $0 == char })
            }
        }
        return nil
    }
}
