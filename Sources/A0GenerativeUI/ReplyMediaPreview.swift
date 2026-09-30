import Foundation
import A0Core

/// A passive invitation to load a direct file from ordinary assistant prose.
/// Discovery is pure: file type, MIME and playable tracks are checked only on Load.
public struct ReplyMediaPreview: Identifiable, Equatable, Sendable {
    public let url:String
    public let kind:MediaKind
    public var id:String { url }
    public var title:String { kind == .audio ? "Audio" : "Video" }
    public var content:MediaContent { MediaContent(title:title,url:url,transcript:nil,sourceURL:url) }

    public static func extract(_ entry:LogEntry) -> [Self] {
        guard entry.type == "response", let source = entry.content, source.utf8.count <= 131_072,
              entry.kvps?["a2ui"] == nil,
              GeneratedContent.extract(entry) == nil, JevCandidates.extract(entry) == nil,
              source.range(of:#"<[/!?A-Za-z]"#,options:.regularExpression) == nil else { return [] }
        // A raw protocol object is not prose, even without its required fence.
        if (try? JSONSerialization.jsonObject(with:Data(source.utf8))) != nil { return [] }
        var result:[Self] = [], seen:Set<String> = []
        func append(_ candidate:String) {
            guard result.count < 4, candidate.utf8.count <= 2048,
                  let url = RichImagePolicy.url(candidate), let kind = kind(for:url),
                  seen.insert(url.absoluteString).inserted else { return }
            result.append(Self(url:url.absoluteString,kind:kind))
        }
        // Markdown permits lazy quote continuations until a blank line. The local
        // block renderer is intentionally simpler, so remove those regions first.
        var quoted = false
        let unquoted = source.components(separatedBy:"\n").map { line -> String in
            let trimmed = line.trimmingCharacters(in:.whitespacesAndNewlines)
            if trimmed.isEmpty { quoted = false; return line }
            if trimmed.hasPrefix(">") { quoted = true }
            return quoted ? "" : line
        }.joined(separator:"\n")
        for block in MarkdownDocument.parse(unquoted) {
            let text:String
            switch block {
            case .paragraph(let value), .heading(_,let value), .listItem(_,let value): text = value
            case .table(let rows): text = rows.map { $0.joined(separator:" ") }.joined(separator:"\n")
            case .code,.quote,.divider: continue
            }
            // Raw HTML, images, reference definitions and indented code remain prose.
            // Reject the whole block rather than guessing at nested HTML boundaries.
            guard !text.contains("<"), !text.contains("!["),
                  !text.components(separatedBy:"\n").contains(where:{ line in
                      line.hasPrefix("    ") || line.hasPrefix("\t") || line.range(of:#"^\s*\[[^\]]+\]:"#,options:.regularExpression) != nil
                  }), let attributed = try? AttributedString(markdown:text,options:.init(interpretedSyntax:.inlineOnlyPreservingWhitespace)) else { continue }
            for run in attributed.runs {
                if run.inlinePresentationIntent?.contains(.code) == true { continue }
                if let link = run.link { append(link.absoluteString) }
            }
            if result.count == 4 { break }
        }
        return result
    }
    private static func kind(for url:URL) -> MediaKind? {
        switch url.pathExtension.lowercased() {
        case "mp3","m4a","aac","wav": .audio
        case "mp4","mov": .video
        default: nil
        }
    }
}
