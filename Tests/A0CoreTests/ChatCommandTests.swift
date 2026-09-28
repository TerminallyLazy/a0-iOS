import Foundation
import Testing
@testable import A0Core

private func jsonResponse(_ text: String, status: Int = 200) -> HTTPResponse {
    HTTPResponse(data: Data(text.utf8), status: status, headers: ["Content-Type": "application/json"])
}
private func signedIn(_ responses: [HTTPResponse]) async throws -> (APIClient, ScriptTransport) {
    let transport = ScriptTransport(loginResponses() + responses)
    let client = APIClient(origin: try ServerOrigin("https://server.test"), transport: transport)
    try await client.connect(username: "fixture", password: "fixture")
    return (client, transport)
}
@Test func createChatUsesRequestedIdentityAndCSRF() async throws {
    let (client, transport) = try await signedIn([jsonResponse(#"{"ok":true,"ctxid":"new-chat"}"#)])
    #expect(try await client.createChat(id: "new-chat") == "new-chat")
    let request = try #require(await transport.requests.last)
    #expect(request.url?.path == "/api/chat_create")
    #expect(request.value(forHTTPHeaderField: "X-CSRF-Token") == "synthetic-csrf")
    let body = try #require(request.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(payload["new_context"] == "new-chat")
    #expect(payload["current_context"] == "")
}
@Test func directSendUsesFrozenContextAndMessageID() async throws {
    let (client, transport) = try await signedIn([jsonResponse(#"{"context":"chat-a","message":"Message received."}"#)])
    try await client.sendText(context: "chat-a", text: "Synthetic message", messageID: "message-a", queued: false)
    let request = try #require(await transport.requests.last)
    #expect(request.url?.path == "/api/message_async")
    let body = try #require(request.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(payload == ["context":"chat-a", "text":"Synthetic message", "message_id":"message-a"])
}
@Test func busySendUsesQueueEndpointAndItemID() async throws {
    let (client, transport) = try await signedIn([jsonResponse(#"{"ok":true,"item_id":"message-a","queue_length":1}"#)])
    try await client.sendText(context: "chat-a", text: "Synthetic message", messageID: "message-a", queued: true)
    let request = try #require(await transport.requests.last)
    #expect(request.url?.path == "/api/message_queue_add")
    let body = try #require(request.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(payload["item_id"] == "message-a")
    #expect(payload["message_id"] == nil)
}
@Test(arguments: [400, 403, 500]) func rejectedSendIsNotReplayed(status: Int) async throws {
    let (client, transport) = try await signedIn([jsonResponse("{}", status: status)])
    await #expect(throws: (any Error).self) {
        try await client.sendText(context: "chat-a", text: "Synthetic", messageID: "m", queued: false)
    }
    #expect(await transport.requests.count == 4)
}
@Test func responseForDifferentContextCannotConfirmSend() async throws {
    let (client, _) = try await signedIn([jsonResponse(#"{"context":"wrong-chat"}"#)])
    await #expect(throws: ClientError.incompatiblePayload) {
        try await client.sendText(context: "chat-a", text: "Synthetic", messageID: "m", queued: false)
    }
}
@Test func differentQueueIDCannotConfirmSend() async throws {
    let (client, _) = try await signedIn([jsonResponse(#"{"ok":true,"item_id":"wrong-id"}"#)])
    await #expect(throws: ClientError.incompatiblePayload) {
        try await client.sendText(context: "chat-a", text: "Synthetic", messageID: "m", queued: true)
    }
}
@Test func differentCreatedContextCannotBeUsed() async throws {
    let (client, _) = try await signedIn([jsonResponse(#"{"ok":true,"ctxid":"wrong-context"}"#)])
    await #expect(throws: ClientError.incompatiblePayload) { try await client.createChat(id:"new-chat") }
}
