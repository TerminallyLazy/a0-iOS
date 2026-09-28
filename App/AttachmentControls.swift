import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import A0Core

/// A locally staged tray. Selection never uploads; ordinary Send owns submission.
struct AttachmentTray: View {
    @Bindable var chat: ChatSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        if !chat.attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chat.attachments) { file in
                        HStack(spacing: 8) {
                            Image(systemName: file.contentType.hasPrefix("image/") ? "photo" : "doc")
                                .foregroundStyle(Color("A0Tint"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name).font(.caption.weight(.medium))
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1).truncationMode(.middle)
                                    .fixedSize(horizontal:false,vertical:true)
                                Text(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .file))
                                    .font(.caption2).foregroundStyle(Color.a0Supporting)
                            }.frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 280 : 160, alignment: .leading)
                            Button { chat.removeAttachment(file.id) } label: {
                                Image(systemName: "xmark").font(.caption.weight(.semibold)).frame(width: 44, height: 44)
                            }.accessibilityLabel("Remove \(file.name)")
                                .accessibilityIdentifier("removeAttachment-\(file.id)")
                        }.padding(.leading, 12)
                            .background(Color("A0Panel"), in: RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color("A0Tint").opacity(0.16)) }
                    }
                }
            }.accessibilityIdentifier("attachmentTray")
        }
    }
}

extension View {
    func attachmentPicker(chat: ChatSession, isPresented: Binding<Bool>) -> some View {
        modifier(AttachmentPickerModifier(chat: chat, isPresented: isPresented))
    }
}

private struct AttachmentPickerModifier: ViewModifier {
    let chat: ChatSession
    @Binding var isPresented: Bool
    @State private var showsFiles = false
    @State private var showsPhotos = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var preparationToken: UUID?
    @State private var preparingSession: ChatSession?
    @State private var errorMessage: String?
    @State private var targetContext: String?
    @State private var targetSession: ObjectIdentifier?
    @State private var importID = UUID()
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Attach to message", isPresented: $isPresented, titleVisibility: .visible) {
                Button("Photo Library", systemImage: "photo.on.rectangle") { beginSelection(); showsPhotos = true }.accessibilityIdentifier("attachPhotos")
                Button("Choose Files", systemImage: "doc.badge.plus") { beginSelection(); showsFiles = true }.accessibilityIdentifier("attachDocuments")
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--synthetic-attachments") {
                    Button("Attach sample file") {
                        beginSelection()
                        runImport(ticket: importID) {
                            if ProcessInfo.processInfo.arguments.contains("--synthetic-attachment-delay") { try await Task.sleep(for:.seconds(8)) }
                            return [try ChatAttachment(name: "sample.txt", contentType: "text/plain", data: Data("Synthetic attachment".utf8))]
                        }
                    }.accessibilityIdentifier("attachSyntheticFile")
                }
                #endif
                Button("Cancel", role: .cancel) { }
            } message: { Text("Up to 5 files, 10 MB each. Files are sent only when you tap Send.") }
            .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                guard targetSession == ObjectIdentifier(chat), targetContext == chat.selectedContext, scenePhase != .background else { return }
                switch result {
                case .success(let urls):
                    let ticket = importID
                    runImport(ticket: ticket) { try await Task.detached { try AttachmentFileReader.readMany(urls) }.value }
                case .failure: errorMessage = "The file picker could not open those files. Please try again."
                }
            }
            .photosPicker(isPresented: $showsPhotos, selection: $photos, maxSelectionCount: max(1, 5 - chat.attachments.count), matching: .images, preferredItemEncoding: .compatible)
            .onChange(of: photos) { _, items in
                guard !items.isEmpty else { return }
                let ticket = importID
                runImport(ticket: ticket) {
                    guard items.count <= 5 else { throw AttachmentError.tooMany }
                    var files: [ChatAttachment] = []
                    for item in items {
                        guard let imported = try await item.loadTransferable(type: ImportedPhoto.self) else { throw AttachmentError.invalidFile }
                        files.append(imported.file)
                        guard files.reduce(0, { $0 + $1.data.count }) <= 20 * 1_024 * 1_024 else { throw AttachmentError.tooLarge }
                    }
                    return files
                }
            }
            .overlay(alignment: .top) {
                if importing { Label("Preparing attachments…", systemImage: "paperclip").font(.caption).padding(10).background(.regularMaterial, in: Capsule()).accessibilityIdentifier("attachmentImportStatus") }
            }
            .alert("Attachment unavailable", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onChange(of: ObjectIdentifier(chat)) { _, _ in invalidate() }
            .onChange(of: chat.selectedContext) { _, _ in invalidate() }
            .onChange(of: scenePhase) { _, phase in if phase == .background { invalidate() } }
            .onDisappear { invalidate() }
    }
    private func beginSelection() { targetSession = ObjectIdentifier(chat); targetContext = chat.selectedContext; importID = UUID(); photos = [] }
    private func invalidate() {
        if let preparationToken { preparingSession?.endAttachmentPreparation(preparationToken) }
        preparationToken = nil; preparingSession = nil
        targetSession = nil; importID = UUID(); importing = false; showsFiles = false; showsPhotos = false; photos = [] }
    private func runImport(ticket: UUID, load: @escaping @Sendable () async throws -> [ChatAttachment]) {
        guard !importing, let reservation = chat.beginAttachmentPreparation() else { return }
        let owner = chat
        preparationToken = reservation; preparingSession = owner
        importing = true
        Task { @MainActor in
            defer {
                owner.endAttachmentPreparation(reservation)
                if preparationToken == reservation { preparationToken = nil; preparingSession = nil }
            }
            do {
                let files = try await load()
                guard ticket == importID, targetSession == ObjectIdentifier(chat), chat.selectedContext == targetContext else { return }
                try await chat.addAttachments(files)
            } catch {
                guard ticket == importID else { return }
                errorMessage = (error as? AttachmentError)?.errorDescription ?? "The attachment could not be saved on this device. Your existing draft is kept."
            }
            guard ticket == importID else { return }
            importing = false; photos = []
        }
    }
}

private struct ImportedPhoto: Transferable, Sendable {
    let file: ChatAttachment
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            ImportedPhoto(file: try AttachmentFileReader.read(received.file))
        }
    }
}

private enum AttachmentFileReader {
    static func readMany(_ urls: [URL]) throws -> [ChatAttachment] {
        guard urls.count <= 5 else { throw AttachmentError.tooMany }
        var files: [ChatAttachment] = []
        for url in urls {
            let file = try read(url)
            guard files.reduce(0, { $0 + $1.data.count }) + file.data.count <= 20 * 1_024 * 1_024 else { throw AttachmentError.tooLarge }
            files.append(file)
        }
        return files
    }
    static func read(_ url: URL) throws -> ChatAttachment {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentTypeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw AttachmentError.invalidFile }
        guard let size = values.fileSize, size <= ChatAttachment.maximumBytes else { throw AttachmentError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: ChatAttachment.maximumBytes + 1) ?? Data()
        return try ChatAttachment(name: url.lastPathComponent, contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream", data: data)
    }
}
