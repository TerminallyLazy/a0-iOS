import Foundation

public enum ApplyResult: Equatable, Sendable { case applied, ignored, needsFullSync }

/// Pure state reduction. A coordinator owns transport choice and supplies a generation
/// for each context/connection so delayed network results cannot cross selections.
public struct SyncReducer: Sendable {
    public private(set) var generation = UUID()
    public private(set) var context: String?
    public private(set) var logs: [LogEntry] = []
    public private(set) var contexts: [[String: JSONValue]] = []
    public private(set) var tasks: [[String: JSONValue]] = []
    public private(set) var notifications: [[String: JSONValue]] = []
    public private(set) var logVersion = 0
    public private(set) var notificationsVersion = 0
    public private(set) var logGUID: String?
    public private(set) var notificationsGUID: String?
    public private(set) var epoch: String?
    public private(set) var sequence = 0
    public private(set) var needsFullSync = true
    public private(set) var progress: JSONValue = .number(0)
    public private(set) var progressActive = false
    public private(set) var paused = false
    public init() {}

    @discardableResult public mutating func select(context: String?) -> UUID {
        self.context = context; generation = UUID(); logs = []; logVersion = 0; logGUID = nil
        sequence = 0; epoch = nil; needsFullSync = true; progress = .number(0); progressActive = false; paused = false
        return generation
    }
    public mutating func beginHandshake(epoch: String, sequenceBase: Int) {
        self.epoch = epoch; sequence = sequenceBase; needsFullSync = true
    }
    /// Keep the last display while requiring fresh state before accepting updates.
    public mutating func invalidateForRecovery() {
        generation = UUID(); epoch = nil; sequence = 0; needsFullSync = true
    }
    public var request: StateRequest {
        StateRequest(context: context, logFrom: needsFullSync ? 0 : logVersion,
                     notificationsFrom: needsFullSync ? 0 : notificationsVersion)
    }
    public mutating func apply(push: StatePush, generation: UUID) -> ApplyResult {
        guard generation == self.generation else { return .ignored }
        guard let epoch, push.data.runtimeEpoch == epoch, push.data.seq == sequence + 1 else {
            needsFullSync = true; return .needsFullSync
        }
        let result = apply(snapshot: push.data.snapshot, generation: generation, full: needsFullSync)
        if result == .applied { sequence = push.data.seq }
        return result
    }
    public mutating func apply(snapshot: Snapshot, generation: UUID, full: Bool) -> ApplyResult {
        guard generation == self.generation else { return .ignored }
        guard snapshot.context == (context ?? "") || snapshot.deselectChat else { return .ignored }
        if !full && (needsFullSync || (logGUID != nil && logGUID != snapshot.logGUID)
            || (notificationsGUID != nil && notificationsGUID != snapshot.notificationsGUID)
            || snapshot.logVersion < logVersion || snapshot.notificationsVersion < notificationsVersion) {
            needsFullSync = true; return .needsFullSync
        }
        if full && (snapshot.contexts == nil || snapshot.tasks == nil) {
            needsFullSync = true; return .needsFullSync
        }
        if snapshot.deselectChat { context = nil; logs = [] }
        if let v = snapshot.contexts { contexts = v }
        if let v = snapshot.tasks { tasks = v }
        if full || snapshot.deselectChat { logs = snapshot.logs }
        else {
            var byNumber = Dictionary(logs.map { ($0.no, $0) }, uniquingKeysWith: { _, new in new })
            for item in snapshot.logs { byNumber[item.no] = item }
            logs = byNumber.values.sorted { $0.no < $1.no }
        }
        // Notification updates are versioned collection entries, not append-only messages.
        if full { notifications = snapshot.notifications }
        else {
            for item in snapshot.notifications {
                if let id = item["id"], let index = notifications.firstIndex(where: { $0["id"] == id }) {
                    notifications[index] = item
                } else { notifications.append(item) }
            }
        }
        logGUID = snapshot.logGUID; logVersion = snapshot.logVersion
        notificationsGUID = snapshot.notificationsGUID; notificationsVersion = snapshot.notificationsVersion
        progress = snapshot.logProgress; progressActive = snapshot.logProgressActive; paused = snapshot.paused; needsFullSync = false
        return .applied
    }
}
