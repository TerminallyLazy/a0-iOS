import Foundation

/// Monotonic foreground time; missed deadlines never cause catch-up bursts.
public struct RealtimeRetrySchedule: Sendable {
    private var nextAttempt: Duration = .seconds(30)
    private var interval: Duration = .seconds(30)
    public init() {}
    public mutating func reserve(at elapsed: Duration) -> Bool {
        guard elapsed >= nextAttempt else { return false }
        interval = min(interval * 2, .seconds(120))
        nextAttempt = elapsed + interval
        return true
    }
}

/// Candidate state stays private until both the handshake and full snapshot pass.
/// The coordinator fences callbacks by attempt ID and cancels polling before publishing.
public struct RealtimeHandoff: Sendable {
    private let sourceGeneration: UUID
    private var state = SyncReducer()
    public init(context: String?, sourceGeneration: UUID) {
        self.sourceGeneration = sourceGeneration
        state.select(context: context)
    }
    public var request: StateRequest { StateRequest(context: state.context) }
    public mutating func handshake(epoch: String, sequenceBase: Int) {
        state.beginHandshake(epoch: epoch, sequenceBase: sequenceBase)
    }
    public mutating func accept(_ push: StatePush, replacing current: SyncReducer) -> SyncReducer? {
        let snapshot = push.data.snapshot
        // If polling sees a collection reset, let it establish the new baseline
        // before a later socket attempt. A delayed candidate must never undo it.
        guard current.generation == sourceGeneration,
              current.logGUID == nil || snapshot.logGUID == current.logGUID,
              current.notificationsGUID == nil || snapshot.notificationsGUID == current.notificationsGUID,
              !(snapshot.logGUID == current.logGUID && snapshot.logVersion < current.logVersion),
              !(snapshot.notificationsGUID == current.notificationsGUID && snapshot.notificationsVersion < current.notificationsVersion),
              state.apply(push: push, generation: state.generation) == .applied else { return nil }
        return state
    }
}
