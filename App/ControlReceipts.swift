import Foundation
import A0Core

/// Shared single writer for project and conversation mutations.
@MainActor enum ControlReceipts {
    static let journal:ControlJournal = {
        var directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("AgentZeroControlReceipts")
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where: { $0.hasPrefix("--synthetic-") }) {
            let index = args.firstIndex(of:"--persistence-test-id")
            let namespace = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? UUID().uuidString
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("A0ControlFixtures").appendingPathComponent(namespace)
        }
        #endif
        return ControlJournal(directory:directory)
    }()
}
