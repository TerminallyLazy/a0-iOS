import Foundation
import Testing
import A0Core
import A2UISwiftCore
@testable import A0GenerativeUI

@Suite @MainActor struct GenerativeUITests {
    func entry(_ content: String, type: String = "response") throws -> LogEntry {
        let data = try JSONSerialization.data(withJSONObject:["no":1,"type":type,"content":content])
        return try JSONDecoder().decode(LogEntry.self,from:data)
    }
    func payload(_ components: String, extra: String = "") -> String {
        "[{\"version\":\"v0.9\",\"createSurface\":{\"surfaceId\":\"trip\",\"catalogId\":\"https://a2ui.org/specification/v0_9/basic_catalog.json\"}}," +
        "{\"version\":\"v0.9\",\"updateComponents\":{\"surfaceId\":\"trip\",\"components\":" + components + "}}" + extra + "]"
    }
    let text = #"[{"id":"root","component":"Text","text":"Native answer"}]"#
    @Test func explicitResponseBlocksOnlyAndStreaming() throws {
        #expect(GeneratedContent.extract(try entry("ordinary JSON {}")) == nil)
        #expect(GeneratedContent.extract(try entry("```a2ui\n[]\n```",type:"user")) == nil)
        let pending = try #require(GeneratedContent.extract(try entry("Intro\n```a2ui\n[")))
        #expect(!pending.complete)
        let result = try #require(GeneratedContent.extract(try entry("Intro\n```a2ui\n" + payload(text) + "\n```\nAfter")))
        #expect(result.complete)
        #expect(result.prose.contains("Intro")); #expect(result.prose.contains("After"))
        #expect(!result.prose.contains("createSurface"))
    }
    @Test func sdkRendersValidatedTreeAndKeepsInputOnRepeatedSnapshot() throws {
        let session = GeneratedSession()
        let source = payload(text)
        try session.load(source)
        #expect(session.viewModel?.componentTree != nil)
        let first = session.viewModel
        try session.load(source)
        #expect(first === session.viewModel)
        #expect(session.surfaceID == "trip")
    }
    @Test func rejectsNetworkComponentsFunctionsCyclesAndOversize() throws {
        for components in [
            #"[{"id":"root","component":"Image","url":"https://example.com/track"}]"#,
            #"[{"id":"root","component":"Text","text":{"call":"openUrl","args":{"url":"file:///etc/passwd"}}}]"#,
            #"[{"id":"root","component":"Column","children":["root"]}]"#,
            #"[{"id":"root","component":"Column","children":["missing"]}]"#,
            #"[{"id":"root","component":"TextField"}]"#,
            #"[{"id":"root","component":"Slider","value":0,"min":10,"max":1}]"#
        ] { #expect(throws:(any Error).self) { try GeneratedDocument.validate(payload(components)) } }
        #expect(throws:(any Error).self) { try GeneratedDocument.validate(String(repeating:" ",count:70_000)) }
    }
    @Test func updatesDeleteAndInvalidReplacementNeverKeepStaleSurface() throws {
        let session = GeneratedSession()
        try session.load(payload(text))
        #expect(throws:(any Error).self) { try session.load("[]") }
        #expect(session.viewModel == nil)
        try session.load(payload(text,extra:#",{"version":"v0.9","deleteSurface":{"surfaceId":"trip"}}"#))
        #expect(session.viewModel == nil)
    }
    @Test func actionsAreBoundedAndAppendedWithoutSendingOrReplacingDraft() throws {
        let action = ResolvedAction(name:"choose",sourceComponentId:"choose",context:["destination":.string("Paris")])
        let draft = try GeneratedAction.draft(action,surfaceID:"trip",existing:"Keep this")
        #expect(draft.hasPrefix("Keep this\n\n"))
        #expect(draft.contains("a2ui-action")); #expect(draft.contains("Paris"))
        #expect(throws:(any Error).self) { try GeneratedAction.draft(.init(name:"choose",sourceComponentId:"b",context:["x":.string(String(repeating:"x",count:20_000))]),surfaceID:"trip",existing:"") }
    }
    @Test func dataBindingUpdatesAndSurfaceIsolation() throws {
        let source = payload(#"[{"id":"root","component":"Text","text":{"path":"/answer"}}]"#,
            extra:#",{"version":"v0.9.1","updateDataModel":{"surfaceId":"trip","path":"/","value":{"answer":"First"}}},{"version":"v0.9","updateDataModel":{"surfaceId":"trip","path":"/answer","value":"Final"}}"#)
        let first = GeneratedSession(), other = GeneratedSession()
        try first.load(source); try other.load(source)
        #expect(first.viewModel?.surface.dataModel.get("/answer") == .string("Final"))
        try first.viewModel?.surface.dataModel.set("/answer",value:.string("Edited locally"))
        try first.load(source)
        #expect(first.viewModel?.surface.dataModel.get("/answer") == .string("Edited locally"))
        #expect(other.viewModel?.surface.dataModel.get("/answer") == .string("Final"))
        try first.load(source.replacingOccurrences(of:"Final",with:"New server revision"))
        #expect(first.viewModel?.surface.dataModel.get("/answer") == .string("New server revision"))
    }
    @Test func safeCatalogControlsAndExampleRender() throws {
        let controls = #"[{"id":"root","component":"Column","children":["row","field","toggle","choices","slider","button","divider"]},{"id":"row","component":"Row","children":["card"]},{"id":"card","component":"Card","child":"label"},{"id":"label","component":"Text","text":"Label"},{"id":"field","component":"TextField","label":"Input","value":{"path":"/input"}},{"id":"toggle","component":"CheckBox","label":"Include","value":true},{"id":"choices","component":"ChoicePicker","options":[{"label":"One","value":"one"}],"value":["one"]},{"id":"slider","component":"Slider","value":0.5,"min":0,"max":1},{"id":"button","component":"Button","child":"label","action":{"event":{"name":"choose","context":{"value":{"path":"/input"}}}}},{"id":"divider","component":"Divider"}]"#
        #expect(try GeneratedDocument.validate(payload(controls)).surfaceID == "trip")
        let session = GeneratedSession(); try session.load(GenerativeGuide.example)
        #expect(session.viewModel?.componentTree?.children.count == 5)
    }
    @Test func crossSurfaceUnknownVersionAndImplicitSharingRejected() throws {
        let base = payload(text)
        for source in [
            base.replacingOccurrences(of:"v0.9",with:"v0.8"),
            base.replacingOccurrences(of:"basic_catalog.json",with:"other.json"),
            base.replacingOccurrences(of:#""createSurface":{"surfaceId":"trip""#,with:#""createSurface":{"sendDataModel":true,"surfaceId":"trip""#),
            base.replacingOccurrences(of:#""updateComponents":{"surfaceId":"trip""#,with:#""updateComponents":{"surfaceId":"other""#),
            payload(text,extra:#",{"version":"v0.9","deleteSurface":{"surfaceId":"other"}}"#),
            payload(text,extra:#",{"version":"v0.9","updateDataModel":{"surfaceId":"trip","path":"/items/-1","value":"bad"}}"#),
            payload(text,extra:#",{"version":"v0.9","updateDataModel":{"surfaceId":"trip","path":"/items/99999999999999999999999","value":"bad"}}"#)
        ] { #expect(throws:(any Error).self) { try GeneratedDocument.validate(source) } }
    }
    @Test func graphExpansionAndRepeatedIDsBounded() throws {
        let duplicate = #"[{"id":"root","component":"Text","text":"one"},{"id":"root","component":"Text","text":"two"}]"#
        #expect(throws:(any Error).self) { try GeneratedDocument.validate(payload(duplicate)) }
        let chain = (0..<15).map { i in
            ["id":i == 0 ? "root" : "n\(i)","component":"Column","children":i == 14 ? [] : ["n\(i + 1)"]] as [String:Any]
        }
        let json = String(decoding:try JSONSerialization.data(withJSONObject:chain),as:UTF8.self)
        #expect(throws:(any Error).self) { try GeneratedDocument.validate(payload(json)) }
    }
    @Test func fencedExamplesAndStructuredMetadata() throws {
        #expect(GeneratedContent.extract(try entry("````text\n```a2ui\n[]\n```\n````")) == nil)
        let data = try JSONSerialization.data(withJSONObject:["no":0,"type":"response","content":"Explanation","kvps":["a2ui":try JSONSerialization.jsonObject(with:Data(payload(text).utf8))]])
        let result = try #require(GeneratedContent.extract(JSONDecoder().decode(LogEntry.self,from:data)))
        #expect(result.prose == "Explanation"); #expect(result.complete)
        #expect(try GeneratedDocument.validate(result.source).surfaceID == "trip")
    }

    @Test func rejectsUnsafeIntermediateGraphEvenIfLaterRepaired() throws {
        let intermediate = payload(#"[{"id":"root","component":"Column","children":["root"]}]"#,
            extra:#",{"version":"v0.9","updateComponents":{"surfaceId":"trip","components":[{"id":"root","component":"Text","text":"Repaired"}]}}"#)
        #expect(throws:(any Error).self) { try GeneratedDocument.validate(intermediate) }
    }

}
