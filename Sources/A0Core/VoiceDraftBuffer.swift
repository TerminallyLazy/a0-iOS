import Foundation

/// Recognition partials are snapshots; only finalized segments accumulate.
public struct VoiceDraftBuffer: Sendable, Equatable {
    public static let limit = 12_000
    private var finalized = ""
    private var partial = ""
    public init() {}
    public var text: String {
        String([finalized, partial].filter { !$0.isEmpty }.joined(separator: " ").prefix(Self.limit))
    }
    public mutating func update(_ snapshot: String) {
        partial = String(snapshot.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.limit))
    }
    public mutating func finishSegment() { finalized = text; partial = "" }
    public func appending(to draft: String) -> String {
        guard !text.isEmpty else { return draft }
        return draft.isEmpty ? text : draft + "\n\n" + text
    }
}
