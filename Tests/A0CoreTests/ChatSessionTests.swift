import Foundation
import Testing
@testable import A0Core

actor ChatDouble: ChatAPI {
    enum Mode { case success, timeout, denied, createTimeout, held, heldTimeout }
    enum Call: Equatable { case create(String), send(String, String, String, Bool) }
    var mode: Mode
    var calls: [Call] = []
    private var held: CheckedContinuation<Void, Never>?
    private var observers: [CheckedContinuation<Void, Never>] = []
    init(_ mode: Mode = .success) { self.mode = mode }
    func createChat(id: String) async throws -> String {
        calls.append(.create(id))
        if mode == .createTimeout { throw URLError(.timedOut) }
        return id
    }
    func sendText(context: String, text: String, messageID: String, queued: Bool) async throws {
        calls.append(.send(context,text,messageID,queued))
        if mode == .timeout { throw URLError(.timedOut) }
        if mode == .denied { throw ClientError.httpStatus(400) }
        if mode == .held || mode == .heldTimeout {
            await withCheckedContinuation { continuation in
                held = continuation
                for observer in observers { observer.resume() }; observers = []
            }
            if mode == .heldTimeout { throw URLError(.timedOut) }
        }
    }
    func waitForSend() async {
        if held != nil { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func release() { held?.resume(); held = nil }
    func succeed() { mode = .success }
}

@MainActor @Test func sendingFromNewChatCreatesBeforeSubmitting() async throws {
    let api = ChatDouble(); let model = ChatSession(api: api)
    model.draft = "Hello from a synthetic test"
    await model.send()
    let delivery = try #require(model.deliveries.first)
    #expect(await api.calls == [.create(delivery.context), .send(delivery.context, delivery.text, delivery.id, false)])
    #expect(model.selectedContext == delivery.context)
    #expect(delivery.status == .accepted)
    #expect(model.draft.isEmpty)
}
@MainActor @Test func emptyDraftDoesNotCreateOrSend() async {
    let api = ChatDouble(); let model = ChatSession(api: api)
    model.draft = " \n "
    await model.send()
    #expect(await api.calls.isEmpty)
    #expect(model.deliveries.isEmpty)
}
@MainActor @Test(arguments: [(true,false), (false,true)])
func busyOrQueuedChatEnqueues(flags: (Bool,Bool)) async throws {
    let api = ChatDouble(); let model = ChatSession(api: api)
    model.select("chat-a"); model.draft = "Queue this"
    await model.send(isBusy: flags.0, hasQueue: flags.1)
    let delivery = try #require(model.deliveries.first)
    #expect(delivery.status == .queued)
    #expect(await api.calls == [.send("chat-a", "Queue this", delivery.id, true)])
}
@MainActor @Test func timeoutPreservesDraftAndPreventsSilentReplay() async throws {
    let api = ChatDouble(.timeout); let model = ChatSession(api: api)
    model.select("chat-a"); model.draft = "Do it once"
    await model.send(); await model.send()
    #expect(model.draft == "Do it once")
    #expect(model.deliveries.first?.status == .uncertain)
    #expect(await api.calls.count == 1)
    #expect(model.canSend == false)
}
@MainActor @Test func definitiveRejectionKeepsDraftAndAllowsExplicitRetry() async throws {
    let api = ChatDouble(.denied); let model = ChatSession(api: api)
    model.select("chat-a"); model.draft = "Fix and retry"
    await model.send()
    #expect(model.deliveries.first?.status == .failed)
    #expect(model.draft == "Fix and retry")
    await api.succeed(); await model.send()
    #expect(await api.calls.count == 2)
    #expect(model.deliveries.last?.status == .accepted)
}
@MainActor @Test func switchingChatsDuringSendCannotEraseAnotherDraft() async {
    let api = ChatDouble(.held); let model = ChatSession(api: api)
    model.select("chat-a"); model.draft = "First"
    let send = Task { await model.send() }
    await api.waitForSend()
    model.select("chat-b"); model.draft = "Second"
    await api.release(); await send.value
    #expect(model.selectedContext == "chat-b")
    #expect(model.draft == "Second")
    model.select("chat-a"); #expect(model.draft.isEmpty)
}
@MainActor @Test func editsDuringSendRemainDraftsAndDoubleTapDoesNotResubmit() async {
    let api = ChatDouble(.held); let model = ChatSession(api: api)
    model.select("chat-a"); model.draft = "First"
    let send = Task { await model.send() }
    await api.waitForSend()
    model.draft = "Next message"
    await model.send()
    await api.release(); await send.value
    #expect(model.draft == "Next message")
    #expect(await api.calls.count == 1)
}
@MainActor @Test func serverReceiptResolvesUncertainSendOnlyInMatchingContext() async throws {
    let api = ChatDouble(.timeout); let model = ChatSession(api: api)
    model.select("synthetic-chat"); model.draft = "Uncertain text"
    await model.send()
    let delivery = try #require(model.deliveries.first)
    let text = String(decoding: try fixture("full"),as:UTF8.self).replacingOccurrences(of:"synthetic-user",with:delivery.id)
    let wrong = text.replacingOccurrences(of:"synthetic-chat",with:"wrong-chat")
    model.reconcile(try JSONDecoder().decode(Snapshot.self,from:Data(wrong.utf8)))
    #expect(model.deliveries.first?.status == .uncertain)
    model.reconcile(try JSONDecoder().decode(Snapshot.self,from:Data(text.utf8)))
    #expect(model.deliveries.first?.status == .accepted)
    #expect(model.deliveries.first?.confirmed == true)
    #expect(model.draft.isEmpty)
    #expect(await api.calls.count == 1)
}
@MainActor @Test func uncertainCreationNeverSendsBeforeCreationIsConfirmed() async throws {
    let api = ChatDouble(.createTimeout); let model = ChatSession(api: api)
    model.draft = "Not yet sent"
    await model.send(); await model.send()
    let delivery = try #require(model.deliveries.first)
    #expect(await api.calls == [.create(delivery.context)])
    #expect(delivery.status == .uncertain)
    let text = String(decoding:try fixture("full"),as:UTF8.self).replacingOccurrences(of:"synthetic-chat",with:delivery.context)
    model.reconcile(try JSONDecoder().decode(Snapshot.self,from:Data(text.utf8)))
    #expect(model.deliveries.first?.status == .failed)
    #expect(model.selectedContext == delivery.context)
    #expect(model.draft == "Not yet sent")
    #expect(await api.calls.count == 1)
}
@MainActor @Test func disconnectInvalidatesInFlightCompletionWithoutLosingDraft() async {
    let api = ChatDouble(.held); let model = ChatSession(api: api)
    model.select("chat-a"); model.draft = "Keep me"
    let send = Task { await model.send() }
    await api.waitForSend(); model.suspend()
    await api.release(); await send.value
    #expect(model.draft == "Keep me")
    #expect(model.deliveries.first?.status == .uncertain)
}

@MainActor @Test func queuedReceiptResolvesTimeoutBeforeExecution() async throws {
    let api = ChatDouble(.timeout); let model = ChatSession(api: api)
    model.select("synthetic-chat"); model.draft = "Wait in queue"
    await model.send(isBusy: true)
    let id = try #require(model.deliveries.first?.id)
    var json = try #require(JSONSerialization.jsonObject(with: fixture("full")) as? [String: Any])
    json["contexts"] = [["id": "synthetic-chat", "message_queue": [["id": id, "text": "Wait in queue"]]]]
    let snapshot = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: json))
    model.reconcile(snapshot)
    #expect(model.deliveries.first?.status == .queued)
    #expect(model.draft.isEmpty)
    #expect(await api.calls.count == 1)
}
@MainActor @Test func reconnectDoesNotReplayUncertainMutation() async {
    let old = ChatDouble(.timeout), fresh = ChatDouble()
    let model = ChatSession(api: old)
    model.select("a"); model.draft = "Keep across reconnect"
    await model.send(); model.suspend(); model.resume(api: fresh)
    await model.send()
    #expect(await fresh.calls.isEmpty)
    #expect(model.draft == "Keep across reconnect")
}

