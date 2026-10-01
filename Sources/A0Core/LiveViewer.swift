import Foundation

/// One capture collection per conversation. Evidence remains on the server.
public struct ConversationCaptures: Sendable {
    public let history: [BrowserScreenshot]
    public init(logs: [LogEntry], context: String) {
        var seen = Set<String>()
        history = logs.reversed().compactMap { BrowserScreenshot.extract($0,context:context) }
            .filter { seen.insert($0.id).inserted }.prefix(100).map { $0 }
    }
    public func latest(source: String) -> BrowserScreenshot? { history.first { $0.source == source } }
}

public struct LiveFrame: Sendable, Equatable {
    public let id: String
    public let source: String
    public let width: Int
    public let height: Int
    public let data: Data
    public let capturedAt: Date
    public let scope: String
    public init(_ value: [String:JSONValue]) throws {
        guard let id = value["id"]?.string, id.count == 32,
              let source = value["source"]?.string, ["browser","computer_use"].contains(source),
              case .number(let width) = value["width"], case .number(let height) = value["height"],
              width >= 1, height >= 1, width <= 1600, height <= 1200, width.rounded() == width, height.rounded() == height,
              value["mime"] == .string("image/jpeg"), let encoded = value["data"]?.string, encoded.utf8.count <= 2_000_000,
              let data = Data(base64Encoded:encoded), data.count <= 1_500_000, data.starts(with:[0xff,0xd8,0xff]),
              case .number(let captured) = value["captured_at"], captured.isFinite, captured > 0,
              let scope = value["scope"]?.string, scope == (source == "browser" ? "tab":"display") else { throw ClientError.incompatiblePayload }
        self.id = id; self.source = source; self.width = Int(width); self.height = Int(height)
        self.data = data; capturedAt = Date(timeIntervalSince1970:captured); self.scope = scope
    }
}

public struct LiveViewerStatus: Sendable {
    public let supported: Bool
    public let phase: String
    public let mine: Bool
    public let recoverable: Bool
    public let sequence: Int
    public let hostLabel: String
    public init(_ value: [String:JSONValue]) throws {
        guard case .bool(let supported) = value["supported"],
              let phase = value["phase"]?.string, ["watching","requesting","human","held","returning"].contains(phase),
              case .bool(let mine) = value["mine"], case .bool(let recoverable) = value["recoverable"],
              case .number(let sequence) = value["sequence"], sequence >= 0, sequence <= 1_000_000,
              sequence.rounded() == sequence, let label = value["host_label"]?.string, label.count <= 128 else { throw ClientError.incompatiblePayload }
        self.supported = supported; self.phase = phase; self.mine = mine; self.recoverable = recoverable
        self.sequence = Int(sequence); hostLabel = label
    }
    public var controlling: Bool { supported && phase == "human" && mine }
}

public struct LiveViewerError: Error, LocalizedError, Sendable {
    public let message: String
    public var errorDescription: String? { message }
}

extension APIClient {
    /// Bounded, authenticated and non-retrying. Caller journals each mutation first.
    public func hostViewer(context: String, viewer: String, command: String, source: String,
                           fields: [String:JSONValue] = [:]) async throws -> [String:JSONValue] {
        guard !context.isEmpty, context.count <= 128, viewer.count == 32,
              ["status","frame","acquire","input","return","hold","heartbeat"].contains(command),
              ["browser","computer_use"].contains(source), Set(fields.keys).isSubset(of:["request_id","sequence","frame","input"]) else { throw ClientError.incompatiblePayload }
        let session = try socketSession()
        var payload = fields
        payload.merge(["context":.string(context),"viewer":.string(viewer),"command":.string(command),"source":.string(source)]) { _,new in new }
        var request = URLRequest(url:session.origin.url.appendingPathComponent("api/plugins/_a0_connector/v1/host_viewer"),cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:27)
        request.httpMethod = "POST"; request.httpBody = try JSONEncoder().encode(payload)
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        request.setValue(session.origin.header,forHTTPHeaderField:"Origin")
        request.setValue(session.cookieHeader,forHTTPHeaderField:"Cookie")
        request.setValue(session.csrfToken,forHTTPHeaderField:"X-CSRF-Token")
        let response = try await boundedImageRequest(request,maximumBytes:command == "frame" ? 2_100_000:65_536)
        let current = try socketSession()
        // boundedImageRequest already fences authentication changes. Routine cookie
        // refreshes within the same authenticated runtime must not discard an ack.
        guard current.runtimeID == session.runtimeID else { throw ClientError.disconnected }
        if isLoginRedirect(response) || response.status == 401 { throw ClientError.requiresLogin }
        if response.status == 403 { throw ClientError.csrfRejected }
        if response.status == 409, response.data.count <= 512, let message = String(data:response.data,encoding:.utf8) {
            throw LiveViewerError(message:message)
        }
        try validate(response)
        guard let result = try? JSONDecoder().decode([String:JSONValue].self,from:response.data),
              result["version"] == .number(1),result["context"] == .string(context) else { throw ClientError.incompatiblePayload }
        if let receipt = fields["request_id"], result["request_id"] != receipt { throw ClientError.incompatiblePayload }
        return result
    }
}
