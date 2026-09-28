import Foundation
import Testing
@testable import A0Core

@Test func pollRecoveryBacksOffAndStopsAtFourRetries() {
    var policy = PollRecoveryPolicy()
    for seconds in [1.0, 2.0, 4.0, 8.0] {
        #expect(policy.failure(URLError(.networkConnectionLost),jitter:0) == .retry(after:.seconds(seconds)))
    }
    #expect(policy.failure(URLError(.timedOut),jitter:0) == .paused)
    policy.reset()
    #expect(policy.failure(ClientError.httpStatus(503),jitter:0) == .retry(after:.seconds(1)))
}
@Test func pollRecoveryJitterIsBounded() {
    var low = PollRecoveryPolicy(), high = PollRecoveryPolicy()
    #expect(low.failure(URLError(.timedOut),jitter:-1) == .retry(after:.seconds(1)))
    #expect(high.failure(URLError(.timedOut),jitter:2) == .retry(after:.seconds(1.25)))
}
@Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed])
func transientNetworkFailuresCanRetry(_ code: URLError.Code) {
    var policy = PollRecoveryPolicy()
    #expect(policy.failure(URLError(code),jitter:0) == .retry(after:.seconds(1)))
}
@Test(arguments: [500, 502, 503, 504])
func transientServerFailuresCanRetry(_ status: Int) {
    var policy = PollRecoveryPolicy()
    #expect(policy.failure(ClientError.httpStatus(status),jitter:0) == .retry(after:.seconds(1)))
}
@Test(arguments: [URLError.Code.cancelled, .serverCertificateUntrusted, .secureConnectionFailed, .userAuthenticationRequired, .badURL])
func certificateAuthenticationAndCancellationNeverRetry(_ code: URLError.Code) {
    var policy = PollRecoveryPolicy()
    #expect(policy.failure(URLError(code),jitter:0) == .stop)
}
@Test(arguments: [ClientError.requiresLogin, .csrfRejected, .incompatiblePayload, .unexpectedResponse, .httpStatus(401), .httpStatus(403), .httpStatus(429), .httpStatus(404)])
func protocolAndSecurityFailuresNeverRetry(_ error: ClientError) {
    var policy = PollRecoveryPolicy()
    #expect(policy.failure(error,jitter:0) == .stop)
}
@Test func unknownErrorsNeverRetry() {
    var policy = PollRecoveryPolicy()
    #expect(policy.failure(PersistenceError.writeFailed,jitter:0) == .stop)
}
@Test func recoveryRetainsDisplayButInvalidatesCursorsAndStaleResponses() throws {
    var state = SyncReducer()
    let old = state.select(context:"synthetic-chat")
    let full = try snapshot()
    _ = state.apply(snapshot:full,generation:old,full:true)
    let logs = state.logs
    state.invalidateForRecovery()
    #expect(state.logs == logs)
    #expect(state.context == "synthetic-chat")
    #expect(state.generation != old)
    #expect(state.request.logFrom == 0 && state.request.notificationsFrom == 0)
    #expect(state.needsFullSync)
    #expect(state.apply(snapshot:full,generation:old,full:true) == .ignored)
    #expect(state.apply(snapshot:try snapshot("delta"),generation:state.generation,full:false) == .needsFullSync)
    #expect(state.apply(snapshot:full,generation:state.generation,full:true) == .applied)
    #expect(!state.needsFullSync)
}
