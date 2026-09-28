/// The local preference for sending follow-ups to an agent that is still working.
/// Queue uses the server queue; Steer submits immediately through the ordinary message endpoint.
public enum SendMode: String, CaseIterable, Sendable {
    case queue, steer

    public init(preference: String?) {
        self = preference.flatMap(Self.init(rawValue:)) ?? .queue
    }

    public func shouldQueue(isBusy: Bool, hasQueue: Bool) -> Bool {
        self == .queue && (isBusy || hasQueue)
    }
}
