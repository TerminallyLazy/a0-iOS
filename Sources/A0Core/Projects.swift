import Foundation

public enum ProjectError: Error, Sendable, Equatable, LocalizedError {
    case invalidName, invalidGitURL, serverRejected
    public var errorDescription: String? {
        switch self {
        case .invalidName: "Use a project folder name without slashes, control characters, or parent-directory references."
        case .invalidGitURL: "Enter an HTTPS repository URL without embedded credentials."
        case .serverRejected: "Agent Zero could not complete the project request. Check the project in the Web UI before trying again."
        }
    }
}

public struct ProjectSummary: Codable, Sendable, Equatable, Identifiable {
    public var name: String
    public var title: String
    public var description: String
    public var color: String
    public var id: String { name }
    public var displayTitle: String { title.isEmpty ? name : title }
    public init(name: String, title: String = "", description: String = "", color: String = "") {
        self.name = name; self.title = title; self.description = description; self.color = color
    }
    public init?(context: [String: JSONValue]) {
        guard case .object(let project) = context["project"], let name = project["name"]?.string,
              !name.isEmpty else { return nil }
        self.init(name:name,title:project["title"]?.string ?? "",color:project["color"]?.string ?? "")
    }
    enum CodingKeys: String, CodingKey { case name, title, description, color }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        name = try c.decode(String.self,forKey:.name)
        title = try c.decodeIfPresent(String.self,forKey:.title) ?? ""
        description = try c.decodeIfPresent(String.self,forKey:.description) ?? ""
        color = try c.decodeIfPresent(String.self,forKey:.color) ?? ""
    }
    /// Agent Zero Web UI palette, including its eight-digit CSS RGBA value.
    public static let colors = ["#7b2cbf", "#8338ec", "#9b5de5", "#d0bfff", "#002975ff", "#3a86ff", "#0077b6", "#4cc9f0", "#00bbf9", "#a5d8ff", "#00f5d4", "#06d6a0", "#1a7431", "#2a9d8f", "#b2f2bb", "#9ef01a", "#e9c46a", "#fee440", "#ffec99", "#ff9f43", "#fb5607", "#ffddb5", "#f95738", "#e76f51", "#ff6b6b", "#ffc9c9", "#f15bb5", "#ff006e", "#ffafcc", "#adb5bd", "#6c757d"]
}

/// In-memory edit document: preserve plugin fields, file settings and masked secret values.
/// Do not archive or log this payload; it can contain project variables and credentials.
public struct ProjectDocument: Sendable, Equatable {
    public var fields: [String: JSONValue]
    public init(fields: [String: JSONValue]) { self.fields = fields }
    public init(name: String, title: String) {
        fields = ["name":.string(name), "title":.string(title), "description":.string(""),
                  "instructions":.string(""), "color":.string("#3a86ff"), "git_url":.string(""),
                  "include_agents_md":.bool(true)]
        // Omit file_structure so the server supplies its current defaults and ignore patterns.
    }
    public var name: String { get { text("name") } set { fields["name"] = .string(newValue) } }
    public var title: String { get { text("title") } set { fields["title"] = .string(newValue) } }
    public var description: String { get { text("description") } set { fields["description"] = .string(newValue) } }
    public var instructions: String { get { text("instructions") } set { fields["instructions"] = .string(newValue) } }
    public var color: String { get { text("color") } set { fields["color"] = .string(newValue) } }
    public var gitURL: String { get { text("git_url") } set { fields["git_url"] = .string(newValue) } }
    public var variables: String { get { text("variables") } set { fields["variables"] = .string(newValue) } }
    public var secrets: String { get { text("secrets") } set { fields["secrets"] = .string(newValue) } }
    public var mcpServers: String { get { fields["mcp_servers"]?.string ?? "{\n  \"mcpServers\": {}\n}" } set { fields["mcp_servers"] = .string(newValue) } }
    public var includeAgentsMD: Bool { get { fields["include_agents_md"] != .bool(false) } set { fields["include_agents_md"] = .bool(newValue) } }
    public var fileStructure: [String: JSONValue] {
        get { if case .object(let settings) = fields["file_structure"] { settings } else { Self.defaultFileStructure } }
        set { fields["file_structure"] = .object(newValue) }
    }
    public var summary: ProjectSummary { ProjectSummary(name:name,title:title,description:description,color:color) }
    private func text(_ key: String) -> String { fields[key]?.string ?? "" }
    public static let defaultFileStructure: [String:JSONValue] = ["enabled":.bool(true), "max_depth":.number(5), "max_files":.number(20), "max_folders":.number(20), "max_lines":.number(250), "gitignore":.string("")]
}

public enum ProjectResult: Sendable, Equatable {
    case list([ProjectSummary]), document(ProjectDocument), deleted(String), activated, fileStructure(String)
}

