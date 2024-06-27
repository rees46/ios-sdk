import Foundation
import UIKit

class NotificationHandler{
    
    private weak var sdk: SimplePersonalizationSDK?
    private let sessionQueue: SessionQueue
    
    init(sdk: SimplePersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private struct Constants {
        static let mobilePushTokensPath = "mobile_push_tokens"
        static let notificationPath = "notifications"
        
        static let shopId = "shop_id"
        static let did = "did"
        static let seance = "seance"
        static let sid = "sid"
        static let segment = "segment"
        static let itemId = "item_id"
        static let email = "email"
        static let phone = "phone"
        static let type = "type"
        static let token = "token"
        static let iosFirebase = "ios_firebase"
        static let ios = "ios"
        static let platform = "platform"
        static let externalId = "external_id"
        static let loyaltyId = "loyalty_id"
        static let channel = "channel"
        static let limit = "limit"
        static let page = "page"
    }
    
    func setPushTokenNotification(
        token: String,
        isFirebaseNotification: Bool = false,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard let sdk = sdk else { return }
        
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
            
            sdk.urlSession = URLSession(configuration: sessionConfig)
            sdk.postRequest(path: Constants.mobilePushTokensPath, params: params, completion: { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func getAllNotifications(type: String, phone: String? = nil, email: String? = nil, userExternalId: String? = nil, userLoyaltyId: String? = nil, channel: String?, limit: Int?, page: Int?, dateFrom: String?, completion: @escaping(Result<UserPayloadResponse, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            var params = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment,
                Constants.type: type,
            ]
            
            if let userPhone = phone {
                params[Constants.phone] = String(userPhone)
            }
            if let userEmail = email {
                params[Constants.phone] = String(userEmail)
            }
            if let userExternalId = userExternalId {
                params[Constants.externalId] = String(userExternalId)
            }
            if let userLoyaltyId = userLoyaltyId {
                params[Constants.loyaltyId] = String(userLoyaltyId)
            }
            if let channel = channel {
                params[Constants.channel] = String(channel)
            }
            if let limit = limit {
                params[Constants.limit] = String(limit)
            }
            if let page = page {
                params[Constants.page] = String(page)
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sdk.urlSession = URLSession(configuration: sessionConfig)
            
            sdk.getRequest(path: Constants.notificationPath, params: params, completion: { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let result = UserPayloadResponse(json: resJSON)
                    completion(.success(result))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
}
