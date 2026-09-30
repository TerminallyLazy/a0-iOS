import Foundation
import Testing
import A0Core
@testable import A0GenerativeUI

@Suite struct ReplyMediaPreviewTests {
    private func entry(_ text:String,type:String = "response",kvps:[String:Any]? = nil) throws -> LogEntry {
        var object:[String:Any] = ["no":1,"type":type,"content":text]
        if let kvps { object["kvps"] = kvps }
        return try JSONDecoder().decode(LogEntry.self,from:JSONSerialization.data(withJSONObject:object))
    }
    @Test func recognizesDirectReplyLinksWithoutChangingTheirSource() throws {
        let text = "MP4 direct URL:\nhttps://media.example.com/flower.mp4\n\nMP3 direct URL:\n[Song](https://media.example.com/song.MP3?download=1)"
        let links = ReplyMediaPreview.extract(try entry(text))
        #expect(links.map(\.kind) == [.video,.audio])
        #expect(links.map(\.url) == ["https://media.example.com/flower.mp4","https://media.example.com/song.MP3?download=1"])
        #expect(links[0].content.url == links[0].url)
        #expect(links[0].content.title == "Video")
        #expect(links[1].content.title == "Audio")
        #expect(links[0].content.transcript == nil)
        #expect(links[0].id == links[0].url)
    }
    @Test func excludesNonResponsesExamplesCodeHTMLAndUnsupportedLinks() throws {
        let url = "https://media.example.com/clip.mp4"
        for type in ["user","tool","agent","code_exe","util"] {
            #expect(ReplyMediaPreview.extract(try entry(url,type:type)).isEmpty)
        }
        for text in ["```swift\n\(url)\n```","~~~\n\(url)\n~~~", "`\(url)`", "``\(url)``", "> \(url)", "<video src=\"\(url)\"></video>", "<div>\n\(url)\n</div>", "    \(url)", "![Preview](\(url))", "[sample]: \(url)"] {
            #expect(ReplyMediaPreview.extract(try entry(text)).isEmpty, "Unexpected preview: \(text)")
        }
        for url in ["http://media.example.com/a.mp4","https://127.0.0.1/a.mp4","https://media.local/a.mp4","https://user:pass@example.com/a.mp3","https://example.com:8443/a.mp4","https://example.com/watch?v=a.mp4","https://example.com/a.m3u8","https://example.com/a.mpd","file:///a.mp4"] {
            #expect(ReplyMediaPreview.extract(try entry(url)).isEmpty)
        }
    }
    @Test func excludesMultilineHTMLAndLazyBlockquoteContinuations() throws {
        for text in ["<div>\n\nhttps://media.example.com/html.mp4\n\n</div>", "> A quoted example\nhttps://media.example.com/quoted.mp3"] {
            #expect(ReplyMediaPreview.extract(try entry(text)).isEmpty)
        }
        let text = "> A quote\nhttps://media.example.com/quote.mp3\n\nhttps://media.example.com/actual.mp4"
        #expect(ReplyMediaPreview.extract(try entry(text)).map(\.url) == ["https://media.example.com/actual.mp4"])
    }
    @Test func explicitPayloadsHavePrecedenceEvenWhenInvalidOrPending() throws {
        let link = "https://media.example.com/a.mp3"
        for suffix in ["\n```a2ui\n[]\n```","\n```a2ui\n[","\n```a2ui-candidates\n{}\n```","\n```a2ui-candidates\n{"] {
            #expect(ReplyMediaPreview.extract(try entry(link + suffix)).isEmpty)
        }
        #expect(ReplyMediaPreview.extract(try entry(link,kvps:["a2ui":[]])).isEmpty)
    }
    @Test func ordinaryJSONIsNotTreatedAsPlayableProse() throws {
        for source in [#"{"url":"https://media.example.com/a.mp4"}"#, #"[{"component":"Video","url":"https://media.example.com/a.mp4"}]"#] {
            #expect(ReplyMediaPreview.extract(try entry(source)).isEmpty)
        }
    }
    @Test func supportedExtensionsPunctuationAndDuplicatesAreBounded() throws {
        for (ext,kind) in [("mp3",MediaKind.audio),("m4a",.audio),("aac",.audio),("wav",.audio),("mp4",.video),("mov",.video)] {
            let url = "https://media.example.com/file.\(ext)"
            #expect(ReplyMediaPreview.extract(try entry("\(url). [Clip](\(url))")).map(\.kind) == [kind])
        }
        let links = (0..<8).map { "https://media.example.com/\($0).mp3" }
        #expect(ReplyMediaPreview.extract(try entry(links.joined(separator:"\n"))).map(\.url) == Array(links.prefix(4)))
        #expect(ReplyMediaPreview.extract(try entry("See (https://media.example.com/a.mp4), then https://media.example.com/b.mp3!")).count == 2)
        #expect(ReplyMediaPreview.extract(try entry("https://media.example.com/a.mp3?x=" + String(repeating:"a",count:2048))).isEmpty)
        #expect(ReplyMediaPreview.extract(try entry(String(repeating:"a",count:131_072) + " https://media.example.com/a.mp3")).isEmpty)
        #expect(ReplyMediaPreview.extract(try entry("")).isEmpty)
    }
    @Test func mixedProseKeepsCodeAndQuotedLinksOutWithoutLosingOrdinaryLinks() throws {
        let text = "`https://media.example.com/code.mp4`\n\n> https://media.example.com/quote.mp3\n\nPlay **this** [clip](https://media.example.com/actual.mp4)."
        #expect(ReplyMediaPreview.extract(try entry(text)).map(\.url) == ["https://media.example.com/actual.mp4"])
    }
    @Test func oversizedMalformedURLIsRejectedWithoutManualPunctuationScanning() throws {
        let source = "https://media.example.com/" + String(repeating:")",count:100_000) + ".mp4"
        #expect(ReplyMediaPreview.extract(try entry(source)).isEmpty)
    }
    @Test func listAndTableLinksRetainDocumentOrder() throws {
        let source = "# [Video](https://media.example.com/a.mp4)\n\n- [Audio](https://media.example.com/b.mp3)\n\n| Media | Link |\n| --- | --- |\n| Clip | [Watch](https://media.example.com/c.mov) |"
        #expect(ReplyMediaPreview.extract(try entry(source)).map(\.url) == ["https://media.example.com/a.mp4","https://media.example.com/b.mp3","https://media.example.com/c.mov"])
    }
    @Test func producerIncludesValidMediaExampleAndKeepsPriorSuffixHidden() throws {
        #expect(throws:Never.self) { try GeneratedDocument.validate(GenerativeGuide.mediaExample) }
        #expect(GenerativeGuide.instructions.contains(GenerativeGuide.mediaExample))
        #expect(GenerativeGuide.capabilities.contains("Do not stop at listing direct URLs"))
        #expect(GenerativeChatAPI.visibleText("Request" + GenerativeChatAPI.priorMediaSuffix) == "Request")
        let oldJev = "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.priorMediaCapabilities + "\n" + JevGuide.capabilities + "\n</agent-zero-ios-presentation>"
        #expect(GenerativeChatAPI.visibleText("Request" + oldJev) == "Request")
    }
}
