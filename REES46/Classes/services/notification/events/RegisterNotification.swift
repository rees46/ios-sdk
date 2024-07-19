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
    
    func registerWithDeviceToken(deviceToken: Data) {
        guard let sdk = sdk as? SimplePersonalizationSDK,
              sdk.autoSendPushToken == true
        else {
            // If autoSendPushToken is false, do nothing
            return
        }
        
        if let pushTokenLastUpdateDate = UserDefaults.standard.object(forKey: Constants.mainPushTokenLastUploadDateKey) as? Date {
            let currentDate = Date()
            let timeSincePushTokenLastUpdate = currentDate.timeIntervalSince(pushTokenLastUpdateDate)
            guard timeSincePushTokenLastUpdate >= Constants.oneWeekInSeconds else {
                // Token was sent within the last week; no need to send again
                return
            }
        }
        
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        sdk.setPushTokenNotification(token: token) { [weak self] tokenResponse in
            guard let self = self else { return }
            switch tokenResponse {
            case .success():
                UserDefaults.standard.setValue(Date(), forKey: Constants.mainPushTokenLastUploadDateKey)
            case .failure(let error):
                self.handleRegistrationError(error)
            }
        }
    }
    
    private func handleRegistrationError(_ error: SDKError) {
        switch error {
        case let .custom(customError):
            print("SDK Push Token Error:", customError)
        default:
            print("SDK Push Token server error: \(error.description)\n")
        }
    }
}
