import Foundation
import Testing
@testable import A0GenerativeUI

@Suite struct ChartMediaTests {
    func surface(_ component:[String:Any], catalog:String = GeneratedDocument.richCatalogID) throws -> String {
        var node = component; node["id"] = "root"
        return String(decoding:try JSONSerialization.data(withJSONObject:[
            ["version":"v0.9","createSurface":["surfaceId":"test","catalogId":catalog]],
            ["version":"v0.9","updateComponents":["surfaceId":"test","components":[node]]]
        ],options:.sortedKeys),as:UTF8.self)
    }
    func chart(_ kind:String, _ points:[[String:Any]])->[String:Any] {
        ["component":"Chart","title":"Actual observations","kind":kind,"yLabel":"Units","xLabel":"Time","points":points]
    }
    @Test func allChartStylesAcceptMeaningfulData() throws {
        for kind in ["line","bar","area","horizontalBar","groupedBar","stackedBar","stackedArea","pie","donut","scatter","bubble","histogram","range","heatmap"] {
            let p:[String:Any] = ["label":"First","value":4,"x":2,"size":3,"lower":1,"upper":5,"row":"North"]
            #expect(throws:Never.self,"\(kind)") { try GeneratedDocument.validate(surface(chart(kind,[p]))) }
        }
    }
    @Test func chartSemanticsRejectMisleadingOrUnboundedData() throws {
        let invalid:[(String,[[String:Any]])] = [
            ("pie",[["label":"A","value":0]]),("donut",[["label":"A","value":-1]]),
            ("pie",(0..<8).map{["label":"\($0)","value":1]}),
            ("scatter",[["label":"A","value":2]]),("bubble",[["label":"A","value":2,"x":1,"size":0]]),
            ("range",[["label":"A","value":8,"lower":1,"upper":5]]),
            ("histogram",[["label":"A","value":-1,"lower":1,"upper":5]]),
            ("histogram",[["label":"A","value":2,"lower":1,"upper":5],["label":"B","value":3,"lower":4,"upper":6]]),
            ("heatmap",[["label":"A","value":2]]),
            ("heatmap",[["label":"A","value":2,"row":"X"],["label":"A","value":3,"row":"X"]]),
            ("line",[["label":"A","value":1],["label":"A","value":2]]),
            ("stackedArea",[["label":"A","value":-1]]),
            ("line",(0..<9).map{["label":"A","value":1,"series":"\($0)"]}),
            ("range",[["label":"A","value":1,"lower":5,"upper":1]])
        ]
        for (kind,points) in invalid { #expect(throws:(any Error).self,"\(kind)") { try GeneratedDocument.validate(surface(chart(kind,points))) } }
    }
    @Test func mediaRequiresRichCatalogAndPublicDirectURL() throws {
        for kind in ["AudioPlayer","Video"] {
            let valid:[String:Any] = ["component":kind,"title":"Recorded briefing","url":"https://media.example.com/clip","transcript":"An accessible transcript.","sourceURL":"https://example.com/source"]
            #expect(throws:Never.self) { try GeneratedDocument.validate(surface(valid)) }
            #expect(throws:(any Error).self) { try GeneratedDocument.validate(surface(valid,catalog:"https://a2ui.org/specification/v0_9/basic_catalog.json")) }
            for url in ["http://example.com/a","https://localhost/a","https://user:pass@example.com/a","file:///tmp/a"] {
                var bad = valid; bad["url"] = url
                #expect(throws:(any Error).self) { try GeneratedDocument.validate(surface(bad)) }
            }
            var bad = valid; bad["title"] = ""
            #expect(throws:(any Error).self) { try GeneratedDocument.validate(surface(bad)) }
        }
    }
    @Test func producerAdvertisesChartsAndMediaWithoutContradictingOldRestrictions() {
        #expect(GenerativeGuide.capabilities.contains("heatmap"))
        #expect(GenerativeGuide.capabilities.contains("AudioPlayer:"))
        #expect(!GenerativeGuide.capabilities.contains("No Video/AudioPlayer"))
        let old = GenerativeGuide.legacyCapabilities + "\n" + GenerativeGuide.expandedCapabilities
        for suffix in [old,old + "\n" + JevGuide.capabilities] {
            #expect(GenerativeChatAPI.visibleText("My request\n\n<agent-zero-ios-presentation>\n" + suffix + "\n</agent-zero-ios-presentation>") == "My request")
        }
    }
}

extension ChartMediaTests {
    @Test func chartDisplayAndBoundsRetainSuppliedValues() throws {
        let p:[String:Any] = ["label":"Sample","value":4,"series":"Group","x":2,"lower":1,"upper":5,"size":3,"row":"North"]
        let content = try JSONDecoder().decode(ChartContent.self,from:JSONSerialization.data(withJSONObject:chart("range",[p])))
        #expect(content.points[0].name == "Sample · Group · North")
        #expect(content.points[0].detail == "4; x: 2; Range: 1–5; Size: 3")
        #expect(content.series == ["Group"])
        for field in ["title","yLabel","xLabel"] {
            var bad = chart("line",[["label":"A","value":1]]); bad[field] = ""
            #expect(throws:(any Error).self) { try GeneratedDocument.validate(surface(bad)) }
        }
        for points in [[],[["label":"A","value":1e12]],(0..<33).map{["label":"\($0)","value":1]}] as [[[String:Any]]] {
            #expect(throws:(any Error).self) { try GeneratedDocument.validate(surface(chart("line",points))) }
        }
        #expect(throws:Never.self) { try GeneratedDocument.validate(surface(chart("scatter",(0..<128).map{["label":"\($0)","value":$0,"x":$0]}))) }
    }
    @Test func mediaCandidatesKeepTranscriptsAndURLsOutOfJevProjection() throws {
        for type in ["AudioPlayer","Video"] {
            let source = try surface(["component":type,"title":"Private title","url":"https://media.example.com/private","transcript":"Private transcript"])
            let object = try JSONSerialization.jsonObject(with:Data(source.utf8))
            let envelope:[String:Any] = ["version":1,"intent":"Review supplied media","candidates":[["id":"clip","description":"A playable clip","surface":object]]]
            let json = String(decoding:try JSONSerialization.data(withJSONObject:envelope),as:UTF8.self)
            let batch = try JevCandidates(prose:"Summary",source:json,complete:true).validated()
            let request = String(decoding:try batch.requestData(),as:UTF8.self)
            #expect(request.contains(type)); #expect(!request.contains("Private")); #expect(!request.contains("media.example.com"))
        }
    }
    @Test func mediaRejectsExcessiveTextAndBadSources() throws {
        let valid:[String:Any] = ["component":"AudioPlayer","title":"A","url":"https://media.example.com/a"]
        for change in [["title":String(repeating:"a",count:161)],["transcript":String(repeating:"a",count:8193)],["sourceURL":"file:///a"]] {
            #expect(throws:(any Error).self) { try GeneratedDocument.validate(surface(valid.merging(change){_,b in b})) }
        }
    }
}

extension ChartMediaTests {
    @Test @MainActor func mediaAlwaysUsesTrustedLocalPlayerInsteadOfSDKBuiltins() throws {
        for type in ["AudioPlayer","Video"] {
            let session = GeneratedSession()
            try session.load(surface(["component":type,"title":"A clip","url":"https://media.example.com/clip"]))
            #expect(session.viewModel?.componentTree?.instance.component == "A0" + type)
        }
    }
}
