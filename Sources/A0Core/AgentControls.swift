import Foundation

public enum AgentControl: Sendable {
    case pause(Bool), nudge, history, context
    public var mutates:Bool { switch self { case .pause,.nudge:true; default:false } }
    public var title:String {
        switch self { case .pause(let value): value ? "Pause agent" : "Resume agent"; case .nudge:"Nudge agent"; case .history:"History"; case .context:"Context" }
    }
    func request(context:String) throws -> (path:String,payload:[String:JSONValue]) {
        guard !context.isEmpty else { throw ClientError.incompatiblePayload }
        switch self {
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
        let response = try await request(operation.path,method:"POST",body:JSONEncoder().encode(operation.payload))
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response)
        return try control.result(response.data,context:context)
    }
}
