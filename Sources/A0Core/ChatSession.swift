import Foundation
import Observation

public protocol ChatAPI: Sendable {
    func sendHostTask(context: String, text: String, messageID: String, queued: Bool, selection: HostTaskSelection) async throws
    func createChat(id: String) async throws -> String
    func sendText(context: String, text: String, messageID: String, queued: Bool) async throws
    func sendAttachments(context: String, text: String, messageID: String, queued: Bool, attachments: [ChatAttachment]) async throws
}
extension ChatAPI {
    public func sendHostTask(context: String, text: String, messageID: String, queued: Bool, selection: HostTaskSelection) async throws { throw ClientError.incompatiblePayload }
    public func sendAttachments(context: String, text: String, messageID: String, queued: Bool, attachments: [ChatAttachment]) async throws { throw AttachmentError.unsupported }
}

public struct Delivery: Identifiable, Sendable, Codable, Equatable {
    public enum Status: String, Sendable, Codable {
        case creating, sending, accepted, queued, uncertain, failed, cancelled
    }
    public let id: String
    public let context: String
    public let text: String
    public var hostLabel: String? = nil
    public let attachmentIDs: [UUID]?
    public fileprivate(set) var status: Status
    public fileprivate(set) var confirmed = false
    fileprivate var received = false
    fileprivate var draftFinalized = false
    fileprivate var creating: Bool
    fileprivate var draftKey: String
}

/// Foreground draft and delivery state. An uncertain mutation is never replayed.
@MainActor @Observable public final class ChatSession {
    public private(set) var selectedContext: String?
    public private(set) var deliveries: [Delivery] = []
    private var drafts: [String: String] = [:]
    private var hostDrafts: [String: HostTaskSelection] = [:]
    public var hostTask: HostTaskSelection? { hostDrafts[key] }
    public func selectHostTask(_ selection: HostTaskSelection) {
        guard selectedContext != nil, activeID == nil, attachments.isEmpty else { return }
        hostDrafts[key] = selection; persist()
    }
    public func clearHostTaskDraft() { guard activeID == nil else { return }; hostDrafts[key] = nil; persist() }
    public func invalidateHostTask() { if hostDrafts[key] != nil { hostDrafts[key]?.generation = nil; persist() } }
    public func reconcileHost(_ status: HostConnection) {
        guard let selected = hostDrafts[key], status.context == selectedContext else { return }
        if status.generation != selected.generation || status.targetID != selected.targetID || status.selection(selected.capability) == nil {
            hostDrafts[key]?.generation = nil; persist()
        }
    }
    private var staged: [String: [StagedAttachment]] = [:]
    private var importingAttachments = false
    private var previewFiles: [UUID: ChatAttachment] = [:]
    private var attachmentPreparation: UUID?
    /// Reserve the draft before Photos/iCloud bytes begin loading, so Send cannot race selection.
    public func beginAttachmentPreparation() -> UUID? {
        guard activeID == nil, !importingAttachments, attachmentPreparation == nil else { return nil }
        let token = UUID(); attachmentPreparation = token; return token
    }
    public func endAttachmentPreparation(_ token: UUID) {
        if attachmentPreparation == token { attachmentPreparation = nil }
    }
    public var attachments: [StagedAttachment] { staged[key] ?? [] }
    public func addAttachments(_ files: [ChatAttachment]) async throws {
        guard !importingAttachments else { throw AttachmentError.invalidFile }
        importingAttachments = true
        defer { importingAttachments = false }
        let destination = key, generation = generation
        let previous = staged[destination] ?? []
        let existingIDs = Set(staged.values.flatMap { $0.map(\.id) })
        guard Set(files.map(\.id)).count == files.count, files.allSatisfy({ !existingIDs.contains($0.id) }) else { throw AttachmentError.invalidFile }
        guard previous.count + files.count <= 5 else { throw AttachmentError.tooMany }
        guard previous.reduce(0, { $0 + $1.byteCount }) + files.reduce(0, { $0 + $1.data.count }) <= 20 * 1_024 * 1_024 else { throw AttachmentError.tooLarge }
        var written: [UUID] = []
        var installedMetadata = false
        do {
            for file in files {
                if let store, let profile { try await store.stage(file, for: profile) }
                else { previewFiles[file.id] = file }
                written.append(file.id)
            }
            guard generation == self.generation, destination == key else { throw CancellationError() }
            staged[destination] = (staged[destination] ?? []) + files.map(\.staged)
            installedMetadata = true
            persist(); try await flush()
        } catch {
            // If persistence failed keep in-memory metadata and protected files for an explicit save retry.
            if !installedMetadata {
                for id in written { if let store, let profile { try? await store.removeAttachment(id, for: profile) }; previewFiles[id] = nil }
            }
            throw error
        }
    }
    public func removeAttachment(_ id: UUID) {
        staged[key]?.removeAll { $0.id == id }; persist()
        let pendingSave = saving, store = store, profile = profile
        previewFiles[id] = nil
        Task { if (try? await pendingSave?.value) != nil, let store, let profile { try? await store.removeAttachment(id, for: profile) } }
    }

