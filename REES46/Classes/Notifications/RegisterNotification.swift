import Foundation
import UIKit

class NotificationRegistrar {
    
    private let sdk: PersonalizationSDK
    
    struct Constants {
        static let deviceIdKey = "device_id"
        static let mainPushTokenLastUploadDateKey = "mainPushTokenLastUploadDateKey"
        static let oneWeekInSeconds: TimeInterval = 7 * 24 * 60 * 60
    }
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
    }

    /// Per-shop throttle key: the APNs token is device-global, but each shop uploads it to its own
    /// backend on its own weekly schedule. A single global key let the first shop's upload throttle
    /// every other shop for a week (so their backends never got the token). Namespacing by `shop_id`
    /// makes each initialized instance register the token independently — the iOS analog of Android's
    /// per-shop `PushTokenManager` throttle, and what implicitly fans the token out across shops.
    private var lastUploadDateKey: String {
        "\(Constants.mainPushTokenLastUploadDateKey).\(sdk.shopId)"
    }

    /// Guards the check and the claim of a shop's weekly upload.
    private static let uploadLock = NSLock()

    func registerWithDeviceToken(deviceToken: Data) {
        // Kept for the next launches: with `autoSendPushToken` every shop sends it after its /init.
        UserDefaults.standard.set(deviceToken, forKey: SdkConstants.deviceToken)

        // The week's upload is claimed before it goes out, so two calls at once — the app's token
        // callback and the SDK's own send after /init — send the token once. Written after the
        // answer, the date was lost with a registrar made for one call, and nothing held back.
        let key = lastUploadDateKey
        Self.uploadLock.lock()
        let lastUpload = UserDefaults.standard.object(forKey: key) as? Date
        if let lastUpload = lastUpload, Date().timeIntervalSince(lastUpload) < Constants.oneWeekInSeconds {
            Self.uploadLock.unlock()
#if DEBUG
            print("Push token already sent recently. Next possible send date: \(lastUpload.addingTimeInterval(Constants.oneWeekInSeconds))")
#endif
            return
        }
        UserDefaults.standard.set(Date(), forKey: key)
        Self.uploadLock.unlock()

        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        sdk.setPushTokenNotification(token: token) { tokenResponse in
            switch tokenResponse {
            case .success():
#if DEBUG
                print("Push token successfully sent.")
#endif
            case .failure(let error):
                // Not sent: the claim goes back, and the next call tries again.
                UserDefaults.standard.set(lastUpload, forKey: key)
                Self.handleRegistrationError(error)
            }
        }
    }
    
    private static func handleRegistrationError(_ error: SdkError) {
        switch error {
        case let .custom(customError):
            print("SDK Push Token Error:", customError)
        default:
            print("SDK Push Token server error: \(error.description)\n")
        }
    }
}
