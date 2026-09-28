import Foundation

public enum AttachmentError: Error, Sendable, Equatable, LocalizedError {
    case invalidFile, tooLarge, tooMany, unsupported, storageFull
    public var errorDescription: String? {
        switch self {
        case .invalidFile: "This file could not be attached. Choose a regular, readable file."
        case .tooLarge: "Choose files under 10 MB each and 20 MB total per message."
        case .tooMany: "Attach up to 5 files per message."
        case .unsupported: "Attachments are unavailable for this connection."
        case .storageFull: "Local attachments are full. Remove unused draft attachments before adding more."
        }
    }
}

/// Transient bytes, only loaded for explicit import or Send. Archives contain metadata instead.
public struct ChatAttachment: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let contentType: String
    public let data: Data
    public static let maximumBytes = 10 * 1_024 * 1_024
    public init(id: UUID = UUID(), name: String, contentType: String, data: Data) throws {
        guard !name.isEmpty, name.count <= 255, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !contentType.isEmpty, contentType.count <= 100,
              contentType.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "/-+._".contains($0)) }), contentType.contains("/") else { throw AttachmentError.invalidFile }
        guard data.count <= Self.maximumBytes else { throw AttachmentError.tooLarge }
        self.id = id; self.name = name; self.contentType = contentType; self.data = data
    }
    public var staged: StagedAttachment { StagedAttachment(id: id, name: name, contentType: contentType, byteCount: data.count) }
    public var uploadName: String { staged.uploadName }
}

public struct StagedAttachment: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let contentType: String
    public let byteCount: Int
    public var uploadName: String {
        let safe = name.map { $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0)) ? $0 : "_" }
        var basename = String(safe.prefix(120))
        while basename.hasSuffix(".") { basename.removeLast() }
        return id.uuidString + "-" + (basename.isEmpty ? "file" : basename)
    }
}

public struct AttachmentMultipart: Sendable {
    public let contentType: String
    public let data: Data
    public init(fields: [(String, String)], files: [ChatAttachment], fileField: String) throws {
        guard files.count <= 5 else { throw AttachmentError.tooMany }
        guard files.reduce(0, { $0 + $1.data.count }) <= 20 * 1_024 * 1_024 else { throw AttachmentError.tooLarge }
        guard ["file", "attachments"].contains(fileField), fields.allSatisfy({ ["text", "context", "message_id"].contains($0.0) }) else { throw AttachmentError.invalidFile }
        let boundary = "A0-" + UUID().uuidString
        self.contentType = "multipart/form-data; boundary=" + boundary
        var result = Data()
        func append(_ string: String) { result.append(Data(string.utf8)) }
        for (key, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
        }
        for file in files {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(file.uploadName)\"\r\nContent-Type: \(file.contentType)\r\n\r\n")
            result.append(file.data); append("\r\n")
        }
        append("--\(boundary)--\r\n"); self.data = result
    }
}

extension APIClient {
    /// Selection never uploads. The caller persists the delivery before entering this mutation sequence.
    public func sendAttachments(context: String, text: String, messageID: String, queued: Bool, attachments: [ChatAttachment]) async throws {
        _ = try socketSession()
        if queued {
            let multipart = try AttachmentMultipart(fields: [], files: attachments, fileField: "file")
            let upload = try await attachmentCommand("/api/upload", body: multipart.data, contentType: multipart.contentType)
            struct Uploaded: Decodable { let filenames: [String] }
            let uploaded: Uploaded = try decode(upload.data)
            guard uploaded.filenames == attachments.map(\.uploadName) else { throw ClientError.incompatiblePayload }
            struct Queue: Encodable { let context: String; let text: String; let item_id: String; let attachments: [String] }
            let payload = Queue(context: context, text: text, item_id: messageID, attachments: uploaded.filenames)
            let response = try await attachmentCommand("/api/message_queue_add", body: JSONEncoder().encode(payload), contentType: "application/json")
            struct Queued: Decodable { let ok: Bool; let item_id: String }
            let ack: Queued = try decode(response.data)
            guard ack.ok, ack.item_id == messageID else { throw ClientError.incompatiblePayload }
        } else {
            let body = try AttachmentMultipart(fields: [("context", context), ("text", text), ("message_id", messageID)], files: attachments, fileField: "attachments")
            let response = try await attachmentCommand("/api/message_async", body: body.data, contentType: body.contentType)
            struct Accepted: Decodable { let context: String }
            let ack: Accepted = try decode(response.data)
            guard ack.context == context else { throw ClientError.incompatiblePayload }
        }
    }
    private func attachmentCommand(_ path: String, body: Data, contentType: String) async throws -> HTTPResponse {
        _ = try socketSession()
        let response = try await request(path, method: "POST", body: body, contentType: contentType)
        if isLoginRedirect(response) || response.status == 401 { disconnect(); throw ClientError.requiresLogin }
        if response.status == 403 { disconnect(); throw ClientError.csrfRejected }
        try validate(response); return response
    }
}
