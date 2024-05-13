import Foundation
import UIKit

class NotificationRegistrar {
    private let sdk: PersonalizationSDK
    private let mainPushTokenLastUploadDateKey = "mainPushTokenLastUploadDateKey"

    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
    }

    func registerWithDeviceToken(deviceToken: Data) {
        guard let sdk = sdk as? SimplePersonalizationSDK,
              sdk.autoSendPushToken == true
        else { return }

        if let pushTokenLastUpdateDate = UserDefaults.standard.object(forKey: self.mainPushTokenLastUploadDateKey) as? Date {
            let currentDate = Date()
            let timeSincePushTokenLastUpdate = currentDate.timeIntervalSince(pushTokenLastUpdateDate)
            let oneWeekInSeconds: TimeInterval = 7 * 24 * 60 * 60

            guard timeSincePushTokenLastUpdate >= oneWeekInSeconds else {
                return
            }
        }

        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        sdk.setPushTokenNotification(token: token) { [weak self] tokenResponse in
            guard let self = self else { return }
            switch tokenResponse {
            case .success():
                UserDefaults.standard.setValue(Date(), forKey: self.mainPushTokenLastUploadDateKey)
                return
            case .failure(let error):
                self.handleRegistrationError(error)
            }
        }
    }

    private func handleRegistrationError(_ error: NotificationError) {
        switch error {
        case let .custom(customError):
            print("SDK Push Token Error:", customError)
        default:
            print("SDK Push Token server, \(error.description)\n")
        }
    }
}
