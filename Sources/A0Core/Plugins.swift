import Foundation

public enum PluginError: Error, Sendable, Equatable, LocalizedError {
    case invalidIdentity, protectedPlugin, rejected, invalidSource, unavailable
    public var errorDescription: String? {
        switch self {
        case .invalidIdentity: "The server returned an invalid plugin identity."
        case .protectedPlugin: "This action is not available for this plugin."
        case .rejected: "Agent Zero did not confirm this operation. Check the plugin before trying again."
        case .invalidSource: "This plugin does not have a supported HTTPS repository."
        case .unavailable: "This plugin feature is unavailable on the connected server."
        }
    }
}

public struct InstalledPlugin: Sendable, Equatable, Identifiable {
    public let fields: [String:JSONValue]
    public let id: String
    public init(fields:[String:JSONValue]) throws {
        guard let name = fields["name"]?.string else { throw PluginError.invalidIdentity }
        try PluginIdentity.validate(name); self.id = name; self.fields = fields
    }
    public var title:String { let value = fields["display_name"]?.string ?? ""; return value.isEmpty ? id : value }
    public var summary:String { fields["description"]?.string ?? "" }
    public var version:String { fields["version"]?.string ?? "" }
    public var author:String { fields["author"]?.string ?? "" }
    public var isCustom:Bool { fields["is_custom"] == .bool(true) }
    public var alwaysEnabled:Bool { fields["always_enabled"] == .bool(true) }
    public var hasMain:Bool { fields["has_main_screen"] == .bool(true) }
    public var hasSettings:Bool { fields["has_config_screen"] == .bool(true) || perProject || perAgent }
    public var perProject:Bool { fields["per_project_config"] == .bool(true) }
    public var perAgent:Bool { fields["per_agent_config"] == .bool(true) }
    public var state:String { alwaysEnabled ? "enabled" : fields["toggle_state"]?.string ?? "unknown" }
}
public enum PluginIdentity {
    public static func validate(_ value:String) throws {
        guard !value.isEmpty, value.count <= 160, value != ".", value != "..",
              value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "_-".contains($0)) }) else { throw PluginError.invalidIdentity }
    }
}
public struct PluginScope: Sendable, Equatable, Hashable {
    public var project:String
    public var agent:String
    public init(project:String = "",agent:String = "") { self.project = project; self.agent = agent }
    public var label:String { [project.isEmpty ? "Global" : project, agent.isEmpty ? "All agents" : agent].joined(separator:" · ") }
    var payload:[String:JSONValue] { ["project_name":.string(project),"agent_profile":.string(agent)] }
}
public struct PluginScopeOption: Sendable, Identifiable {
    public let id:String
    public let title:String
}
public struct PluginToggleStatus: Sendable {
    public let enabled:Bool
    public let loadedScope:PluginScope
    public let path:String
    public func hasOverride(in scope:PluginScope) -> Bool { !path.isEmpty && loadedScope == scope }
}
public enum PluginCommand: Sendable {
    case activate(InstalledPlugin,Bool,PluginScope)
    case removeOverride(InstalledPlugin,String)
    case delete(InstalledPlugin)
    case install(PluginHubEntry)
    case update(InstalledPlugin)
    public var title:String {
        switch self {
        case .activate(_,let enabled,_): enabled ? "Activate plugin" : "Deactivate plugin"
        case .removeOverride: "Remove plugin override"
        case .delete: "Delete plugin"
        case .install: "Install plugin"
        case .update: "Update plugin"
        }
    }
    public var pluginID:String {
        switch self { case .activate(let p,_,_),.removeOverride(let p,_),.delete(let p),.update(let p):p.id; case .install(let p):p.id }
    }
    public func validatedRequest() throws -> (path:String,payload:[String:JSONValue],installer:Bool) {
        try PluginIdentity.validate(pluginID)
        var payload:[String:JSONValue] = ["plugin_name":.string(pluginID)]
        var installer = false
        switch self {
        case .activate(let plugin,let enabled,let scope):
            guard !plugin.alwaysEnabled, scope.project.isEmpty || plugin.perProject, scope.agent.isEmpty || plugin.perAgent else { throw PluginError.protectedPlugin }
            payload.merge(scope.payload,uniquingKeysWith: { _,new in new })
            payload["action"] = .string("toggle_plugin"); payload["enabled"] = .bool(enabled); payload["clear_overrides"] = .bool(false)
        case .removeOverride(let plugin,let path):
            guard !plugin.alwaysEnabled,!path.isEmpty else { throw PluginError.protectedPlugin }
            payload["action"] = .string("delete_config"); payload["path"] = .string(path)
        case .delete(let plugin):
            guard plugin.isCustom else { throw PluginError.protectedPlugin }
            payload["action"] = .string("delete_plugin")
        case .install(let entry):
            guard entry.suspension.isEmpty else { throw PluginError.protectedPlugin }
            guard let source = entry.source else { throw PluginError.invalidSource }
            installer = true; payload["action"] = .string("install_git"); payload["git_url"] = .string(source.absoluteString)
        case .update(let plugin):
            guard plugin.isCustom else { throw PluginError.protectedPlugin }
            installer = true; payload["action"] = .string("update_plugin")
        }
        return (installer ? PluginHubEntry.endpoint : "/api/plugins",payload,installer)
    }
}

