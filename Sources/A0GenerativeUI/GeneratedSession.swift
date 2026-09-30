import Foundation
import Observation
import A2UISwiftCore
import A2UISwiftUI

/// Owned by a response view, never shared between chats, profiles or log epochs.
@MainActor @Observable public final class GeneratedSession {
    public private(set) var viewModel: SurfaceViewModel?
    public private(set) var surfaceID = ""
    private var lastSource: String?
    public init() {}
    public func reset() {
        viewModel?.surface.dispose()
        viewModel = nil; surfaceID = ""; lastSource = nil
    }
    public func load(_ source: String) throws {
        guard source != lastSource else { return }
        reset()
        let document = try GeneratedDocument.validate(source)
        // Reconstruct an atomic snapshot, not a delta accumulated from other replies.
        let catalog = Catalog(id:document.catalogID,componentNames:GeneratedDocument.components.union(["A0TextField","A0AudioPlayer","A0Video"]))
        let surface = SurfaceModel(id:document.surfaceID,catalog:catalog)
        let candidate = SurfaceViewModel(surface:surface)
        let localMessages = document.messages.map { message -> A2uiMessage in
            guard case .updateComponents(var update) = message else { return message }
            update.components = update.components.map { component in
                var local = component
                if ["TextField","AudioPlayer","Video"].contains(local.component) { local.component = "A0" + local.component }
                return local
            }
            return .updateComponents(update)
        }
        let errors = candidate.processMessages(localMessages)
        guard errors.isEmpty else { surface.dispose(); throw GeneratedUIError.invalid }
        surfaceID = document.surfaceID; lastSource = source
        viewModel = document.deleted ? nil : candidate
    }
}

public enum GeneratedAction {
    public static func draft(_ action: ResolvedAction,surfaceID:String,existing:String) throws -> String {
        guard GeneratedDocument.validID(action.name), GeneratedDocument.validID(action.sourceComponentId), GeneratedDocument.validID(surfaceID) else { throw GeneratedUIError.invalid }
        let message = A2uiClientMessage.action(A2uiClientAction(name:action.name,surfaceId:surfaceID,sourceComponentId:action.sourceComponentId,context:action.context))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
        let data = try encoder.encode(message)
        guard data.count <= 16_384 else { throw GeneratedUIError.tooLarge }
        let text = "```a2ui-action\n" + String(decoding:data,as:UTF8.self) + "\n```"
        return existing.isEmpty ? text : existing + "\n\n" + text
    }
}
