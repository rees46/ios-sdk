import Foundation
import UserNotifications
import UIKit

public protocol NotificationServiceProtocol {
    func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data)
    func didReceiveRemoteNotifications(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult, String) -> Void
    )
    func didReceiveRegistrationFCMToken(fcmToken: String?)
    func didReceiveDeepLink(url: URL)
    
    var pushActionDelegate: NotificationActionsProtocol? { get set }
}
