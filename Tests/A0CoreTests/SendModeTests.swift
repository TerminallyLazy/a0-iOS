import Foundation
import Testing
@testable import A0Core

@Test func sendModeDefaultsToQueueForMissingOrUnknownPreference() {
    #expect(SendMode(preference: nil) == .queue)
    #expect(SendMode(preference: "future-value") == .queue)
    #expect(SendMode(preference: "steer") == .steer)
}

@Test(arguments: [(false,false), (true,false), (false,true), (true,true)])
func sendModeRoutesBusyAndQueuedConversations(flags: (Bool,Bool)) {
    #expect(SendMode.queue.shouldQueue(isBusy: flags.0, hasQueue: flags.1) == (flags.0 || flags.1))
    #expect(!SendMode.steer.shouldQueue(isBusy: flags.0, hasQueue: flags.1))
}

@MainActor @Test func steerSendsImmediatelyEvenWhenBusyWithExistingQueue() async throws {
    let api = ChatDouble(), chat = ChatSession(api: ChatDouble())
    chat.resume(api: api); chat.select("busy-chat"); chat.draft = "Change direction"
    await chat.send(mode: .steer, isBusy: true, hasQueue: true)
    let delivery = try #require(chat.deliveries.first)
    #expect(await api.calls == [.send("busy-chat", "Change direction", delivery.id, false)])
    #expect(delivery.status == .accepted)
}

@MainActor @Test func queueAllowsAnotherMessageAfterAcknowledgmentWhileAgentStillWorks() async throws {
    let api = ChatDouble(), chat = ChatSession(api: ChatDouble())
    chat.resume(api: api); chat.select("busy-chat")
    chat.draft = "First follow-up"; await chat.send(mode: .queue, isBusy: true)
    chat.draft = "Second follow-up"; await chat.send(mode: .queue, isBusy: true, hasQueue: true)
    #expect(await api.calls.count == 2)
    #expect(chat.deliveries.count == 2)
    #expect(chat.deliveries.allSatisfy { $0.status == .queued })
}

@MainActor @Test func changingModeDoesNotReplayUncertainMessage() async {
    let api = ChatDouble(.timeout), chat = ChatSession(api: ChatDouble())
    chat.resume(api: api); chat.select("busy-chat"); chat.draft = "Exactly once"
    await chat.send(mode: .queue, isBusy: true)
    await chat.send(mode: .steer, isBusy: true)
    #expect(await api.calls.count == 1)
    #expect(chat.deliveries.first?.status == .uncertain)
    #expect(!chat.canSend)
}

@MainActor @Test func newChatSendsDirectlyEvenWithQueueModeAndStaleBusyHint() async throws {
    let api = ChatDouble(), chat = ChatSession(api: ChatDouble())
    chat.resume(api: api); chat.draft = "Fresh chat"
    await chat.send(mode: .queue, isBusy: true, hasQueue: true)
    let delivery = try #require(chat.deliveries.first)
    #expect(await api.calls == [.create(delivery.context), .send(delivery.context, "Fresh chat", delivery.id, false)])
}
