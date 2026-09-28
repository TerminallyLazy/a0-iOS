import Foundation

public enum JSONValue: Codable, Sendable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
    public var string: String? { if case .string(let s) = self { s } else { nil } }
}

public struct LogEntry: Codable, Sendable, Equatable, Identifiable {
    public let no: Int
    public let id: String?
    public let type: String
    public let heading: String?
    public let content: String?
    public let kvps: [String: JSONValue]?
    public let timestamp: JSONValue?
    public let agentno: Int?
}

public struct Snapshot: Codable, Sendable, Equatable {
    public let deselectChat: Bool
    public let context: String
    public let contexts: [[String: JSONValue]]?
    public let tasks: [[String: JSONValue]]?
    public let logs: [LogEntry]
    public let logGUID: String
    public let logVersion: Int
    public let logProgress: JSONValue
    public let logProgressActive: Bool
    public let paused: Bool
    public let notifications: [[String: JSONValue]]
    public let notificationsGUID: String
    public let notificationsVersion: Int
    enum CodingKeys: String, CodingKey {
        case context, contexts, tasks, logs, paused, notifications
        case deselectChat = "deselect_chat", logGUID = "log_guid", logVersion = "log_version"
        case logProgress = "log_progress", logProgressActive = "log_progress_active"
        case notificationsGUID = "notifications_guid", notificationsVersion = "notifications_version"
    }
}

public struct StateRequest: Codable, Sendable, Equatable {
    public let context: String?
    public let logFrom: Int
    public let notificationsFrom: Int
    public let timezone: String
    public let collectionsDelta: Bool
    public init(context: String? = nil, logFrom: Int = 0, notificationsFrom: Int = 0,
                timezone: String = TimeZone.current.identifier, collectionsDelta: Bool = true) {
        self.context = context; self.logFrom = logFrom; self.notificationsFrom = notificationsFrom
        self.timezone = timezone; self.collectionsDelta = collectionsDelta
    }
    enum CodingKeys: String, CodingKey {
        case context, timezone
        case logFrom = "log_from", notificationsFrom = "notifications_from", collectionsDelta = "collections_delta"
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(context, forKey: .context)
        try c.encode(logFrom, forKey: .logFrom)
        try c.encode(notificationsFrom, forKey: .notificationsFrom)
        try c.encode(timezone, forKey: .timezone)
        try c.encode(collectionsDelta, forKey: .collectionsDelta)
    }
}

public struct StatePush: Decodable, Sendable {
    public struct Payload: Decodable, Sendable {
        public let runtimeEpoch: String
        public let seq: Int
        public let snapshot: Snapshot
        enum CodingKeys: String, CodingKey { case runtimeEpoch = "runtime_epoch", seq, snapshot }
    }
    public let data: Payload
}

public struct HandshakeAck: Decodable, Sendable {
    public struct Result: Decodable, Sendable {
        public let handlerId: String
        public let ok: Bool
        public let data: JSONValue?
        public let error: JSONValue?
    }
    public let correlationId: String
    public let results: [Result]
    public func validated(correlationID: String) throws -> (epoch: String, sequenceBase: Int) {
        guard correlationId == correlationID,
              let result = results.first(where: { ["ws_webui.WsWebui", "api.ws_webui.WsWebui"].contains($0.handlerId) }), result.ok,
              case .object(let data) = result.data,
              let epoch = data["runtime_epoch"]?.string, !epoch.isEmpty,
              case .number(let seq) = data["seq_base"], let sequence = Int(exactly: seq), sequence >= 0,
              data["code"] == nil, result.error == nil else { throw ClientError.invalidHandshake }
        return (epoch, sequence)
    }
}
