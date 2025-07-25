import AdSupport
import AppTrackingTransparency
import Foundation

public final class IDFAAdapter: AdvertisingIdPort {

    public init() {}

    public func getAdvertisingId(completion: @escaping (String?) -> Void) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                guard status == .authorized else {
                    completion(nil)
                    return
                }

                let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                let isValid = idfa != NullIDFA
                completion(isValid ? idfa : nil)
            }
        } else {
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
                let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                let isValid = idfa != NullIDFA
                completion(isValid ? idfa : nil)
            } else {
                completion(nil)
            }
        }
    }
}
