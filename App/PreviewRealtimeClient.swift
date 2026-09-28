#if DEBUG
import Foundation
import A0Core
import A0Realtime

/// Synthetic callback stream only. Late events intentionally survive disconnect
/// so lifecycle tests exercise the coordinator's attempt and connection fences.
@MainActor final class PreviewRealtimeClient: RealtimeConnecting {
    var onEvent: (@MainActor (RealtimeEvent) -> Void)?
    func connect(session: SocketSession, request: StateRequest) {
        guard session.runtimeID == "fixture", request.logFrom == 0, request.notificationsFrom == 0 else {
            onEvent?(.failed(stage: "fixture-session-or-cursors")); return
        }
        requestState(request)
    }
    func requestState(_ request: StateRequest) {
        let callback = onEvent
        Task {
            try? await Task.sleep(for: .seconds(3))
            callback?(.handshake(epoch: "fixture-realtime", sequenceBase: 0))
            guard !ProcessInfo.processInfo.arguments.contains("--synthetic-realtime-timeout") else { return }
            try? await Task.sleep(for: .seconds(3))
            let conversationFixture = ProcessInfo.processInfo.arguments.contains("--synthetic-chat-selection")
            let context = request.context ?? ""
            let contexts: [[String: Any]] = conversationFixture
                ? ["chat-alpha", "chat-beta", "chat-empty"].map { ["id": $0, "name": $0, "running": false] }
                : request.context.map { [["id": $0, "name": "HTTP fixture chat", "running": false] as [String: Any]] } ?? []
            let entries: [[String: Any]] = conversationFixture && !context.isEmpty && context != "chat-empty"
                ? [["no": 0, "type": "response", "content": "Conversation content for " + context]] : []
            let snapshot: [String: Any] = ["context": request.context ?? "", "deselect_chat": false,
                "contexts": contexts, "tasks": [],
                "logs": entries, "log_guid": conversationFixture ? "fixture-log-" + context : "fixture-log", "log_version": entries.count,
                "log_progress": "", "log_progress_active": false, "paused": false,
                "notifications": [], "notifications_guid": "fixture-notices", "notifications_version": 0]
            guard let data = try? JSONSerialization.data(withJSONObject: ["data": ["runtime_epoch": "fixture-realtime", "seq": 1, "snapshot": snapshot]]),
                  let push = try? JSONDecoder().decode(StatePush.self, from: data) else { return }
            callback?(.push(push))
        }
    }
    func disconnect() { onEvent = nil }
}
#endif
