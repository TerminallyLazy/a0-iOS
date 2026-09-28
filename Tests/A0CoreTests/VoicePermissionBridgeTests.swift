import Foundation
import Testing
@testable import A0Core

struct VoicePermissionBridgeTests {
    @Test @MainActor func authorizationCallbackCanArriveOnBackgroundQueue() async {
        // TCC delivers the physical-device Speech authorization callback here,
        // even when Listen began on MainActor. This must not assert its executor.
        let result = await VoicePermissionBridge.request { completion in
            DispatchQueue.global(qos: .default).async { completion(true) }
        }
        #expect(result)
    }

    @Test @MainActor func denialArrivesWithoutChangingItsMeaning() async {
        let result = await VoicePermissionBridge.request { completion in
            DispatchQueue.global(qos: .default).async { completion(false) }
        }
        #expect(!result)
    }
}
