
import Foundation

protocol PushTokenNotificationService {
    func setPushToken(
        token: String,
        isFirebaseNotification: Bool,
        completion: @escaping (Result<Void, SDKError>) -> Void
    )
}
