import Foundation

public enum AgentControl: Sendable {
    case pause(Bool), nudge, history, context, stop
    public var mutates:Bool { switch self { case .pause,.nudge,.stop:true; default:false } }
    public var title:String {
        switch self { case .stop:"Stop agent and clear queue"; case .pause(let value): value ? "Pause agent" : "Resume agent"; case .nudge:"Nudge agent"; case .history:"History"; case .context:"Context" }
    }
    func request(context:String) throws -> (path:String,payload:[String:JSONValue]) {
        guard !context.isEmpty else { throw ClientError.incompatiblePayload }
        switch self {
        case .stop: return ("/api/stop",["context":.string(context)])
        case .pause(let value): return ("/api/pause",["context":.string(context),"paused":.bool(value)])
        case .nudge:return ("/api/nudge",["ctxid":.string(context)])
        case .history:return ("/api/history_get",["context":.string(context)])
        case .context:return ("/api/ctx_window_get",["context":.string(context)])
        }
    }
    func result(_ data:Data,context:String) throws -> AgentControlResult {
        guard data.count <= 2_097_152,
              let value = try? JSONDecoder().decode([String:JSONValue].self,from:data) else { throw ClientError.incompatiblePayload }
        switch self {
        case .stop:
            guard value["context"]?.string == context, case .bool = value["stopped"] else { throw ClientError.incompatiblePayload }
            return AgentControlResult(text:"Agent stopped. Queued follow-ups cleared.",tokens:nil)
        case .pause(let paused):
            guard value["pause"] == .bool(paused) else { throw ClientError.incompatiblePayload }
            return AgentControlResult(text:paused ? "Agent paused." : "Agent resumed.",tokens:nil)
        case .nudge:
            guard value["ctxid"]?.string == context else { throw ClientError.incompatiblePayload }
            return AgentControlResult(text:"Nudge acknowledged by server.",tokens:nil)
        case .history,.context:
            let key = if case .history = self { "history" } else { "content" }
            guard let text = value[key]?.string else { throw ClientError.incompatiblePayload }
            let tokens:Int? = if case .number(let n) = value["tokens"] { Int(exactly:n) } else { nil }
            return AgentControlResult(text:text,tokens:tokens)
        }
    }
}
public struct AgentControlResult: Sendable { public let text:String; public let tokens:Int? }
extension APIClient {
    public func perform(_ control:AgentControl,context:String) async throws -> AgentControlResult {
        _ = try socketSession()
        let operation = try control.request(context:context)
        var queueError: (any Error)?
        if case .stop = control {
            // Clear first so a delayed queue worker cannot restart the cancelled chat.
            // A failed clear must never prevent the cancellation attempt or be retried.
            do {
                let cleared = try await controlRequest("/api/message_queue_remove", payload:operation.payload)
                guard let value = try? JSONDecoder().decode([String:JSONValue].self,from:cleared.data),
                      value["ok"] == .bool(true), value["remaining"] == .number(0) else { throw ClientError.incompatiblePayload }
            } catch { queueError = error }
        }
        let response = try await controlRequest(operation.path,payload:operation.payload)
        let result = try control.result(response.data,context:context)
        if let queueError { throw queueError }
        return result
    }
    private func controlRequest(_ path:String,payload:[String:JSONValue]) async throws -> HTTPResponse {
        _ = try socketSession()
        let response = try await request(path,method:"POST",body:JSONEncoder().encode(payload))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response)
        return response
    }
}
