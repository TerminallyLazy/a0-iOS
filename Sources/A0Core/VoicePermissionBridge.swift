/// Legacy permission APIs may complete on arbitrary queues. Both closures are
/// explicitly Sendable so a caller on MainActor cannot lend them its executor.
public enum VoicePermissionBridge {
    public nonisolated static func request(
        using register: @Sendable (@escaping @Sendable (Bool) -> Void) -> Void
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            register { @Sendable allowed in continuation.resume(returning: allowed) }
        }
    }
}
