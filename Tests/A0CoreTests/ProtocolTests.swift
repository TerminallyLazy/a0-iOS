import Foundation
import Testing
@testable import A0Core

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}
func snapshot(_ name: String = "full") throws -> Snapshot { try JSONDecoder().decode(Snapshot.self, from: fixture(name)) }

@Test func stateRequestUsesWireCursorsNotForceFull() throws {
    let data = try JSONEncoder().encode(StateRequest(timezone: "UTC"))
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["forceFull"] == nil)
    #expect(json["context"] is NSNull)
    #expect(json["log_from"] as? Int == 0)
    #expect(json["notifications_from"] as? Int == 0)
}
@Test func incrementalStreamReplacesByNumberAndRetainsNullCollections() throws {
    var reducer = SyncReducer(); let generation = reducer.select(context: "synthetic-chat")
    #expect(reducer.apply(snapshot: try snapshot(), generation: generation, full: true) == .applied)
    #expect(reducer.apply(snapshot: try snapshot("delta"), generation: generation, full: false) == .applied)
    #expect(reducer.logs.count == 2)
    #expect(reducer.logs.last?.content == "Completed synthetic response")
    #expect(reducer.contexts.count == 1)
    #expect(reducer.notifications.count == 1)
    #expect(reducer.notifications.first?["read"] == .bool(true))
}
@Test func pollingAndPushProduceSameState() throws {
    var poll = SyncReducer(); let pg = poll.select(context: "synthetic-chat")
    var push = SyncReducer(); let sg = push.select(context: "synthetic-chat")
    push.beginHandshake(epoch: "synthetic-runtime", sequenceBase: 1)
    for (index, name) in ["full", "delta"].enumerated() {
        let data = try fixture(name)
        let payload = "{\"data\":{\"runtime_epoch\":\"synthetic-runtime\",\"seq\":\(index + 2),\"snapshot\":\(String(decoding: data, as: UTF8.self))}}"
        let event = try JSONDecoder().decode(StatePush.self, from: Data(payload.utf8))
        #expect(push.apply(push: event, generation: sg) == .applied)
        #expect(poll.apply(snapshot: try snapshot(name), generation: pg, full: index == 0) == .applied)
    }
    #expect(push.logs == poll.logs)
    #expect(push.contexts == poll.contexts)
    #expect(push.notifications == poll.notifications)
    #expect(push.request == poll.request)
}
@Test func staleGenerationCannotChangeSelection() throws {
    var reducer = SyncReducer(); let stale = reducer.select(context: "synthetic-chat")
    reducer.select(context: "other-chat")
    #expect(reducer.apply(snapshot: try snapshot(), generation: stale, full: true) == .ignored)
    #expect(reducer.logs.isEmpty)
    #expect(reducer.context == "other-chat")
}
@Test func guidResetRequiresFullSnapshot() throws {
    var reducer = SyncReducer(); let generation = reducer.select(context: "synthetic-chat")
    _ = reducer.apply(snapshot: try snapshot(), generation: generation, full: true)
    let changed = String(decoding: try fixture("delta"), as: UTF8.self).replacingOccurrences(of: "synthetic-log", with: "reset-log")
    let reset = try JSONDecoder().decode(Snapshot.self, from: Data(changed.utf8))
    #expect(reducer.apply(snapshot: reset, generation: generation, full: false) == .needsFullSync)
    #expect(reducer.request.logFrom == 0)
    #expect(reducer.logs.last?.content == "Working")
}
@Test(arguments: ["wrong-runtime", "synthetic-runtime"])
func runtimeChangeOrSequenceGapRequiresResync(epoch: String) throws {
    var reducer = SyncReducer(); let generation = reducer.select(context: "synthetic-chat")
    reducer.beginHandshake(epoch: "synthetic-runtime", sequenceBase: 1)
    let payload = "{\"data\":{\"runtime_epoch\":\"\(epoch)\",\"seq\":99,\"snapshot\":\(String(decoding: try fixture("full"), as: UTF8.self))}}"
    let push = try JSONDecoder().decode(StatePush.self, from: Data(payload.utf8))
    #expect(reducer.apply(push: push, generation: generation) == .needsFullSync)
    #expect(reducer.logs.isEmpty)
}
@Test func emptyCollectionsClearWhileUnknownLogTypeSurvives() throws {
    let text = String(decoding: try fixture("delta"), as: UTF8.self).replacingOccurrences(of: "\"contexts\": null", with: "\"contexts\": []").replacingOccurrences(of: "\"response\"", with: "\"future-plugin-type\"")
    var reducer = SyncReducer(); let generation = reducer.select(context: "synthetic-chat")
    _ = reducer.apply(snapshot: try snapshot(), generation: generation, full: true)
    _ = reducer.apply(snapshot: try JSONDecoder().decode(Snapshot.self, from: Data(text.utf8)), generation: generation, full: false)
    #expect(reducer.contexts.isEmpty)
    #expect(reducer.logs.last?.type == "future-plugin-type")
}
@Test func handshakeRequiresMatchingHandlerAndCorrelation() throws {
    let data = Data(#"{"correlationId":"request-1","results":[{"handlerId":"ws_webui.WsWebui","ok":true,"data":{"runtime_epoch":"runtime","seq_base":1}}]}"#.utf8)
    let ack = try JSONDecoder().decode(HandshakeAck.self, from: data)
    #expect(try ack.validated(correlationID: "request-1").sequenceBase == 1)
    #expect(throws: ClientError.invalidHandshake) { try ack.validated(correlationID: "old-request") }
}
@Test func applicationErrorInsideSuccessfulAckIsRejected() throws {
    let data = Data(#"{"correlationId":"request-1","results":[{"handlerId":"ws_webui.WsWebui","ok":true,"data":{"code":"INVALID_REQUEST"}}]}"#.utf8)
    let ack = try JSONDecoder().decode(HandshakeAck.self, from: data)
    #expect(throws: ClientError.invalidHandshake) { try ack.validated(correlationID: "request-1") }
}
