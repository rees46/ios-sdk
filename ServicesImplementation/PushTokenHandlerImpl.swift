
import Foundation

class PushTokenHandlerServiceImpl: PushTokenHandlingService {
    
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
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "setPushToken: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            var params = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.token: token
            ]
            
            if isFirebaseNotification {
                params[Constants.platform] = Constants.iosFirebase
            } else {
                params[Constants.platform] = Constants.ios
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            
            sdk.configureURLSession(configuration: sessionConfig)
            sdk.postRequest(
                path: Constants.mobilePushTokensPath, params: params, completion: { result in
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
