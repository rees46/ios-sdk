import Foundation
import UserNotifications
import UIKit

public protocol NotificationServicePushDelegate: AnyObject {
    func openCategory(categoryId: String)
    func openProduct(productId: String)
    func openWeb(url: String)
    func openCustom(url: String)
}

public protocol NotificationServiceProtocol {
    func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data)
    func didReceiveRemoteNotifications(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult, String) -> Void
    )
    func didReceiveRegistrationFCMToken(fcmToken: String?)
    func didReceiveDeepLink(url: URL)
    
    var pushActionDelegate: NotificationServicePushDelegate? { get set }
}
