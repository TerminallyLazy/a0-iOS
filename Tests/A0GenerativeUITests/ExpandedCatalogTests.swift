import Foundation
import Testing
import A2UISwiftCore
@testable import A0GenerativeUI

@MainActor struct ExpandedCatalogTests {
    func payload(_ component:String)->String {
        #"[{"version":"v0.9","createSurface":{"surfaceId":"expanded","catalogId":"agent-zero:mobile:v1"}},{"version":"v0.9","updateComponents":{"surfaceId":"expanded","components":["# + component + "]}}]"
    }
    @Test func metricTableAndTimelineRenderOnlyValidTypedContent() throws {
        for component in [
            #"{"id":"root","component":"Metric","title":"Open tasks","value":"12","unit":"tasks","change":"3 fewer","trend":"down","sourceURL":"https://example.com/tasks"}"#,
            #"{"id":"root","component":"DataTable","title":"Options","columns":["Name","Duration"],"rows":[["Walk","20 minutes"],["Read","30 minutes"]]}"#,
            #"{"id":"root","component":"Timeline","title":"Afternoon","items":[{"id":"walk","title":"Take a walk","time":"2 PM","detail":"Around the park","state":"pending"}]}"#
        ] {
            let session = GeneratedSession(); try session.load(payload(component))
            #expect(session.viewModel?.componentTree != nil)
            let reply = try #require(JevCandidates.extract(try jevEntry(jevEnvelope(surface:payload(component)))))
            #expect(try reply.validated().candidates.count == 1)
        }
    }
    @Test func malformedRowsDuplicateEventsUnsafeSourcesAndUnknownStatesRejected() {
        for component in [
            #"{"id":"root","component":"Metric","title":"","value":"12"}"#,
            #"{"id":"root","component":"Metric","title":"Count","value":"12","trend":"execute","sourceURL":"http://localhost"}"#,
            #"{"id":"root","component":"DataTable","title":"Options","columns":["Name","Duration"],"rows":[["Missing cell"]]}"#,
            #"{"id":"root","component":"DataTable","title":"Options","columns":[],"rows":[]}"#,
            #"{"id":"root","component":"Timeline","title":"Plan","items":[{"id":"a","title":"One"},{"id":"a","title":"Two"}]}"#,
            #"{"id":"root","component":"Timeline","title":"Plan","items":[{"id":"a","title":"One","state":"execute"}]}"#
        ] { #expect(throws:(any Error).self) { try GeneratedDocument.validate(payload(component)) } }
    }
    @Test func checklistPreservesBindingsAndRequiresReviewedAction() throws {
        let session = GeneratedSession(); try session.load(GenerativeGuide.expandedExample)
        #expect(session.viewModel?.surface.dataModel.get("/packed") == .bool(false))
        try session.viewModel?.surface.dataModel.set("/packed",value:.bool(true))
        try session.load(GenerativeGuide.expandedExample)
        #expect(session.viewModel?.surface.dataModel.get("/packed") == .bool(true))
        let draft = try GeneratedAction.draft(ResolvedAction(name:"update_tasks",sourceComponentId:"review_tasks",context:["packed":.bool(true)]),surfaceID:session.surfaceID,existing:"")
        #expect(draft.contains("a2ui-action"))
        #expect(draft.contains("packed"))
        #expect(throws:(any Error).self) { try GeneratedDocument.validate(payload(#"{"id":"root","component":"Checklist","title":"Tasks","children":["text"]},{"id":"text","component":"Text","text":"Not a task"}"#)) }
    }
    @Test func tableAndTimelineCountLimitsAndBasicCatalogStayBounded() throws {
        let rows = Array(repeating:["cell"],count:51)
        let component:[String:Any] = ["id":"root","component":"DataTable","title":"Large","columns":["One"],"rows":rows]
        let json = String(decoding:try JSONSerialization.data(withJSONObject:component),as:UTF8.self)
        #expect(throws:(any Error).self) { try GeneratedDocument.validate(payload(json)) }
        let source = payload(#"{"id":"root","component":"Metric","title":"Count","value":"12"}"#)
        #expect(throws:(any Error).self) { try GeneratedDocument.validate(source.replacingOccurrences(of:"agent-zero:mobile:v1",with:"https://a2ui.org/specification/v0_9/basic_catalog.json")) }
    }
}