extension APIClient {
    func pluginResponse(path:String,payload:[String:JSONValue],installer:Bool = false) async throws -> [String:JSONValue] {
        _ = try socketSession()
        let response = try await request(path,method:"POST",body:JSONEncoder().encode(payload))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        if response.status == 404 { throw PluginError.unavailable }
        try validate(response)
        guard response.data.count <= 8_388_608 else { throw ClientError.incompatiblePayload }
        let result:[String:JSONValue] = try decode(response.data)
        guard case .bool(let success) = result[installer ? "success":"ok"] else { throw ClientError.incompatiblePayload }
        guard success else { throw PluginError.rejected }
        return result
    }
    public func installedPlugins() async throws -> [InstalledPlugin] {
        let response = try await pluginResponse(path:"/api/plugins_list",payload:["filter":.object(["custom":.bool(true),"builtin":.bool(true)])])
        guard case .array(let rows) = response["plugins"],rows.count <= 5000 else { throw ClientError.incompatiblePayload }
        let plugins = try rows.map { row in
            guard case .object(let fields) = row else { throw ClientError.incompatiblePayload }
            return try InstalledPlugin(fields:fields)
        }
        guard Set(plugins.map(\.id)).count == plugins.count else { throw ClientError.incompatiblePayload }
        return plugins.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    public func pluginStatus(_ id:String,scope:PluginScope) async throws -> PluginToggleStatus {
        try PluginIdentity.validate(id)
        let result = try await pluginResponse(path:"/api/plugins",payload:scope.payload.merging(["action":.string("get_toggle_status"),"plugin_name":.string(id)],uniquingKeysWith:{ _,new in new }))
        guard let status = result["status"]?.string,["enabled","disabled"].contains(status) else { throw ClientError.incompatiblePayload }
        return PluginToggleStatus(enabled:status == "enabled",loadedScope:PluginScope(project:result["loaded_project_name"]?.string ?? "",agent:result["loaded_agent_profile"]?.string ?? ""),path:result["loaded_path"]?.string ?? "")
    }
    public func pluginScopeOptions(agents:Bool) async throws -> [PluginScopeOption] {
        let result = try await pluginResponse(path:agents ? "/api/agents":"/api/projects",payload:["action":.string(agents ? "list":"list_options")])
        guard case .array(let rows) = result["data"],rows.count <= 5000 else { throw ClientError.incompatiblePayload }
        let options = rows.compactMap { item -> PluginScopeOption? in
            guard case .object(let fields) = item,let key = fields["key"]?.string,!key.isEmpty else { return nil }
            return PluginScopeOption(id:key,title:fields["label"]?.string ?? key)
        }
        guard Set(options.map(\.id)).count == options.count else { throw ClientError.incompatiblePayload }
        return options
    }
    public func pluginDocument(_ id:String,license:Bool = false) async throws -> String {
        try PluginIdentity.validate(id)
        let result = try await pluginResponse(path:"/api/plugins",payload:["action":.string("get_doc"),"plugin_name":.string(id),"doc":.string(license ? "license":"readme")])
        guard let content = result["content"]?.string,content.utf8.count <= 1_048_576 else { throw ClientError.incompatiblePayload }
        return content
    }
    /// The caller must persist command intent first. No command is automatically retried.
    public func performPluginCommand(_ command:PluginCommand) async throws {
        let request = try command.validatedRequest()
        _ = try await pluginResponse(path:request.path,payload:request.payload,installer:request.installer)
    }
}
