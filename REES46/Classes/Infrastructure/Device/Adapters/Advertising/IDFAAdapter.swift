import AdSupport
import AppTrackingTransparency
import Foundation

public final class IDFAAdapter: AdvertisingIdPort {

    public func getAdvertisingId(completion: @escaping (AdvertisingId?) -> Void) {
        DispatchQueue.main.async {
            let status = ATTrackingManager.trackingAuthorizationStatus
            switch status {
            case .notDetermined:
                ATTrackingManager.requestTrackingAuthorization { newStatus in
                    self.handleAuthorizationStatus(newStatus, completion: completion)
                }
            default:
                self.handleAuthorizationStatus(status, completion: completion)
            }
        }
    }

    private func handleAuthorizationStatus(_ status: ATTrackingManager.AuthorizationStatus, completion: @escaping (AdvertisingId?) -> Void) {
        guard status == .authorized else {
            completion(nil)
            return
        }
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        completion(idfa != NullIDFA ? AdvertisingId(value: idfa) : nil)
    }
}
