import Foundation

public struct PluginHubEntry: Sendable, Equatable, Identifiable {
    static let endpoint = "/api/plugins/_plugin_installer/plugin_install"
    public let id:String
    public let fields:[String:JSONValue]
    public init(id:String,fields:[String:JSONValue]) throws { try PluginIdentity.validate(id); self.id = id; self.fields = fields }
    public var title:String { fields["title"]?.string ?? id }
    public var summary:String { fields["description"]?.string ?? "" }
    public var author:String { fields["author"]?.string ?? "" }
    public var version:String { fields["version"]?.string ?? "" }
    public var suspension:String {
        if let reason = fields["suspended"]?.string { return reason.trimmingCharacters(in:.whitespacesAndNewlines) }
        return fields["suspended"] == .bool(true) ? "Installation suspended by the Plugin Hub." : ""
    }
    public var tags:[String] {
        guard case .array(let tags) = fields["tags"] else { return [] }
        return tags.compactMap(\.string)
    }
    public var source:URL? { Self.httpsURL(fields["github"]?.string ?? "") }
    public static func httpsURL(_ text:String) -> URL? {
        guard let url = URL(string:text),url.scheme?.lowercased() == "https",let host = url.host,!host.isEmpty,
              url.user == nil,url.password == nil,url.fragment == nil,url.query == nil else { return nil }
        return url
    }
    public func hasUpdate(for plugin:InstalledPlugin?) -> Bool {
        guard let plugin else { return false }
        let latest = fields["commit"]?.string ?? fields["latest_commit"]?.string ?? ""
        let current = plugin.fields["current_commit"]?.string ?? ""
        guard !latest.isEmpty,!current.isEmpty,latest != current else { return false }
        let formatter = ISO8601DateFormatter()
        func date(_ string:String) -> Date? {
            formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
            if let date = formatter.date(from:string) { return date }
            formatter.formatOptions = [.withInternetDateTime]; return formatter.date(from:string)
        }
        if let new = date(fields["updated"]?.string ?? fields["latest_commit_timestamp"]?.string ?? ""),
           let old = date(plugin.fields["current_commit_timestamp"]?.string ?? ""),new != old { return new > old }
        return true
    }
}
public struct PluginHubCatalog: Sendable {
    public let entries:[PluginHubEntry]
    public let installedIDs:Set<String>
}
extension APIClient {
    public func pluginHub() async throws -> PluginHubCatalog {
        let result = try await pluginResponse(path:PluginHubEntry.endpoint,payload:["action":.string("fetch_index")],installer:true)
        guard case .object(let index) = result["index"],case .object(let plugins) = index["plugins"],plugins.count <= 10000,
              case .array(let installed) = result["installed_plugins"] else { throw ClientError.incompatiblePayload }
        let entries = try plugins.map { key,value in
            guard case .object(let fields) = value else { throw ClientError.incompatiblePayload }
            return try PluginHubEntry(id:key,fields:fields)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return PluginHubCatalog(entries:entries,installedIDs:Set(installed.compactMap(\.string)))
    }
}

public enum PluginScreenKind:String, Sendable { case main, settings, workspace }
public struct PluginScreenRoute: Identifiable, Sendable, Equatable {
    public let pluginID:String
    public let title:String
    public let kind:PluginScreenKind
    public let scope:PluginScope
    public let contextID:String?
    public var id:String { pluginID+":"+kind.rawValue+":"+(contextID ?? "") }
    public init(pluginID:String,title:String,kind:PluginScreenKind,scope:PluginScope = PluginScope(),contextID:String? = nil) throws {
        try PluginIdentity.validate(pluginID); self.pluginID = pluginID; self.title = title; self.kind = kind; self.scope = scope; self.contextID = contextID
    }
    /// This origin has already passed native authentication. Skip only the tunnel's browser interstitial.
    public func initialRequest(origin:ServerOrigin) -> URLRequest {
        // The root route is a splash that document.write-replaces itself. Load the actual
        // authenticated shell at a root-level path so its relative assets also resolve correctly.
        let document = origin.url.appendingPathComponent("index.html")
        var request = URLRequest(url:document,cachePolicy:.reloadIgnoringLocalCacheData)
        if origin.url.host?.lowercased().hasSuffix(".devtunnels.ms") == true {
            request.setValue("true",forHTTPHeaderField:"X-Tunnel-Skip-AntiPhishing-Page")
        }
        return request
    }
    public static func workspace(contextID:String? = nil) -> Self {
        // Fixed app-owned route; surfaces still come from the authenticated server registry.
        try! Self(pluginID:"workspace",title:"Workspace",kind:.workspace,contextID:contextID)
    }
    public func allowsDownload(_ url:URL,origin:ServerOrigin) -> Bool {
        if allows(url,origin:origin) { return true }
        guard url.scheme == "blob",let embedded = URL(string:String(url.absoluteString.dropFirst(5))) else { return false }
        return allows(embedded,origin:origin)
    }
    public func allows(_ url:URL,origin:ServerOrigin) -> Bool {
        url.scheme == origin.url.scheme && url.host == origin.url.host && (url.port ?? 443) == (origin.url.port ?? 443) && url.user == nil && url.password == nil
    }
}
