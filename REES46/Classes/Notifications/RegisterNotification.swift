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

    func registerWithDeviceToken(deviceToken: Data) {
        if let pushTokenLastUpdateDate = UserDefaults.standard.object(forKey: lastUploadDateKey) as? Date {
            let currentDate = Date()
            let timeSincePushTokenLastUpdate = currentDate.timeIntervalSince(pushTokenLastUpdateDate)
            guard timeSincePushTokenLastUpdate >= Constants.oneWeekInSeconds else {
                // Token was sent within the last week; no need to send again
                let nextPossibleSendDate = pushTokenLastUpdateDate.addingTimeInterval(Constants.oneWeekInSeconds)
#if DEBUG
                print("Push token already sent recently. Next possible send date: \(nextPossibleSendDate)")
#endif
                return
            }
        }
        
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        sdk.setPushTokenNotification(token: token) { [weak self] tokenResponse in
            guard let self = self else { return }
            switch tokenResponse {
            case .success():
                let currentDate = Date()
                UserDefaults.standard.setValue(currentDate, forKey: self.lastUploadDateKey)
                let nextPossibleSendDate = currentDate.addingTimeInterval(Constants.oneWeekInSeconds)
#if DEBUG
                print("Push token successfully sent. Last upload date: \(currentDate). Next possible send date: \(nextPossibleSendDate)")
#endif
            case .failure(let error):
                self.handleRegistrationError(error)
            }
        }
    }
    
    private func handleRegistrationError(_ error: SdkError) {
        switch error {
        case let .custom(customError):
            print("SDK Push Token Error:", customError)
        default:
            print("SDK Push Token server error: \(error.description)\n")
        }
    }
}
