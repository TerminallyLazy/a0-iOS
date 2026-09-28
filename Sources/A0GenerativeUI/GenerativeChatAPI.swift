import A0Core

/// Adds client presentation capabilities to the same explicitly submitted
/// request. No extra message or mutation, and queue/message IDs are unchanged.
public struct GenerativeChatAPI: ChatAPI {
    let base:any ChatAPI
    let enabled:Bool
    public init(base:any ChatAPI,enabled:Bool) { self.base = base; self.enabled = enabled }
    public func createChat(id:String) async throws -> String { try await base.createChat(id:id) }
    public func sendText(context:String,text:String,messageID:String,queued:Bool) async throws {
        try await base.sendText(context:context,text:enabled ? text + Self.suffix : text,messageID:messageID,queued:queued)
    }
    public func sendAttachments(context:String,text:String,messageID:String,queued:Bool,attachments:[ChatAttachment]) async throws {
        try await base.sendAttachments(context:context,text:enabled ? text + Self.suffix : text,messageID:messageID,queued:queued,attachments:attachments)
    }
    public static var suffix:String { "\n\n<agent-zero-ios-presentation>\n" + GenerativeGuide.capabilities + "\n</agent-zero-ios-presentation>" }
    public static func visibleText(_ text:String) -> String {
        // Only collapse our exact known suffix, never arbitrary tag-like user content.
        text.hasSuffix(suffix) ? String(text.dropLast(suffix.count)) : text
    }
}