@MainActor @Test func executionReceiptBeforeQueueAcknowledgmentStaysAccepted() async throws {
    let api = ChatDouble(.held); let model = ChatSession(api: api)
    model.select("synthetic-chat"); model.draft = "Rapid queue processing"
    let send = Task { await model.send(isBusy: true) }
    await api.waitForSend()
    let id = try #require(model.deliveries.first?.id)
    let text = String(decoding: try fixture("full"), as: UTF8.self).replacingOccurrences(of: "synthetic-user", with: id)
    model.reconcile(try JSONDecoder().decode(Snapshot.self, from: Data(text.utf8)))
    await api.release(); await send.value
    #expect(model.deliveries.first?.status == .accepted)
    #expect(model.deliveries.first?.confirmed == true)
}

@MainActor @Test func queueReceiptBeforeTimeoutStaysQueued() async throws {
    let api = ChatDouble(.heldTimeout); let model = ChatSession(api: api)
    model.select("synthetic-chat"); model.draft = "Queue with lost ack"
    let send = Task { await model.send(isBusy: true) }
    await api.waitForSend()
    let id = try #require(model.deliveries.first?.id)
    var json = try #require(JSONSerialization.jsonObject(with: fixture("full")) as? [String: Any])
    json["contexts"] = [["id": "synthetic-chat", "message_queue": [["id": id]]]]
    model.reconcile(try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: json)))
    await api.release(); await send.value
    #expect(model.deliveries.first?.status == .queued)
    #expect(model.draft.isEmpty)
}

@MainActor @Test func repeatedOldReceiptCannotEraseANewIdenticalDraft() async throws {
    let api = ChatDouble(); let model = ChatSession(api: api)
    model.select("synthetic-chat"); model.draft = "Repeat intentionally"
    await model.send()
    let id = try #require(model.deliveries.first?.id)
    model.draft = "Repeat intentionally"
    let text = String(decoding: try fixture("full"), as: UTF8.self).replacingOccurrences(of: "synthetic-user", with: id)
    let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(text.utf8))
    model.reconcile(snapshot); model.reconcile(snapshot)
    #expect(model.draft == "Repeat intentionally")
}

@MainActor @Test func uncertainCreationIsVisibleBeforeContextSelection() async {
    let model = ChatSession(api: ChatDouble(.createTimeout))
    model.draft = "Creation pending"
    await model.send()
    #expect(model.selectedContext == nil)
    #expect(model.visibleDeliveries.count == 1)
    #expect(model.visibleDeliveries.first?.status == .uncertain)
    model.select("other-chat")
    #expect(model.visibleDeliveries.isEmpty)
}
