import Foundation

/// Native, non-executable Markdown blocks. Inline emphasis/links are rendered by
/// Foundation in the app. Unsupported syntax stays visible as literal text.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(Int, String), paragraph(String), listItem(String, String)
    case quote(String), code(String, String), table([[String]]), divider
}
public enum MarkdownDocument {
    public static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var result: [MarkdownBlock] = [], paragraph: [String] = []
        var index = 0
        func flush() {
            if !paragraph.isEmpty { result.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }
        while index < lines.count {
            let line = lines[index], text = line.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { flush(); index += 1; continue }
            if let first = text.first, first == "`" || first == "~" {
                let count = text.prefix(while: { $0 == first }).count
                if count >= 3 {
                    flush(); let language = String(text.dropFirst(count)).trimmingCharacters(in: .whitespaces)
                    index += 1; var code: [String] = []
                    while index < lines.count {
                        let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                        if candidate.prefix(while: { $0 == first }).count >= count,
                           candidate.allSatisfy({ $0 == first }) { index += 1; break }
                        code.append(lines[index]); index += 1
                    }
                    result.append(.code(language,code.joined(separator:"\n"))); continue
                }
            }
            if index + 1 < lines.count, text.contains("|"), isTableRule(lines[index + 1]) {
                flush(); var rows = [cells(text)]; index += 2
                while index < lines.count, lines[index].contains("|"), !lines[index].trimmingCharacters(in:.whitespaces).isEmpty {
                    rows.append(cells(lines[index])); index += 1
                }
                result.append(.table(rows)); continue
            }
            let hashes = text.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), text.dropFirst(hashes).first == " " {
                flush()
                var title = String(text.dropFirst(hashes + 1))
                if title.hasSuffix(" #") || title.hasSuffix("##") {
                    title = title.replacingOccurrences(of: "\\s+#+$", with:"", options:.regularExpression)
                }
                result.append(.heading(hashes,title)); index += 1; continue
            }
            if ["---","***","___"].contains(text) { flush(); result.append(.divider); index += 1; continue }
            if text.hasPrefix(">") {
                flush(); result.append(.quote(String(text.dropFirst()).trimmingCharacters(in:.whitespaces))); index += 1; continue
            }
            if text.hasPrefix("- ") || text.hasPrefix("* ") || text.hasPrefix("+ ") {
                flush(); var body = String(text.dropFirst(2)), marker = "•"
                if body.hasPrefix("[x] ") || body.hasPrefix("[X] ") { marker = "☑"; body = String(body.dropFirst(4)) }
                else if body.hasPrefix("[ ] ") { marker = "☐"; body = String(body.dropFirst(4)) }
                result.append(.listItem(marker,body)); index += 1; continue
            }
            if let range = text.range(of:"^[0-9]+[.)] ",options:.regularExpression) {
                flush(); result.append(.listItem(String(text[range]).trimmingCharacters(in:.whitespaces),String(text[range.upperBound...]))); index += 1; continue
            }
            paragraph.append(line); index += 1
        }
        flush(); return result
    }
    private static func cells(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in:.whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") { text.removeLast() }
        return text.components(separatedBy:"|").map { $0.trimmingCharacters(in:.whitespaces) }
    }
    private static func isTableRule(_ line: String) -> Bool {
        let columns = cells(line)
        return !columns.isEmpty && columns.allSatisfy { cell in
            let rule = cell.trimmingCharacters(in:CharacterSet(charactersIn:": "))
            return rule.count >= 3 && rule.allSatisfy { $0 == "-" }
        }
    }
}
public enum MessagePresentation {
    public static func isActivity(_ type: String) -> Bool { !["user","response"].contains(type) }
    public static func collapses(type: String, content: String) -> Bool {
        isActivity(type) || content.count > 900 || content.filter { $0 == "\n" }.count >= 12
    }
    public static func externalURL(_ value: String) -> URL? {
        guard let url = URL(string:value), ["http","https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
}
