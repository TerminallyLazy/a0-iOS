import Foundation
import A0Core
@preconcurrency import SocketIO

public enum RealtimeEvent: Sendable {
    case handshake(epoch: String, sequenceBase: Int)
    case push(StatePush)
    case failed(stage: String)
}

@MainActor public protocol RealtimeConnecting: AnyObject {
    var onEvent: (@MainActor (RealtimeEvent) -> Void)? { get set }
    func connect(session: SocketSession, request: StateRequest)
    func requestState(_ request: StateRequest)
    func disconnect()
}

/// Socket.IO callbacks are confined to handleQueue(.main). No library auto-reconnect:
/// the coordinator obtains a fresh security context before reconnecting.
@MainActor public final class RealtimeClient: RealtimeConnecting {
    public var onEvent: (@MainActor (RealtimeEvent) -> Void)?
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var connectionID = UUID()
    private var handshakeID: String?
    private var pendingPushes: [StatePush] = []
    private var queuedRequest: StateRequest?
    public init() {}
    public func connect(session: SocketSession, request: StateRequest) {
        disconnect()
        let generation = connectionID
        let manager = SocketManager(socketURL: session.origin.url, config: [
            .log(false), .handleQueue(.main), .reconnects(false), .forceNew(true),
            .forceWebsockets(true), .version(.three), .path("/socket.io/"),
            .extraHeaders(["Origin": session.origin.header, "Cookie": session.cookieHeader])
        ])
        let socket = manager.socket(forNamespace: "/ws")
        self.manager = manager; self.socket = socket
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, self.connectionID == generation else { return }
                self.requestState(request)
            }
        }
        socket.on("state_push") { [weak self] data, _ in
            MainActor.assumeIsolated {
                guard let self, self.connectionID == generation else { return }
                guard let first = data.first, JSONSerialization.isValidJSONObject(first),
                      let encoded = try? JSONSerialization.data(withJSONObject: first),
                      let push = try? JSONDecoder().decode(StatePush.self, from: encoded) else {
                    self.onEvent?(.failed(stage: "payload-or-handshake")); return
                }
                if self.handshakeID != nil {
                    guard self.pendingPushes.count < 32 else { self.onEvent?(.failed(stage: "payload-or-handshake")); return }
                    self.pendingPushes.append(push)
                } else { self.onEvent?(.push(push)) }
            }
        }
        for event in [SocketClientEvent.error, .disconnect] {
            socket.on(clientEvent: event) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, self.connectionID == generation else { return }
                    self.onEvent?(.failed(stage: event == .error ? "socket-error" : "socket-disconnect"))
                }
            }
        }
        socket.connect(withPayload: ["csrf_token": session.csrfToken, "handlers": ["ws_webui"]], timeoutAfter: 10) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.connectionID == generation else { return }
                self.onEvent?(.failed(stage: "connect-timeout"))
            }
        }
    }
    public func requestState(_ request: StateRequest) {
        guard let socket, socket.status == .connected else { return }
        if handshakeID != nil { queuedRequest = request; return }
        let correlation = UUID().uuidString
        let generation = connectionID
        guard let encoded = try? JSONEncoder().encode(request),
              let payload = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            onEvent?(.failed(stage: "encoding")); return
        }
        handshakeID = correlation; pendingPushes = []
        socket.emitWithAck("state_request", ["ts": Date().timeIntervalSince1970 * 1000,
            "data": payload, "correlationId": correlation]).timingOut(after: 10) { [weak self] data in
            MainActor.assumeIsolated {
                guard let self, self.connectionID == generation, self.handshakeID == correlation else { return }
                self.handshakeID = nil
                guard let first = data.first, JSONSerialization.isValidJSONObject(first),
                      let encoded = try? JSONSerialization.data(withJSONObject: first),
                      let ack = try? JSONDecoder().decode(HandshakeAck.self, from: encoded),
                      let accepted = try? ack.validated(correlationID: correlation) else {
                    self.pendingPushes = []; self.onEvent?(.failed(stage: "payload-or-handshake")); return
                }
                if let queued = self.queuedRequest {
                    self.queuedRequest = nil; self.pendingPushes = []
                    self.requestState(queued)
                    return
                }
                self.onEvent?(.handshake(epoch: accepted.epoch, sequenceBase: accepted.sequenceBase))
                let pending = self.pendingPushes; self.pendingPushes = []
                for push in pending { self.onEvent?(.push(push)) }
            }
        }
    }
    public func disconnect() {
        connectionID = UUID(); handshakeID = nil; pendingPushes = []; queuedRequest = nil
        socket?.removeAllHandlers(); socket?.disconnect(); manager?.disconnect()
        socket = nil; manager = nil
    }
}
