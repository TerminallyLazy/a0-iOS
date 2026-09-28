import Foundation

/// Groups only known routine activity; warnings, errors and unknown log types
/// retain their own visible rows. The first log number survives streaming appends.
public struct TranscriptGroup: Identifiable, Sendable, Equatable {
    public let id: Int
    public let isActivity: Bool
    public private(set) var entries: [LogEntry]

    public static func make(_ logs: [LogEntry]) -> [TranscriptGroup] {
        var result: [TranscriptGroup] = []
        for entry in logs {
            let activity = ["agent", "tool", "code_exe", "util"].contains(entry.type)
            if activity, let last = result.indices.last, result[last].isActivity {
                result[last].entries.append(entry)
            } else {
                result.append(TranscriptGroup(id:entry.no,isActivity:activity,entries:[entry]))
            }
        }
        return result
    }
}
