
import Foundation

protocol PushTokenHandlingService {
    func setPushToken(
        token: String,
        isFirebaseNotification: Bool,
        completion: @escaping (Result<Void, SDKError>) -> Void
    )
}
