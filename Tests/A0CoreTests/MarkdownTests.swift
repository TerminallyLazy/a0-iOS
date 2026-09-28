import Testing
@testable import A0Core

struct MarkdownTests {
    @Test func headingsParagraphsAndLists() {
        #expect(MarkdownDocument.parse("# Title\n\nHello **world**\nnext line\n\n- one\n2. two\n> quoted\n---") == [
            .heading(1,"Title"), .paragraph("Hello **world**\nnext line"), .listItem("•","one"),
            .listItem("2.","two"), .quote("quoted"), .divider])
    }
    @Test func fencedCodePreservesWhitespaceAndIncompleteStreams() {
        #expect(MarkdownDocument.parse("```swift\nlet x = 1\n  x + 2\n```\n\nafter") == [.code("swift","let x = 1\n  x + 2"),.paragraph("after")])
        #expect(MarkdownDocument.parse("~~~python\nprint('hi')") == [.code("python","print('hi')")])
        #expect(MarkdownDocument.parse("````text\n```\nkeep\n````") == [.code("text","```\nkeep")])
    }
    @Test func tableAndTasks() {
        #expect(MarkdownDocument.parse("| Name | Value |\n| --- | :---: |\n| A | B |\n\n- [x] Done\n- [ ] Todo") == [.table([["Name","Value"],["A","B"]]),.listItem("☑","Done"),.listItem("☐","Todo")])
    }
    @Test func malformedAndHTMLStayLiteral() {
        #expect(MarkdownDocument.parse("#nospace\n<script>alert(1)</script>\n| not a table |") == [.paragraph("#nospace\n<script>alert(1)</script>\n| not a table |")])
        #expect(MarkdownDocument.parse("\n\n").isEmpty)
        #expect(MarkdownDocument.parse("## Heading ##\r\n\r\n* item") == [.heading(2,"Heading"),.listItem("•","item")])
    }
    @Test func linksRequireExplicitSafeDestination() {
        #expect(MessagePresentation.externalURL("https://example.com/path") != nil)
        #expect(MessagePresentation.externalURL("http://example.com") != nil)
        for value in ["javascript:alert(1)","file:///tmp/x","data:text/html,x","https://user:secret@example.com","/relative"] {
            #expect(MessagePresentation.externalURL(value) == nil)
        }
    }
    @Test func longAndActivityMessagesRollUp() {
        #expect(!MessagePresentation.collapses(type:"response",content:"Short answer"))
        #expect(MessagePresentation.collapses(type:"response",content:String(repeating:"x",count:901)))
        #expect(MessagePresentation.collapses(type:"response",content:Array(repeating:"line",count:13).joined(separator:"\n")))
        #expect(MessagePresentation.collapses(type:"tool",content:"Short output"))
        #expect(!MessagePresentation.collapses(type:"user",content:"hi"))
    }
    @Test func followingPausesForReadingAndResumesExplicitly() {
        var follow = TranscriptFollowState()
        #expect(follow.followsLatest)
        follow.beginReading()
        #expect(!follow.followsLatest)
        follow.observedBottom(false)
        #expect(!follow.followsLatest)
        follow.jumpToLatest()
        #expect(follow.followsLatest)
        follow.beginReading(); follow.observedBottom(true)
        #expect(follow.followsLatest)
    }

}

struct TranscriptGroupingTests {
    @Test func consecutiveActivityGroupsPreserveOrderAndSurfaceWarnings() {
        let logs = ["user","agent","tool","code_exe","warning","tool","response"].enumerated().map {
            LogEntry(no:$0.offset,id:nil,type:$0.element,heading:nil,content:"entry",kvps:nil,timestamp:nil,agentno:nil)
        }
        let groups = TranscriptGroup.make(logs)
        #expect(groups.map(\.id) == [0,1,4,5,6])
        #expect(groups.map { $0.entries.count } == [1,3,1,1,1])
        #expect(groups.flatMap(\.entries) == logs)
        #expect(!groups[2].isActivity)
        #expect(TranscriptGroup.make([]).isEmpty)
        #expect(!TranscriptGroup.make([LogEntry(no:8,id:nil,type:"unknown",heading:nil,content:nil,kvps:nil,timestamp:nil,agentno:nil)])[0].isActivity)
    }
    @Test func appendedActivityKeepsStableGroupIdentity() {
        let first = LogEntry(no:4,id:nil,type:"tool",heading:nil,content:"first",kvps:nil,timestamp:nil,agentno:nil)
        let second = LogEntry(no:5,id:nil,type:"agent",heading:nil,content:"next",kvps:nil,timestamp:nil,agentno:nil)
        #expect(TranscriptGroup.make([first])[0].id == TranscriptGroup.make([first,second])[0].id)
    }
}