    private var api: any ChatAPI
    private var activeID: String?
    private var generation = UUID()
    public enum StorageState: Sendable { case memoryOnly, saving, saved, failed }
    public private(set) var storageState: StorageState = .memoryOnly
    public private(set) var restored = false
    private var store: (any SessionStoring)?
    private var profile: ProfileIdentity?
    private var revision = 0
    private var saving: Task<Void, Error>?
    private var key: String { selectedContext ?? "" }
    public var draft: String {
        get { drafts[key] ?? "" }
        set { drafts[key] = newValue; persist() }
    }
    public var visibleDeliveries: [Delivery] {
        deliveries.filter { $0.draftKey == key && !$0.confirmed }
    }
    public var canSend: Bool {
        activeID == nil && (hostTask == nil || (hostTask?.generation != nil && attachments.isEmpty)) && !importingAttachments && attachmentPreparation == nil && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty)
        && !deliveries.contains { $0.status == .uncertain && $0.draftKey == key }
    }
    public init(api: any ChatAPI) { self.api = api }
    public static func restoring(api: any ChatAPI, profile: ProfileIdentity, store: any SessionStoring) async throws -> ChatSession {
        let archive = try await store.load(profile)
        let session = ChatSession(api: api)
        session.store = store; session.profile = profile; session.storageState = .saved
        if let archive {
            session.hostDrafts = archive.hostDrafts ?? [:]
            session.drafts = archive.drafts; session.staged = archive.attachments ?? [:]; session.selectedContext = archive.selectedContext
            session.deliveries = archive.deliveries; session.revision = archive.revision
            session.restored = !archive.drafts.values.allSatisfy(\.isEmpty) || !archive.deliveries.isEmpty
            for index in session.deliveries.indices where [.creating, .sending].contains(session.deliveries[index].status) {
                session.deliveries[index].status = .uncertain
            }
        }
        return session
    }
    public func flush() async throws { try await saving?.value }
    public func retrySave() async { persist(); try? await flush() }
    private func persist() {
        guard let store, let profile else { return }
        revision += 1
        let revision = revision
        let archive = SessionArchive(profile: profile, revision: revision, selectedContext: selectedContext,
                                     drafts: drafts, deliveries: deliveries.filter { !$0.confirmed }, attachments: staged, hostDrafts: hostDrafts)
        let previous = saving
        storageState = .saving
        saving = Task { [weak self] in
            _ = await previous?.result
            do {
                try await store.save(archive)
                if self?.revision == revision { self?.storageState = .saved }
            } catch {
                if self?.revision == revision { self?.storageState = .failed }
                throw error
            }
        }
    }
    public func select(_ context: String?) {
        if selectedContext != context { attachmentPreparation = nil }
        selectedContext = context; persist()
    }
    public func resume(api: any ChatAPI) { self.api = api }
    public func suspend() {
        for key in hostDrafts.keys { hostDrafts[key]?.generation = nil }
        attachmentPreparation = nil
        generation = UUID()
        if let id = activeID, let index = deliveries.firstIndex(where: { $0.id == id }) {
            deliveries[index].status = .uncertain
        }
        activeID = nil
        persist()
    }
    public func send(mode: SendMode = .queue, isBusy: Bool = false, hasQueue: Bool = false) async {
        guard canSend else { return }
        let id = UUID().uuidString, context = selectedContext ?? UUID().uuidString
        let text = draft, originalKey = key, needsCreate = selectedContext == nil
        let references = attachments
        let hostSelection = hostTask
        let generation = generation, queued = !needsCreate && mode.shouldQueue(isBusy: isBusy, hasQueue: hasQueue)
        let index = deliveries.count
        deliveries.append(Delivery(id: id, context: context, text: text, attachmentIDs: references.map(\.id),
                                   status: needsCreate ? .creating : .sending,
                                   creating: needsCreate, draftKey: originalKey))
        deliveries[index].hostLabel = hostSelection?.hostLabel
        activeID = id
        persist()
        var dispatched = false
        defer { if activeID == id { activeID = nil } }
        do {
            try await flush()
            guard generation == self.generation else { return }
            if needsCreate {
                dispatched = true
                _ = try await api.createChat(id: context)
                guard generation == self.generation else { return }
                adoptContext(index)
                deliveries[index].creating = false
                deliveries[index].status = .sending
                dispatched = false
                persist(); try await flush()
                guard generation == self.generation else { return }
            }
            var files: [ChatAttachment] = []
            for reference in references {
                if let store, let profile { files.append(try await store.attachment(reference, for: profile)) }
                else if let file = previewFiles[reference.id] { files.append(file) }
                else { throw AttachmentError.invalidFile }
            }
            guard generation == self.generation else { return }
            dispatched = true
            if let hostSelection {
                try await api.sendHostTask(context:context,text:text,messageID:id,queued:queued,selection:hostSelection)
            } else if files.isEmpty { try await api.sendText(context: context, text: text, messageID: id, queued: queued) }
            else { try await api.sendAttachments(context: context, text: text, messageID: id, queued: queued, attachments: files) }
            guard generation == self.generation else { return }
            if !deliveries[index].received { deliveries[index].status = queued ? .queued : .accepted }
            clearSubmittedDraft(index)
            if hostSelection != nil { hostDrafts[originalKey] = nil }
            persist()
        } catch {
            guard generation == self.generation else { return }
            // A validated receipt outranks a lost HTTP acknowledgment.
            guard !deliveries[index].received else { return }
            deliveries[index].status = !dispatched || Self.definitelyRejected(error) || (hostSelection != nil && (error as? ClientError) == .httpStatus(409)) ? .failed : .uncertain
            if dispatched { persist() }
        }
    }
    /// Called only after the server acknowledges queue clearing and cancellation.
    public func recordClearedQueue(context: String) {
        for index in deliveries.indices where deliveries[index].context == context && deliveries[index].status == .queued {
            deliveries[index].status = .cancelled
        }
        persist()
    }
    public func reconcile(_ snapshot: Snapshot) {
        let previous = deliveries
        defer { if deliveries != previous { persist() } }
        for index in deliveries.indices {
            let delivery = deliveries[index]
            if delivery.creating {
                if delivery.status == .uncertain,
                   snapshot.contexts?.contains(where: { $0["id"]?.string == delivery.context }) == true {
                    adoptContext(index)
                    deliveries[index].creating = false
                    deliveries[index].status = .failed // Creation succeeded; message was never submitted.
                }
                continue
            }
            if let context = snapshot.contexts?.first(where: { $0["id"]?.string == delivery.context }),
               case .array(let queue) = context["message_queue"],
               queue.contains(where: { item in
                   if case .object(let entry) = item { return entry["id"]?.string == delivery.id }
                   return false
               }) {
                if !deliveries[index].confirmed && deliveries[index].status != .cancelled { deliveries[index].status = .queued }
                deliveries[index].received = true
                clearSubmittedDraft(index)
            }
            guard snapshot.context == delivery.context else { continue }
            if snapshot.logs.contains(where: { $0.id == delivery.id && $0.type == "user" }) {
                deliveries[index].status = .accepted
                deliveries[index].confirmed = true
                deliveries[index].received = true
                clearSubmittedDraft(index)
            }
        }
    }
    private func adoptContext(_ index: Int) {
        let delivery = deliveries[index]
        if let text = drafts[delivery.draftKey] { drafts[delivery.context] = text }
        drafts[delivery.draftKey] = nil
        staged[delivery.context] = staged[delivery.draftKey]
        staged[delivery.draftKey] = nil
        if selectedContext == nil { selectedContext = delivery.context }
        deliveries[index].draftKey = delivery.context
    }
    private func clearSubmittedDraft(_ index: Int) {
        guard !deliveries[index].draftFinalized else { return }
        deliveries[index].draftFinalized = true
        let delivery = deliveries[index]
        if drafts[delivery.draftKey] == delivery.text { drafts[delivery.draftKey] = nil }
        let ids = Set(delivery.attachmentIDs ?? [])
        staged[delivery.draftKey]?.removeAll { ids.contains($0.id) }
        // Delete accepted bytes only after the archive no longer references them.
        persist()
        let pendingSave = saving, store = store, profile = profile
        Task {
            do { try await pendingSave?.value } catch { return }
            for id in ids { if let store, let profile { try? await store.removeAttachment(id, for: profile) }; previewFiles[id] = nil }
        }
    }
    private static func definitelyRejected(_ error: any Error) -> Bool {
        guard let error = error as? ClientError else { return false }
        switch error {
        case .requiresLogin, .csrfRejected: return true
        case .httpStatus(let code): return [400, 401, 403, 404, 413, 422].contains(code)
        default: return false
        }
    }
}
