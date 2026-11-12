
import Foundation
import UIKit

class PushTokenNotificationServiceImpl: PushTokenNotificationServiceProtocol {
    
    private let sdk: SimplePersonalizationSDK
    private let sessionQueue: SessionQueue

    init(sdk: SimplePersonalizationSDK, sessionQueue: SessionQueue) {
        self.sdk = sdk
        self.sessionQueue = sessionQueue
    }

    func setPushToken(token: String, isFirebaseNotification: Bool, completion: @escaping (Result<Void, SdkError>) -> Void) {
        sessionQueue.addOperation {
            var params = [
                "shop_id": self.sdk.shopId,
                "did": self.sdk.deviceId,
                "token": token
            ]

            params["platform"] = isFirebaseNotification ? "ios_firebase" : "ios"

            self.sdk.postRequest(path: "mobile_push_tokens", params: params, timeout: 1) { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
}
