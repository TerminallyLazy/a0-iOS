import Testing
@testable import A0Core

struct VoiceDraftInsertionTests {
    @Test func replacesSpeechPartialsWithoutDuplicatingTypedPrefix() {
        var insertion = VoiceDraftInsertion(draft: "Please check")
        let first = insertion.apply("the weather", to: "Please check")
        #expect(first == "Please check\n\nthe weather")
        #expect(insertion.apply("the weather tomorrow", to: first!) == "Please check\n\nthe weather tomorrow")
    }
    @Test func refusesToOverwriteAnEditOrNewChat() {
        var insertion = VoiceDraftInsertion(draft: "Original")
        _ = insertion.apply("spoken text", to: "Original")
        #expect(insertion.apply("spoken text changed", to: "My manual correction") == nil)
        #expect(insertion.apply("spoken text changed", to: "") == nil)
    }
    @Test func restartingRetainsEarlierDictationAndEmptyResultsDoNotClear() {
        var insertion = VoiceDraftInsertion(draft: "")
        #expect(insertion.apply("", to: "") == "")
        let first = insertion.apply("First thought", to: "")!
        var resumed = VoiceDraftInsertion(draft: first)
        #expect(resumed.apply("Second thought", to: first) == "First thought\n\nSecond thought")
    }
}