public enum ProjectOperation: Sendable {
    case list, load(name: String), create(ProjectDocument), clone(ProjectDocument, gitToken: String)
    case update(ProjectDocument), delete(name: String), activate(name: String, context: String)
    case deactivate(context: String), fileStructure(name: String, settings: [String: JSONValue]?)
    public var mutates: Bool {
        switch self { case .list, .load, .fileStructure: false; default: true }
    }
    public var title: String {
        switch self {
        case .list: "Projects"; case .load: "Project settings"; case .create: "Create project"
        case .clone: "Clone repository"; case .update: "Save project"; case .delete: "Delete project"
        case .activate: "Assign project"; case .deactivate: "Remove project from chat"; case .fileStructure: "Project files"
        }
    }
    func payload() throws -> [String: JSONValue] {
        var result: [String:JSONValue] = [:]
        switch self {
        case .list: result["action"] = .string("list")
        case .load(let name), .delete(let name), .fileStructure(let name,_):
            try Self.validateName(name)
            let action = switch self { case .load: "load"; case .delete: "delete"; default: "file_structure" }
            result = ["action":.string(action), "name":.string(name)]
            if case .fileStructure(_,let settings) = self, let settings { result["settings"] = .object(settings) }
        case .create(let document), .update(let document), .clone(let document,_):
            try Self.validateName(document.name)
            var fields = document.fields
            fields.removeValue(forKey:"git_token")
            let action = switch self { case .create: "create"; case .update: "update"; default: "clone" }
            if case .clone(_,let token) = self {
                guard let url = URLComponents(string:document.gitURL), url.scheme?.lowercased() == "https",
                      let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
                      url.query == nil, url.fragment == nil else { throw ProjectError.invalidGitURL }
                fields["git_token"] = .string(token)
            }
            result = ["action":.string(action), "project":.object(fields)]
        case .activate(let name,let context):
            try Self.validateName(name)
            guard !context.isEmpty else { throw ClientError.incompatiblePayload }
            result = ["action":.string("activate"), "name":.string(name), "context_id":.string(context)]
        case .deactivate(let context):
            guard !context.isEmpty else { throw ClientError.incompatiblePayload }
            result = ["action":.string("deactivate"), "context_id":.string(context)]
        }
        return result
    }
    func result(_ data: Data) throws -> ProjectResult {
        guard data.count <= 2_097_152,
              let envelope = try? JSONDecoder().decode([String:JSONValue].self,from:data),
              case .bool(let ok) = envelope["ok"] else { throw ClientError.incompatiblePayload }
        guard ok else { throw ProjectError.serverRejected }
        guard let content = envelope["data"] else { throw ClientError.incompatiblePayload }
        switch self {
        case .list:
            guard case .array(let values) = content, values.count <= 10_000 else { throw ClientError.incompatiblePayload }
            let projects = try values.map { value -> ProjectSummary in
                guard let item = try? JSONDecoder().decode(ProjectSummary.self,from:JSONEncoder().encode(value)),
                      !item.name.isEmpty else { throw ClientError.incompatiblePayload }
                do { try Self.validateName(item.name) } catch { throw ClientError.incompatiblePayload }
                return item
            }
            guard Set(projects.map(\.name)).count == projects.count else { throw ClientError.incompatiblePayload }
            return .list(projects)
        case .load(let expected):
            let document = try Self.document(content)
            guard document.name == expected else { throw ClientError.incompatiblePayload }
            return .document(document)
        case .update(let expected):
            let document = try Self.document(content)
            guard document.name == expected.name else { throw ClientError.incompatiblePayload }
            return .document(document)
        case .create, .clone: return .document(try Self.document(content))
        case .delete(let expected):
            guard content == .string(expected) else { throw ClientError.incompatiblePayload }
            return .deleted(expected)
        case .activate, .deactivate:
            guard content == .null else { throw ClientError.incompatiblePayload }
            return .activated
        case .fileStructure:
            guard let text = content.string else { throw ClientError.incompatiblePayload }
            return .fileStructure(text)
        }
    }
    private static func document(_ content: JSONValue) throws -> ProjectDocument {
        guard case .object(let fields) = content, let name = fields["name"]?.string, !name.isEmpty else { throw ClientError.incompatiblePayload }
        do { try validateName(name) } catch { throw ClientError.incompatiblePayload }
        return ProjectDocument(fields:fields)
    }
    private static func validateName(_ name: String) throws {
        guard !name.isEmpty, name == name.trimmingCharacters(in:.whitespacesAndNewlines), name != ".", name != "..",
              !name.contains("/"), !name.contains("\\"), name.rangeOfCharacter(from:.controlCharacters) == nil else { throw ProjectError.invalidName }
    }
}

extension APIClient {
    /// Caller persists mutation intent before invocation. No project request is automatically retried.
    public func projects(_ operation: ProjectOperation) async throws -> ProjectResult {
        _ = try socketSession()
        let body = try JSONEncoder().encode(operation.payload())
        let response = try await request("/api/projects",method:"POST",body:body)
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response)
        return try operation.result(response.data)
    }
}
