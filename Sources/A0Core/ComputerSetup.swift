import Foundation

public struct ComputerSetupStep: Decodable, Sendable, Identifiable {
    public let id:String
    public let state:String
    public let reason:String
    public let title:String
    public let detail:String
    public let action:String
    public let location:String
    public let helpID:String
    public let helpText:String?
    enum CodingKeys:String,CodingKey { case id,state,reason,title,detail,action,location; case helpID="help_id",helpText="help_text" }
}

public struct ComputerSetupSnapshot: Decodable, Sendable {
    public let version:Int
    public let serverID:String
    public let observedAt:Double
    public let hostLabel:String?
    public let hostID:String?
    public let connected:Bool
    public let steps:[ComputerSetupStep]
    public let platform:String
    enum CodingKeys:String,CodingKey { case version,connected,steps,platform; case serverID="server_id",observedAt="observed_at",hostLabel="host_label",hostID="host_id" }
    public init(data:Data) throws {
        guard data.count <= 65_536, let value = try? JSONDecoder().decode(Self.self,from:data),
              value.version == 1, Self.identity(value.serverID), value.observedAt.isFinite,
              value.hostLabel.map({ Self.text($0,limit:128) }) ?? true,
              value.hostID.map({ Self.text($0,limit:128) }) ?? true, Self.text(value.platform,limit:32),
              value.steps.count <= 8, Set(value.steps.map(\.id)).count == value.steps.count,
              value.steps.allSatisfy({ step in
                  ["connection","browser","computer_use","routing"].contains(step.id) &&
                  ["checking","ready","action_here","action_on_computer","unavailable","connection_lost"].contains(step.state) &&
                  Self.text(step.title,limit:128) && Self.text(step.detail,limit:512) &&
                  Self.text(step.action,limit:64) && Self.text(step.reason,limit:64) && Self.text(step.helpID,limit:64)
                  && ["here","computer"].contains(step.location) && (step.helpText.map({ Self.text($0,limit:2048) }) ?? true)
              }) else { throw ClientError.incompatiblePayload }
        self=value
    }
    static func identity(_ text:String) -> Bool { text.count == 32 && text.allSatisfy { "0123456789abcdef".contains($0) } }
    static func text(_ value:String,limit:Int) -> Bool { value.count <= limit && !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } }
}

public struct ComputerSetupContinuation: Decodable, Sendable {
    public let version:Int
    public let requestID:String
    public let serverID:String
    public let code:String
    public let expiresAt:Double
    public let state:String
    public let capabilities:[String]
    public let hostID:String?
    public let hostLabel:String?
    enum CodingKeys:String,CodingKey { case version,code,state,capabilities; case requestID="request_id",serverID="server_id",expiresAt="expires_at",hostID="host_id",hostLabel="host_label" }
    public init(data:Data,requestID:String) throws {
        guard data.count <= 65_536, let value=try? JSONDecoder().decode(Self.self,from:data),
              value.version == 1, value.requestID == requestID, UUID(uuidString:requestID) != nil,
              ComputerSetupSnapshot.identity(value.serverID), value.expiresAt.isFinite,
              value.code.count == 14, value.code.allSatisfy({ "ABCDEFGHJKLMNPQRSTUVWXYZ23456789-".contains($0) }),
              ["waiting","claimed","confirmed","cancelled"].contains(value.state),
              !value.capabilities.isEmpty, value.capabilities.count <= 2, Set(value.capabilities).count == value.capabilities.count, value.capabilities.allSatisfy({ ["browser","computer_use"].contains($0) }),
              value.hostID.map({ ComputerSetupSnapshot.text($0,limit:128) }) ?? true,
              value.hostLabel.map({ ComputerSetupSnapshot.text($0,limit:128) }) ?? true else { throw ClientError.incompatiblePayload }
        self=value
    }
}

extension APIClient {
    public func computerSetup() async throws -> ComputerSetupSnapshot {
        try ComputerSetupSnapshot(data:await computerSetupRequest(["action":.string("status")]))
    }
    public func computerSetupContinuation(action:String,requestID:String,capabilities:[String] = []) async throws -> ComputerSetupContinuation {
        guard ["create","read","confirm","cancel"].contains(action), UUID(uuidString:requestID) != nil else { throw ClientError.incompatiblePayload }
        var payload:[String:JSONValue] = ["action":.string(action),"request_id":.string(requestID)]
        if action == "create" {
            guard !capabilities.isEmpty,capabilities.count <= 2,capabilities.allSatisfy({ ["browser","computer_use"].contains($0) }) else { throw ClientError.incompatiblePayload }
            payload["capabilities"] = .array(capabilities.map(JSONValue.string))
        }
        return try ComputerSetupContinuation(data:await computerSetupRequest(payload),requestID:requestID)
    }
    private func computerSetupRequest(_ payload:[String:JSONValue]) async throws -> Data {
        let session=try socketSession()
        var request=URLRequest(url:session.origin.url.appendingPathComponent("api/plugins/_a0_connector/v1/host_setup"),cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:15)
        request.httpMethod="POST";request.httpBody=try JSONEncoder().encode(payload)
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        request.setValue(session.origin.header,forHTTPHeaderField:"Origin")
        request.setValue(session.cookieHeader,forHTTPHeaderField:"Cookie")
        request.setValue(session.csrfToken,forHTTPHeaderField:"X-CSRF-Token")
        let response=try await boundedImageRequest(request,maximumBytes:65_536)
        guard try socketSession().runtimeID == session.runtimeID else { throw ClientError.disconnected }
        if isLoginRedirect(response) || response.status == 401 { throw ClientError.requiresLogin }
        if response.status == 403 { throw ClientError.csrfRejected }
        try validate(response)
        return response.data
    }
}
