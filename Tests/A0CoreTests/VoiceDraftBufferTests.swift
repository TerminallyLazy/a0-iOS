import Testing
@testable import A0Core

struct VoiceDraftBufferTests {
    @Test func partialsReplaceInsteadOfDuplicating() {
        var buffer = VoiceDraftBuffer()
        buffer.update("weather")
        buffer.update("weather tomorrow")
        #expect(buffer.text == "weather tomorrow")
        buffer.finishSegment()
        buffer.update("in Bloomington")
        #expect(buffer.text == "weather tomorrow in Bloomington")
    }
    @Test func finalSegmentAndStopAreIdempotent() {
        var buffer = VoiceDraftBuffer()
        buffer.update("Hello")
        buffer.finishSegment()
        buffer.finishSegment()
        #expect(buffer.appending(to: "Existing draft") == "Existing draft\n\nHello")
        #expect(buffer.appending(to: "") == "Hello")
    }
    @Test func emptySpeechPreservesDraftAndTextIsBounded() {
        var buffer = VoiceDraftBuffer()
        #expect(buffer.appending(to: "Original") == "Original")
        buffer.update(String(repeating: "x", count: 20_000))
        #expect(buffer.text.count == VoiceDraftBuffer.limit)
        buffer.finishSegment()
        buffer.update("more")
        #expect(buffer.text.count == VoiceDraftBuffer.limit)
    }
}
