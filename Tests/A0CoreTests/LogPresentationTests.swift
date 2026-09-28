import Testing
import Foundation
@testable import A0Core

struct LogPresentationTests {
    @Test func headingIconsBecomeNativeSymbolsAndCleanText() {
        let heading = LogHeading("icon://chat A0: Responding")
        #expect(heading.text == "A0: Responding")
        #expect(heading.symbol == "bubble.left.and.bubble.right")
        #expect(LogHeading("icon://lightbulb[Thoughts] Thinking icon://done_all").text == "Thinking")
        #expect(LogHeading("icon://unknown[Some \\[label\\]] Ready").text == "Ready")
        #expect(LogHeading("icon://unknown Ready").symbol == "circle.grid.2x2")
        #expect(LogHeading("Normal heading").symbol == nil)
        #expect(LogHeading("icon://lightbulb[Thoughts]").text == "Thoughts")
    }
    @Test func metadataDrivesToolSummaryWithoutShowingJSON() throws {
        let entry = try JSONDecoder().decode(LogEntry.self,from:Data(#"{"no":1,"type":"agent","heading":"icon://construction A0: Using search_engine","content":"{\"tool_name\":\"search_engine\",\"tool_args\":{\"query\":\"weather\"}}","kvps":{"tool_name":"search_engine","tool_args":{"query":"weather"}}}"#.utf8))
        let presentation = ActivityPresentation(entry)
        #expect(presentation.title == "Search web")
        #expect(presentation.subtitle == "A0 · Agent step")
        #expect(presentation.symbol == "globe")
        #expect(presentation.summary == "weather")
        #expect(presentation.isStructuredContent)
        #expect(presentation.fields["query"] == .string("weather"))
    }
    @Test func streamingAndUnknownEventsKeepReadableFallbacks() throws {
        func entry(_ content:String,_ type:String = "agent") -> LogEntry {
            LogEntry(no:0,id:nil,type:type,heading:"icon://psychology A0: Thinking",content:content,kvps:nil,timestamp:nil,agentno:nil)
        }
        #expect(ActivityPresentation(entry("{\"tool_name\":")).summary == "Receiving activity…")
        #expect(ActivityPresentation(entry("Plain output")).summary == "Plain output")
        #expect(ActivityPresentation(entry("failure","error")).symbol == "exclamationmark.octagon")
        #expect(ActivityPresentation(entry("{\"tool_name\":\"custom_tool\",\"tool_args\":{\"x\":2}}")).title == "Custom tool")
        #expect(ActivityPresentation(LogEntry(no:0,id:nil,type:"tool",heading:nil,content:"{\"tool_name\":\"search_engine\"}",kvps:[:],timestamp:nil,agentno:nil)).title == "Search web")
        #expect(ActivityPresentation(entry("")).summary == "Expand to inspect this step")
    }
}

struct AgentActivityPresentationTests {
    @Test func structuredAgentAttributionWinsOverLegacyHeading() {
        let entry = LogEntry(no:1,id:nil,type:"agent",heading:"A0: Using delegate_parallel",content:nil,kvps:["tool_name":.string("delegate_parallel")],timestamp:nil,agentno:2)
        let activity = ActivityPresentation(entry)
        #expect(activity.agentLabel == "Agent 2")
        #expect(activity.title == "Delegate in parallel")
        #expect(activity.symbol == "person.3")
        #expect(AgentActivitySummary.make([entry]).first?.agentNumber == 2)
    }
    @Test func agentSummariesKeepLatestRecordedEventWithoutInferringRunning() {
        func entry(_ no:Int,_ agent:Int?,_ heading:String) -> LogEntry {
            LogEntry(no:no,id:nil,type:"tool",heading:heading,content:"Observed output",kvps:nil,timestamp:nil,agentno:agent)
        }
        let summaries = AgentActivitySummary.make([entry(1,1,"A1: Searching"),entry(2,nil,"A2: Reading"),entry(3,1,"A1: Reviewing"),entry(4,nil,"Unattributed")])
        #expect(summaries.map(\.agentNumber) == [1,2])
        #expect(summaries.first?.latest.no == 3)
        #expect(summaries.first?.count == 2)
        #expect(ActivityPresentation(entry(4,nil,"Unattributed")).agentLabel == nil)
    }
    @Test func workStatusHonorsSyncPauseAndActiveFlag() {
        #expect(AgentWorkPresentation(progress:.string("icon://psychology A0: Thinking"),active:true,paused:false,synchronizing:false).title == "A0: Thinking")
        #expect(AgentWorkPresentation(progress:.string("Old tool"),active:false,paused:false,synchronizing:false).isWorking == false)
        #expect(AgentWorkPresentation(progress:.string("Old tool"),active:true,paused:true,synchronizing:false).title == "Agent paused")
        #expect(AgentWorkPresentation(progress:.string("Old tool"),active:true,paused:false,synchronizing:true).title == "Updating conversation")
    }
}

@Test func progressActivitySurvivesReductionAndResetsWithSelection() throws {
    var reducer = SyncReducer()
    let generation = reducer.select(context: "synthetic-chat")
    let initial = try snapshot()
    #expect(reducer.apply(snapshot: initial, generation: generation, full: true) == .applied)
    #expect(reducer.progressActive == initial.logProgressActive)
    let active = Snapshot(deselectChat:false,context:"synthetic-chat",contexts:[],tasks:[],logs:[],logGUID:initial.logGUID,logVersion:initial.logVersion,logProgress:.string("Thinking"),logProgressActive:true,paused:false,notifications:[],notificationsGUID:initial.notificationsGUID,notificationsVersion:initial.notificationsVersion)
    #expect(reducer.apply(snapshot:active,generation:generation,full:true) == .applied)
    #expect(reducer.progressActive)
    reducer.select(context:"other-chat")
    #expect(!reducer.progressActive)
    #expect(reducer.apply(snapshot:active,generation:generation,full:true) == .ignored)
    #expect(!reducer.progressActive)
}
