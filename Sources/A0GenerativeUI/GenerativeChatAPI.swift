import A0Core

/// Adds client presentation capabilities to the same explicitly submitted
/// request. No extra message or mutation, and queue/message IDs are unchanged.
public struct GenerativeChatAPI: ChatAPI {
    let base:any ChatAPI
    let enabled:Bool
    let jev:Bool
    public init(base:any ChatAPI,enabled:Bool,jev:Bool = false) { self.base = base; self.enabled = enabled; self.jev = jev }
    public func createChat(id:String) async throws -> String { try await base.createChat(id:id) }
    public func sendText(context:String,text:String,messageID:String,queued:Bool) async throws {
        try await base.sendText(context:context,text:enabled ? text + (jev ? Self.jevSuffix : Self.suffix) : text,messageID:messageID,queued:queued)
    }
    public func sendAttachments(context:String,text:String,messageID:String,queued:Bool,attachments:[ChatAttachment]) async throws {
        try await base.sendAttachments(context:context,text:enabled ? text + (jev ? Self.jevSuffix : Self.suffix) : text,messageID:messageID,queued:queued,attachments:attachments)
    }
    public func sendHostTask(context:String,text:String,messageID:String,queued:Bool,selection:HostTaskSelection) async throws {
        try await base.sendHostTask(context:context,text:enabled ? text + (jev ? Self.jevSuffix : Self.suffix) : text,messageID:messageID,queued:queued,selection:selection)
    }
    public static var suffix:String { "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.capabilities + "\n</agent-zero-ios-presentation>" }
    public static var priorMediaSuffix:String { "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.priorMediaCapabilities + "\n</agent-zero-ios-presentation>" }
    public static var legacySuffix:String { "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.legacyCapabilities + "\n</agent-zero-ios-presentation>" }
    public static var jevSuffix:String { "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.capabilities + "\n" + JevGuide.capabilities + "\n</agent-zero-ios-presentation>" }
    public static func visibleText(_ text:String) -> String {
        // Only collapse our exact known suffix, never arbitrary tag-like user content.
        let previous = "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.previousCapabilities
        let previousSuffixes = [previous + "\n</agent-zero-ios-presentation>", previous + "\n" + JevGuide.capabilities + "\n</agent-zero-ios-presentation>"]
        let priorJev = "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.priorMediaCapabilities + "\n" + JevGuide.capabilities + "\n</agent-zero-ios-presentation>"
        for known in [jevSuffix,suffix,legacySuffix,priorMediaSuffix,priorJev] + previousSuffixes where text.hasSuffix(known) { return String(text.dropLast(known.count)) }
        return text
    }
}
