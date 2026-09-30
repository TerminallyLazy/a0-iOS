import Foundation

/// Presentation data only. No downloaded script or stylesheet is executed by native UI.
public struct ServerTheme: Sendable, Equatable {
    public static let keys = ["background","text","text-muted","primary","secondary","accent","message-bg","highlight","message-text","panel","border","input","input-focus","chat-background","error-text","warning-text","table-row"]
    public struct Gradient: Sendable, Equatable {
        public let angle: Double
        public let colors: [String]
        public let locations: [Double]
    }
    public struct Palette: Sendable, Equatable {
        public let colors: [String:String]
        public let gradient: Gradient?
    }
    public let id: String
    public let name: String
    public let dark: Palette
    public let light: Palette

    public static func resolve(config:[String:JSONValue],css:String) throws -> Self {
        guard css.utf8.count <= 131_072, (try JSONEncoder().encode(config)).count <= 262_144 else { throw ClientError.incompatiblePayload }
        let selected = config["theme"]?.string ?? "aurora"
        guard selected.count <= 80, selected.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { throw ClientError.incompatiblePayload }
        var custom:[String:JSONValue]?
        if case .array(let values) = config["custom_themes"] {
            guard values.count <= 100 else { throw ClientError.incompatiblePayload }
            custom = values.compactMap { value -> [String:JSONValue]? in
                if case .object(let fields) = value,fields["id"]?.string == selected { return fields }; return nil
            }.first
        }
        func builtin(_ id:String,_ mode:String) -> Palette? {
            let selector = "body[data-selectable-theme=\"\(id)\"].\(mode)-mode"
            guard let start = css.range(of:selector),let left = css[start.upperBound...].firstIndex(of:"{"),let right = css[left...].firstIndex(of:"}") else { return nil }
            let declarations = css[css.index(after:left)..<right].split(separator:";").reduce(into:[String:String]()) { result,line in
                guard let colon = line.firstIndex(of:":") else { return }
                result[String(line[..<colon]).trimmingCharacters(in:.whitespacesAndNewlines)] = String(line[line.index(after:colon)...]).trimmingCharacters(in:.whitespacesAndNewlines)
            }
            let colors = Dictionary(uniqueKeysWithValues:keys.compactMap { key in declarations["--color-"+key].map { (key,$0) } })
            guard colors.count == keys.count,colors.values.allSatisfy(validColor) else { return nil }
            return Palette(colors:colors,gradient:declarations["--st-gradient"].flatMap(parseGradient))
        }
        func customPalette(_ mode:String,_ fields:[String:JSONValue]) throws -> Palette {
            guard case .object(let values) = fields[mode] else { throw ClientError.incompatiblePayload }
            let colors = Dictionary(uniqueKeysWithValues:keys.compactMap { key in values[key]?.string.map { (key,$0) } })
            guard colors.count == keys.count,colors.values.allSatisfy(validColor) else { throw ClientError.incompatiblePayload }
            var gradient:Gradient?
            if case .object(let g) = fields["gradient"],g["enabled"] != .bool(false),case .array(let stops) = g["stops"] {
                let colors = stops.compactMap(\.string)
                let angle:Double
                if case .number(let n) = g["angle"] { angle = n } else { angle = 135 }
                guard angle.isFinite,colors.count >= 2,colors.count <= 8,colors.count == stops.count,colors.allSatisfy(validColor) else { throw ClientError.incompatiblePayload }
                gradient = Gradient(angle:angle.truncatingRemainder(dividingBy:360),colors:colors,locations:colors.indices.map { Double($0)/Double(colors.count-1) })
            }
            return Palette(colors:colors,gradient:gradient)
        }
        if let dark = builtin(selected,"dark"),let light = builtin(selected,"light") {
            return Self(id:selected,name:selected.replacingOccurrences(of:"-",with:" ").capitalized,dark:dark,light:light)
        }
        if selected.hasPrefix("custom-"),let custom {
            let name = String((custom["name"]?.string ?? "Custom theme").prefix(80))
            return try Self(id:selected,name:name,dark:customPalette("dark",custom),light:customPalette("light",custom))
        }
        guard let dark = builtin("aurora","dark"),let light = builtin("aurora","light") else { throw ClientError.incompatiblePayload }
        return Self(id:"aurora",name:"Aurora",dark:dark,light:light)
    }
    private static func validColor(_ value:String) -> Bool {
        !value.isEmpty && value.utf8.count <= 160 && !value.contains(where: { ";{}<>\\".contains($0) }) && !value.lowercased().contains("url(") && !value.lowercased().contains("var(")
    }
    /// The plugin emits linear gradients with degree angles and explicit percentage stops.
    static func parseGradient(_ value:String) -> Gradient? {
        guard value.hasPrefix("linear-gradient("),value.hasSuffix(")"),value.count <= 2048 else { return nil }
        var pieces:[String] = [],current = "",depth = 0
        for char in value.dropFirst(16).dropLast() {
            if char == "(" { depth += 1 }; if char == ")" { depth -= 1 }
            if char == "," && depth == 0 { pieces.append(current.trimmingCharacters(in:.whitespaces));current = "" } else { current.append(char) }
        }
        pieces.append(current.trimmingCharacters(in:.whitespaces))
        guard pieces.count >= 3,pieces.count <= 9,pieces[0].hasSuffix("deg"),let angle = Double(pieces[0].dropLast(3)),angle.isFinite else { return nil }
        var colors:[String] = [],locations:[Double] = []
        for piece in pieces.dropFirst() {
            guard let split = piece.lastIndex(of:" "),piece.hasSuffix("%"),let percent = Double(piece[piece.index(after:split)...].dropLast()),(0...100).contains(percent) else { return nil }
            let color = String(piece[..<split]);guard validColor(color) else { return nil }
            colors.append(color);locations.append(percent/100)
        }
        guard locations == locations.sorted() else { return nil }
        return Gradient(angle:angle.truncatingRemainder(dividingBy:360),colors:colors,locations:locations)
    }
}

extension APIClient {
    /// Read-only plugin actions; theme matching never saves plugin configuration.
    public func serverTheme() async throws -> ServerTheme? {
        guard try await pluginStatus("selectable_theme",scope:PluginScope()).enabled else { return nil }
        let result = try await pluginResponse(path:"/api/plugins",payload:["action":.string("get_config"),"plugin_name":.string("selectable_theme"),"project_name":.string(""),"agent_profile":.string("")])
        guard case .object(let config) = result["data"] else { throw ClientError.incompatiblePayload }
        let session = try socketSession()
        let url = session.origin.url.appendingPathComponent("plugins/selectable_theme/webui/themes.css")
        var request = URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:15)
        request.setValue(session.cookieHeader,forHTTPHeaderField:"Cookie")
        request.setValue(session.origin.header,forHTTPHeaderField:"Origin")
        request.setValue("text/css",forHTTPHeaderField:"Accept")
        if url.host?.lowercased().hasSuffix(".devtunnels.ms") == true { request.setValue("true",forHTTPHeaderField:"X-Tunnel-Skip-AntiPhishing-Page") }
        let response = try await boundedImageRequest(request,maximumBytes:131_072)
        guard response.status == 200,response.header("Content-Type")?.lowercased().hasPrefix("text/css") == true,
              let css = String(data:response.data,encoding:.utf8) else { throw ClientError.unexpectedResponse }
        return try ServerTheme.resolve(config:config,css:css)
    }
}
