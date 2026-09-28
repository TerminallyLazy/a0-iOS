import Foundation

public enum PollRecoveryAction: Equatable, Sendable {
    case retry(after: Duration), paused, stop
}

/// Only for foreground snapshot reads. Never apply this policy to commands or login.
public struct PollRecoveryPolicy: Sendable {
    public private(set) var attempts = 0
    public init() {}
    public mutating func reset() { attempts = 0 }
    public mutating func failure(_ error: any Error, jitter: Double = Double.random(in:0...1)) -> PollRecoveryAction {
        guard Self.isTransient(error) else { return .stop }
        guard attempts < 4 else { return .paused }
        let seconds = Double(1 << attempts)
        attempts += 1
        let boundedJitter = jitter.isFinite ? min(1,max(0,jitter)) : 0
        return .retry(after:.seconds(seconds * (1 + boundedJitter * 0.25)))
    }
    private static func isTransient(_ error: any Error) -> Bool {
        if let url = error as? URLError {
            return [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                    .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(url.code)
        }
        if case ClientError.httpStatus(let status) = error {
            return [500,502,503,504].contains(status)
        }
        return false
    }
}
