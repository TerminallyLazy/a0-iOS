import Foundation
import Observation
import A0Core

/// Conversation-owned; views only read results. Arming requires an explicit send.
@MainActor @Observable public final class JevCoordinator {
    public private(set) var selected:[Int:GeneratedContent] = [:]
    public private(set) var models:[Int:String] = [:]
    private let chooser:any JevChoosing
    private let journal:JevAttemptJournal
    private var scope:String?
    private var key:String?
    private var generation = UUID()
    private var seen:Set<Int> = []
    private var sources:[Int:String] = [:]
    private var pending:[Int:Task<Void,Never>] = [:]
    public init(chooser:any JevChoosing,journal:JevAttemptJournal) { self.chooser = chooser; self.journal = journal }
    public func arm(scope:String,baseline:[LogEntry],key:String) {
        if self.scope != scope || self.key != key { cancel(); self.scope = scope; self.key = key }
        seen.formUnion(baseline.map(\.no))
    }
    public func cancel() {
        generation = UUID(); pending.values.forEach { $0.cancel() }; pending = [:]
        selected = [:]; models = [:]; sources = [:]; seen = []; scope = nil; key = nil
    }
    public func observe(_ entries:[LogEntry],scope:String) {
        guard scope == self.scope, let key else { cancel(); return }
        let present = Set(entries.map(\.no))
        for no in Array(sources.keys) where !present.contains(no) {
            pending[no]?.cancel(); selected[no] = nil; models[no] = nil; sources[no] = nil
        }
        for entry in entries {
            let fingerprint = entry.content ?? ""
            if let previous = sources[entry.no], previous != fingerprint {
                pending[entry.no]?.cancel(); selected[entry.no] = nil; models[entry.no] = nil; sources[entry.no] = nil
            }
            guard !seen.contains(entry.no), let reply = JevCandidates.extract(entry), reply.complete else { continue }
            seen.insert(entry.no)
            // Bound per-conversation memory and cost even for a malicious server.
            guard seen.count <= 4096, pending.count < 4 else { continue }
            sources[entry.no] = fingerprint
            let generation = generation, chooser = chooser, journal = journal
            pending[entry.no] = Task { [weak self] in
                do {
                    let batch = try await Task.detached { try reply.validated() }.value
                    try Task.checkCancellation()
                    guard try await journal.begin(identity:scope + "|" + String(entry.no),payload:batch.requestData()) else { return }
                    try Task.checkCancellation()
                    let result = try await chooser.choose(batch,key:key)
                    try Task.checkCancellation()
                    guard let self, self.generation == generation, self.scope == scope, self.sources[entry.no] == fingerprint else { return }
                    if let candidate = batch.candidates.first(where: { $0.id == result.candidateID }) {
                        self.selected[entry.no] = GeneratedContent(prose:reply.prose,source:candidate.source,complete:true)
                        self.models[entry.no] = result.model
                    }
                } catch { /* Preserve prose; never log keys, payloads or raw provider errors. */ }
                if let self, self.generation == generation { self.pending[entry.no] = nil }
            }
        }
    }
    public func waitForPending() async { let tasks = Array(pending.values); for task in tasks { await task.value } }
}
