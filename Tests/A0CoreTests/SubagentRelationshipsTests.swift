import Foundation
import Testing
@testable import A0Core

struct SubagentRelationshipsTests {
    private func context(_ id: String, parent: String? = nil, kind: String = "subordinate", running: Bool? = nil, paused: Bool = false) -> [String: JSONValue] {
        var result: [String: JSONValue] = ["id": .string(id), "name": .string("Chat \(id)"), "paused": .bool(paused)]
        if let parent { result["parent_context_id"] = .string(parent); result["parent_context_kind"] = .string(kind) }
        if let running { result["running"] = .bool(running) }
        return result
    }
    @Test func exactRelationsRetainNestedChildrenAndPositiveStatusOnly() {
        let graph = SubagentRelationships(contexts: [context("root"), context("child", parent:"root", running:true), context("grandchild", parent:"child", running:false), context("paused", parent:"root", running:true, paused:true)])
        #expect(graph.children(of:"root").map(\.id) == ["child", "paused"])
        #expect(graph.parent(of:"grandchild")?.id == "child")
        #expect(graph.children(of:"root").first?.status == .working)
        #expect(graph.children(of:"root").last?.status == .paused)
        #expect(graph.children(of:"child").first?.status == .unspecified)
    }
    @Test func namesAndAgentNumbersNeverCreateRelations() {
        var unrelated = context("other"); unrelated["name"] = .string("Subagent root"); unrelated["agentno"] = .number(1)
        let graph = SubagentRelationships(contexts:[context("root"), unrelated, context("unknown", parent:"root", kind:"invented"), context("missing", parent:"root", kind:"")])
        #expect(graph.children(of:"root").isEmpty)
        #expect(graph.parent(of:"other") == nil)
    }
    @Test func orphansSelfReferencesCyclesAndAmbiguousIDsAreNotNavigable() {
        let graph = SubagentRelationships(contexts:[context("root"), context("orphan", parent:"absent"), context("self", parent:"self"), context("a", parent:"b"), context("b", parent:"a"), context("descendant", parent:"a"), context("duplicate", parent:"root"), context("duplicate"), context("dupchild", parent:"duplicate")])
        for id in ["orphan", "self", "a", "b", "descendant", "duplicate", "dupchild"] { #expect(graph.parent(of:id) == nil) }
        #expect(graph.children(of:"root").isEmpty)
    }
    @Test func identifiersAndInputAreBoundedAndLabelsRemainPlainText() {
        var child = context("child", parent:"root"); child["name"] = nil; child["parent_context_label"] = .string("🧠 Research <b>plain</b>"); child["agent_profile_label"] = .string("Researcher")
        let graph = SubagentRelationships(contexts:[context("root"), child, context("bad id", parent:"root"), context(String(repeating:"x", count:257), parent:"root")])
        #expect(graph.children(of:"root").map(\.id) == ["child"])
        #expect(graph.children(of:"root").first?.name == "🧠 Research <b>plain</b>")
        #expect(graph.children(of:"root").first?.profile == "Researcher")
        #expect(SubagentRelationships(contexts:Array(repeating:context("root"), count:4097)).children(of:"root").isEmpty)
        #expect(SubagentRelationships(contexts:[]).contextIDs.isEmpty)
    }
    @Test func currentNameOutranksOriginalAssignmentLabel() {
        var child = context("child", parent:"root")
        child["name"] = .string("Renamed research")
        child["parent_context_label"] = .string("Original assignment")
        #expect(SubagentRelationships(contexts:[context("root"),child]).children(of:"root").first?.name == "Renamed research")
    }
    @Test func boundedLargeCollectionKeepsOrderingAndDiscoversNewChild() {
        var rows = [context("root")]
        for number in 0..<4094 { rows.append(context("child-\(number)", parent:"root")) }
        let initial = SubagentRelationships(contexts:rows)
        #expect(initial.children(of:"root").count == 4094)
        #expect(initial.children(of:"root").last?.id == "child-4093")
        var tracker = SubagentDiscovery(); let scope = UUID()
        tracker.reconcile(initial, scope:scope, fresh:true)
        rows.append(context("new",parent:"root"))
        tracker.reconcile(SubagentRelationships(contexts:rows), scope:scope, fresh:true)
        #expect(tracker.newIDs(parent:"root") == ["new"])
    }
    @Test func malformedMetadataAndHiddenBackgroundContextsStayOut() {
        var malformed = context("wrong", parent:"root"); malformed["parent_context_id"] = .number(1)
        var hidden = context("background", parent:"root"); hidden["type"] = .string("background")
        var missingID = context("ignored"); missingID["id"] = nil
        let graph = SubagentRelationships(contexts:[context("root"), malformed, hidden, missingID, context("", parent:"root")])
        #expect(graph.children(of:"root").isEmpty)
        #expect(graph.conversation("background") == nil)
    }
    @Test func excessiveDepthFailsClosedWithoutLosingShallowRelationships() {
        var rows = [context("root")]
        for number in 0..<70 { rows.append(context("node-\(number)", parent:number == 0 ? "root" : "node-\(number - 1)")) }
        let graph = SubagentRelationships(contexts:rows)
        #expect(graph.parent(of:"node-0")?.id == "root")
        #expect(graph.parent(of:"node-69") == nil)
    }
    @Test func historicalChildrenBaselineAndFutureChildrenAreNewOnce() {
        var tracker = SubagentDiscovery(); let scope = UUID()
        let initial = SubagentRelationships(contexts:[context("root"),context("historic",parent:"root"),context("empty")])
        tracker.reconcile(initial, scope:scope, fresh:true)
        #expect(tracker.newIDs(parent:"root").isEmpty)
        let next = SubagentRelationships(contexts:[context("root"),context("historic",parent:"root"),context("new",parent:"root"),context("empty"),context("first",parent:"empty")])
        tracker.reconcile(next, scope:scope, fresh:true); tracker.reconcile(next, scope:scope, fresh:true)
        #expect(tracker.newIDs(parent:"root") == ["new"])
        #expect(tracker.newIDs(parent:"empty") == ["first"])
        tracker.acknowledge(child:"new")
        #expect(tracker.newIDs(parent:"root").isEmpty)
        #expect(tracker.newIDs(parent:"empty") == ["first"])
    }
    @Test func incompleteSyncAccountChangesAndNewParentsDoNotInventNewness() {
        var tracker = SubagentDiscovery(); let scope = UUID()
        let initial = SubagentRelationships(contexts:[context("root")])
        tracker.reconcile(initial, scope:scope, fresh:true)
        let updated = SubagentRelationships(contexts:[context("root"),context("child",parent:"root"),context("historical-parent"),context("old",parent:"historical-parent")])
        tracker.reconcile(updated, scope:scope, fresh:false)
        #expect(tracker.newIDs(parent:"root").isEmpty)
        tracker.reconcile(updated, scope:scope, fresh:true)
        #expect(tracker.newIDs(parent:"root") == ["child"])
        #expect(tracker.newIDs(parent:"historical-parent").isEmpty)
        tracker.reconcile(updated, scope:UUID(), fresh:false)
        #expect(tracker.newIDs(parent:"root").isEmpty)
        tracker.reconcile(updated, scope:UUID(), fresh:true)
        #expect(tracker.newIDs(parent:"root").isEmpty)
    }
    @Test func deletedChildrenDropBadgesAndVisitAcknowledgesOnlyThatChild() {
        var tracker = SubagentDiscovery(); let scope = UUID()
        tracker.reconcile(SubagentRelationships(contexts:[context("root")]), scope:scope, fresh:true)
        tracker.reconcile(SubagentRelationships(contexts:[context("root"),context("a",parent:"root"),context("b",parent:"root")]), scope:scope, fresh:true)
        tracker.acknowledge(child:"a")
        #expect(tracker.newIDs(parent:"root") == ["b"])
        tracker.reconcile(SubagentRelationships(contexts:[context("root")]), scope:scope, fresh:true)
        #expect(tracker.newIDs(parent:"root").isEmpty)
    }
}
