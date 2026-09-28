import Testing
@testable import A0Core

struct ConnectionIndicatorTests {
    @Test func liveIsGreenOnlyWhenStateIsCurrent() {
        #expect(ConnectionIndicator(status:"Live",ready:true,synchronizing:false).tone == .live)
        #expect(ConnectionIndicator(status:"Live",ready:false,synchronizing:true).tone == .working)
    }
    @Test func pollingAndRetryDoNotPretendToBeLive() {
        #expect(ConnectionIndicator(status:"Polling",ready:true,synchronizing:false).tone == .polling)
        #expect(ConnectionIndicator(status:"Checking realtime",ready:true,synchronizing:false).tone == .polling)
        #expect(ConnectionIndicator(status:"Reconnecting",ready:false,synchronizing:true).tone == .working)
    }
    @Test func unavailableAndStoppedRecoveryAreDistinct() {
        #expect(ConnectionIndicator(status:"Not connected",ready:false,synchronizing:false).tone == .offline)
        #expect(ConnectionIndicator(status:"Sync paused",ready:false,synchronizing:true).tone == .attention)
    }
}
