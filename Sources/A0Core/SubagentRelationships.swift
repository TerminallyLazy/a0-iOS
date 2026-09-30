import Foundation

/// A read-only projection of explicit, available server child-chat relationships.
/// Agent numbers and names describe activity; they never establish navigation.
public struct SubagentRelationships: Sendable {
    public struct Conversation: Identifiable, Equatable, Sendable {
        public enum Status: Sendable { case working, paused, unspecified }
        public let id: String
        public let name: String
        public let profile: String?
        public let status: Status
    }
    private let conversations: [String: Conversation]
    private let parents: [String: String]
    private let childrenByParent: [String: [Conversation]]
    public var contextIDs: Set<String> { Set(conversations.keys) }

    public init(contexts: [[String: JSONValue]]) {
        guard contexts.count <= 4096 else { conversations = [:]; parents = [:]; childrenByParent = [:]; return }
        var counts: [String: Int] = [:]
        for row in contexts { if let id = Self.identifier(row["id"]) { counts[id, default:0] += 1 } }
        var nodes: [String: Conversation] = [:], edges: [String: String] = [:], order: [String] = []
        for row in contexts {
            guard let id = Self.identifier(row["id"]), counts[id] == 1, row["type"] != .string("background") else { continue }
            let name = Self.label(row["name"]) ?? Self.label(row["parent_context_label"]) ?? "Conversation"
            let status: Conversation.Status = row["paused"] == .bool(true) ? .paused : row["running"] == .bool(true) ? .working : .unspecified
            nodes[id] = Conversation(id:id, name:name, profile:Self.label(row["agent_profile_label"]), status:status)
            order.append(id)
            if row["parent_context_kind"] == .string("subordinate"), let parent = Self.identifier(row["parent_context_id"]), parent != id {
                edges[id] = parent
            }
        }
        // Reject ambiguous/missing destinations and every path entering a cycle.
        // A depth bound also prevents hostile collections doing unbounded graph work.
        var safeEdges: [String: String] = [:]
        for (child, parent) in edges where nodes[parent] != nil {
            var visited: Set<String> = [child], cursor = parent, safe = true
            for depth in 0..<64 {
                if !visited.insert(cursor).inserted { safe = false; break }
                guard let next = edges[cursor] else { break }
                if depth == 63 || nodes[next] == nil { safe = false; break }
                cursor = next
            }
            if safe { safeEdges[child] = parent }
        }
        var children: [String: [Conversation]] = [:]
        for id in order {
            if let parent = safeEdges[id], let child = nodes[id] { children[parent, default:[]].append(child) }
        }
        conversations = nodes; parents = safeEdges; childrenByParent = children
    }
    public func children(of parent: String) -> [Conversation] {
        childrenByParent[parent] ?? []
    }
    public func parent(of child: String) -> Conversation? { parents[child].flatMap { conversations[$0] } }
    public func conversation(_ id: String) -> Conversation? { conversations[id] }
    private static func identifier(_ value: JSONValue?) -> String? {
        guard let value = value?.string, !value.isEmpty, value.utf8.count <= 256,
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        return value
    }
    private static func label(_ value: JSONValue?) -> String? {
        guard let value = value?.string?.trimmingCharacters(in:.whitespacesAndNewlines), !value.isEmpty else { return nil }
        return String(value.prefix(160))
    }
}

/// Session-local discovery, reconciled only against fresh complete collections.
/// Baselines parents even when empty, so their first later child is discoverable.
public struct SubagentDiscovery: Sendable {
    private var scope: UUID?
    private var known: [String: Set<String>] = [:]
    private var unseen: [String: Set<String>] = [:]
    public init() {}
    public mutating func reconcile(_ relationships: SubagentRelationships, scope: UUID, fresh: Bool) {
        if self.scope != scope { self.scope = scope; known = [:]; unseen = [:] }
        guard fresh else { return }
        let parents = relationships.contextIDs
        known = known.filter { parents.contains($0.key) }
        unseen = unseen.filter { parents.contains($0.key) }
        for parent in parents {
            let children = Set(relationships.children(of:parent).map(\.id))
            if let previous = known[parent] {
                unseen[parent] = (unseen[parent] ?? []).intersection(children).union(children.subtracting(previous))
            }
            known[parent] = children
        }
    }
    public func newIDs(parent: String) -> Set<String> { unseen[parent] ?? [] }
    public mutating func acknowledge(child: String) {
        for parent in unseen.keys { unseen[parent]?.remove(child) }
    }
}
