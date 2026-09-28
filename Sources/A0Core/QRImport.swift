import Foundation

/// The existing Agent Zero tunnel QR contains a plain URL, never credentials.
public struct QRDestination: Equatable, Sendable {
    public let origin: ServerOrigin
    public init(_ payload: String) throws {
        let text = payload.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.count <= 2048,
              text.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }),
              !text.contains("%"), !text.contains("\\"),
              let origin = try? ServerOrigin(text) else { throw QRImportIssue.invalidCode }
        self.origin = origin
    }
}

public enum QRImportIssue: Error, Equatable, Sendable {
    case invalidCode, cameraDenied, cameraUnavailable
    public var message: String {
        switch self {
        case .invalidCode: "Use a plain HTTPS server address without credentials, a path, query, or fragment. For international domains, use the ASCII (punycode) address."
        case .cameraDenied: "Camera access is off. Allow access in Settings, or enter the server address below."
        case .cameraUnavailable: "QR scanning is unavailable on this device right now. Enter the server address below."
        }
    }
}

/// Transient review state only: no network, credential lookup, or persistence.
public struct QRImportSession: Sendable {
    public private(set) var destination: QRDestination?
    public private(set) var issue: QRImportIssue?
    public private(set) var scanID: UUID?
    public init() {}
    public mutating func beginScan() -> UUID {
        cancel()
        let id = UUID(); scanID = id; return id
    }
    public mutating func receive(_ payload: String, from id: UUID) {
        guard scanID == id else { return }
        review(payload)
    }
    public mutating func failCamera(_ issue: QRImportIssue, from id: UUID) {
        guard scanID == id else { return }
        scanID = nil; self.issue = issue
    }
    public mutating func review(_ payload: String) {
        cancel()
        do { destination = try QRDestination(payload) }
        catch { issue = .invalidCode }
    }
    public mutating func confirm() -> QRDestination? {
        let result = destination
        cancel(); return result
    }
    public mutating func cancel() { destination = nil; issue = nil; scanID = nil }
}
