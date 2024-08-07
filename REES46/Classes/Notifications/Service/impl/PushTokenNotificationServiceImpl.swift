
import Foundation
import UIKit

class PushTokenNotificationServiceImpl: PushTokenNotificationServiceProtocol {
    
    private let sdk: SimplePersonalizationSDK
    private let sessionQueue: SessionQueue

    init(sdk: SimplePersonalizationSDK, sessionQueue: SessionQueue) {
        self.sdk = sdk
        self.sessionQueue = sessionQueue
    }

    func setPushToken(token: String, isFirebaseNotification: Bool, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            var params = [
                "shop_id": self.sdk.shopId,
                "did": self.sdk.deviceId,
                "token": token
            ]

            params["platform"] = isFirebaseNotification ? "ios_firebase" : "ios"

            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true

            self.sdk.urlSession = URLSession(configuration: sessionConfig)
            self.sdk.postRequest(path: "mobile_push_tokens", params: params) { result in
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
