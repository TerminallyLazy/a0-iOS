/// Reconciles speech snapshots into the editable composer without overwriting edits.
/// A changed current draft ends this insertion; a new recording starts from that text.
public struct VoiceDraftInsertion: Sendable, Equatable {
    private let original: String
    public private(set) var lastApplied: String
    public init(draft: String) { original = draft; lastApplied = draft }
    public mutating func apply(_ snapshot: String, to currentDraft: String) -> String? {
        guard currentDraft == lastApplied else { return nil }
        guard !snapshot.isEmpty else { return currentDraft }
        lastApplied = original.isEmpty ? snapshot : original + "\n\n" + snapshot
        return lastApplied
    }
}
