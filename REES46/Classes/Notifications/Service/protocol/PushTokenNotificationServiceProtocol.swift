import Foundation

protocol PushTokenNotificationServiceProtocol {
    func setPushToken(
        token: String,
        isFirebaseNotification: Bool,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )

    /// The bridges' view of `setPushToken`: a token that waits for the device id is no failure —
    /// `completion` hears the answer once it went.
    func setPushToken(
        token: String,
        isFirebaseNotification: Bool,
        whenSent completion: @escaping (Result<Void, SdkError>) -> Void
    )
}

extension PushTokenNotificationServiceProtocol {
    func setPushToken(
        token: String,
        isFirebaseNotification: Bool,
        whenSent completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        setPushToken(token: token, isFirebaseNotification: isFirebaseNotification, completion: completion)
    }
}
