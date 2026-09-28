/// Compact connection presentation; a usable polling connection is distinct from realtime.
public struct ConnectionIndicator: Sendable, Equatable {
    public enum Tone: Sendable { case live, polling, working, attention, offline }
    public let tone: Tone
    public init(status: String, ready: Bool, synchronizing: Bool) {
        if ["Sync paused", "Connection needs attention", "Sign in again", "Saved drafts unavailable"].contains(status) {
            tone = .attention
        } else if ready && !synchronizing && status == "Live" {
            tone = .live
        } else if ready && !synchronizing && ["Polling", "Checking realtime"].contains(status) {
            tone = .polling
        } else if synchronizing || ["Reconnecting", "Catching up", "Synchronizing", "Opening realtime connection"].contains(status) {
            tone = .working
        } else {
            tone = .offline
        }
    }
}
