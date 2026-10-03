import Foundation
import Testing
import A0Core
import A2UISwiftCore
@testable import A0GenerativeUI

@Suite @MainActor struct RichReplyTests {
    @Test func richCatalogFixtureAndRealValues() throws {
        let session = GeneratedSession()
        try session.load(GenerativeGuide.richExample)
        #expect(session.viewModel?.componentTree?.children.count == 3)
        #expect(GeneratedDocument.components.contains("Forecast"))
        #expect(GeneratedDocument.components.contains("ImageCarousel"))
        #expect(GeneratedDocument.components.contains("Chart"))
        #expect(GeneratedDocument.components.contains("Dashboard"))
    }
    @Test func publicImagePolicyRejectsCredentialsAndPrivateHosts() {
        for source in ["http://example.com/a.png","file:///tmp/a","https://localhost/a","https://127.0.0.1/a","https://10.0.0.1/a","https://[::1]/a","https://me:secret@example.com/a","https://host.local/a","https://example.com:444/a"] {
            #expect(RichImagePolicy.url(source) == nil)
        }
        #expect(RichImagePolicy.url("https://images.example.com/photo.jpg") != nil)
    }
    @Test func richPayloadsRejectInvalidNumbersAndUnknownURLs() throws {
        for replacement in [
            GenerativeGuide.richExample.replacingOccurrences(of:"https://images.example.com/",with:"http://localhost/"),
            GenerativeGuide.richExample.replacingOccurrences(of:"\"kind\":\"line\"",with:"\"kind\":\"execute\"")
        ] { #expect(throws:(any Error).self) { try GeneratedDocument.validate(replacement) } }
    }
    @Test func automaticCapabilitiesPreserveUserTextAndQueueIdentity() async throws {
        let base = RecordingChat()
        let api = GenerativeChatAPI(base:base,enabled:true)
        try await api.sendText(context:"chat-a",text:"Show the forecast",messageID:"m",queued:true)
        let call = try #require(await base.call)
        #expect(call.context == "chat-a" && call.id == "m" && call.queued)
        #expect(call.text.hasPrefix("Show the forecast"))
        #expect(call.text.contains("Forecast")); #expect(call.text.contains("ImageCarousel"))
        #expect(GenerativeChatAPI.visibleText(call.text) == "Show the forecast")
        let plain = GenerativeChatAPI(base:base,enabled:false)
        try await plain.sendText(context:"chat-a",text:"Plain reply",messageID:"n",queued:false)
        #expect(await base.call?.text == "Plain reply")
    }
    @Test func firstMessagePresetPassesThroughRichReplyAdapter() async throws {
        let base = RecordingChat()
        let api = GenerativeChatAPI(base:base,enabled:true,jev:true)
        try await api.setModelPreset(name:"Focused",context:"new-chat")
        #expect(await base.preset == "Focused:new-chat")
        #expect(await base.call == nil)
    }
    @Test func inputUsesTrustedNativePresentation() throws {
        let session = GeneratedSession(); try session.load(GenerativeGuide.example)
        #expect(session.viewModel?.componentTree?.children.first(where:{$0.id == "destination"})?.instance.component == "A0TextField")
    }
}
private actor RecordingChat: ChatAPI {
    struct Call: Sendable { let context:String; let text:String; let id:String; let queued:Bool }
    var call: Call?
    var preset: String?
    func setModelPreset(name:String,context:String) async throws { preset = name + ":" + context }
    func createChat(id:String) async throws -> String { id }
    func sendText(context:String,text:String,messageID:String,queued:Bool) async throws { call = Call(context:context,text:text,id:messageID,queued:queued) }
}

extension RichReplyTests {
    @Test func jevGuidanceIsOptInAndLegacyMessagesStillCollapse() async throws {
        let base = RecordingChat()
        let api = GenerativeChatAPI(base:base,enabled:true,jev:true)
        try await api.sendText(context:"a",text:"Useful overview",messageID:"same",queued:true)
        let call = try #require(await base.call)
        #expect(call.text.contains("a2ui-candidates"))
        #expect(call.id == "same" && call.queued)
        #expect(GenerativeChatAPI.visibleText(call.text) == "Useful overview")
        #expect(GenerativeChatAPI.visibleText("Old" + GenerativeChatAPI.suffix) == "Old")
        #expect(!call.text.contains("TYPESAFE_API_KEY"))
        try await GenerativeChatAPI(base:base,enabled:false,jev:true).sendText(context:"a",text:"Plain",messageID:"b",queued:false)
        #expect(await base.call?.text == "Plain")
    }
}
