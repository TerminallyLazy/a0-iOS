/// Foreground audio intent is exclusive across inline players and composer voice.
@MainActor protocol NativeAudioParticipant:AnyObject {
    func relinquishAudio()
}

@MainActor enum NativeAudioOwnership {
    private static weak var owner:(any NativeAudioParticipant)?
    static func owns(_ participant:any NativeAudioParticipant)->Bool { owner === participant }
    static func claim(_ participant:any NativeAudioParticipant) {
        guard owner !== participant else { return }
        owner?.relinquishAudio()
        owner = participant
    }
    /// Only the current participant may deactivate the shared system session.
    @discardableResult static func release(_ participant:any NativeAudioParticipant)->Bool {
        guard owner === participant else { return false }
        owner = nil
        return true
    }
}
