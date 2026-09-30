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
