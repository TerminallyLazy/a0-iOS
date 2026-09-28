import Foundation
import A0Core
import A0Realtime

@main struct Probe {
    @MainActor static func main() async {
        #if DEBUG
        guard CommandLine.arguments.count == 2 else {
            print("Usage: a0-transport-probe http://localhost:<port>"); return
        }
        do {
            let origin = try ServerOrigin(CommandLine.arguments[1], policy: .loopbackDevelopment)
            guard origin.allowsUnauthenticatedLoopback else { throw ClientError.invalidOrigin }
            let client = APIClient(origin: origin)
            try await client.connect(username: "", password: "")
            let snapshot = try await client.poll(StateRequest(timezone: "UTC"))
            print("HTTP snapshot decoded; \(snapshot.contexts?.count ?? 0) contexts, \(snapshot.logs.count) selected logs. Bodies withheld.")
            let realtime = RealtimeClient()
            let (stream, continuation) = AsyncStream<RealtimeEvent>.makeStream()
            realtime.onEvent = { continuation.yield($0) }
            let timeout = Task { try? await Task.sleep(for: .seconds(15)); continuation.finish() }
            realtime.connect(session: try await client.socketSession(), request: StateRequest(timezone: "UTC"))
            var reducer = SyncReducer()
            var success = false
            for await event in stream {
                switch event {
                case .handshake(let epoch, let base):
                    reducer.beginHandshake(epoch: epoch, sequenceBase: base)
                    print("Socket.IO /ws accepted state_request; sequence baseline \(base).")
                case .push(let push):
                    if reducer.apply(push: push, generation: reducer.generation) == .applied {
                        print("Socket.IO full state decoded and applied; sequence \(reducer.sequence).")
                        success = true; continuation.finish()
                    } else { print("State push requires resync."); continuation.finish() }
                case .failed(let stage): print("Socket.IO failed: \(stage)."); continuation.finish()
                }
            }
            timeout.cancel(); realtime.disconnect(); await client.disconnect()
            print(success ? "PASS: loopback HTTP + Socket.IO interoperability. Remote authentication and TLS not tested." : "FAIL: no accepted state push.")
            if !success { exit(1) }
        } catch {
            print((error as? ClientError)?.errorDescription ?? "Transport failed; sensitive details withheld.")
            exit(1)
        }
        #else
        print("The loopback probe is available only in Debug builds.")
        #endif
    }
}
