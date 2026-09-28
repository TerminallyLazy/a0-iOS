/// Incoming messages may follow the bottom only while the reader has not
/// intentionally moved into history. Layout changes do not revoke that intent.
public struct TranscriptFollowState: Sendable, Equatable {
    public private(set) var followsLatest = true
    public init() {}
    public mutating func beginReading() { followsLatest = false }
    public mutating func observedBottom(_ visible: Bool) { if visible { followsLatest = true } }
    public mutating func jumpToLatest() { followsLatest = true }
}
