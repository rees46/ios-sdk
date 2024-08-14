
import Foundation

protocol PushTokenNotificationServiceProtocol {
    func setPushToken(
        token: String,
        isFirebaseNotification: Bool,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )
}
