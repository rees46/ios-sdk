
import Foundation

class PushTokenHandlerServiceImpl: PushTokenNotificationServiceProtocol {
    
    private var sdk: PersonalizationSDK?
    private let sessionQueue: SessionQueue
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private struct Constants {
        static let mobilePushTokensPath = "mobile_push_tokens"
        static let shopId = "shop_id"
        static let did = "did"
        static let iosFirebase = "ios_firebase"
        static let ios = "ios"
        static let platform = "platform"
        static let token = "token"
    }
    
    func setPushToken(
        token: String,
        isFirebaseNotification: Bool = false,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "setPushToken: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            // The token never goes out without a device id: the SDK keeps it until /init stores one.
            let deviceId = sdk.deviceId
            guard !deviceId.isEmpty else {
                (sdk as? SimplePersonalizationSDK)?.deferPushToken(.direct(token: token, isFirebase: isFirebaseNotification))
                completion(.failure(.pushTokenWaitsForDeviceId))
                return
            }
            var params = [
                Constants.shopId: sdk.shopId,
                Constants.did: deviceId,
                Constants.token: token
            ]
            
            if isFirebaseNotification {
                params[Constants.platform] = Constants.iosFirebase
            } else {
                params[Constants.platform] = Constants.ios
            }
            
            sdk.postRequest(
                path: Constants.mobilePushTokensPath, params: params, timeout: nil, completion: { result in
                    switch result {
                    case .success:
                        completion(.success(Void()))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }
    }
}
