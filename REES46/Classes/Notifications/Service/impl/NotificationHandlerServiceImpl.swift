import Foundation

class NotificationHandlerServiceImpl: NotificationHandlerServiceProtocol {
    
    private var sdk: PersonalizationSDK?
    private let sessionQueue: SessionQueue
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private struct Constants {
        static let notificationPath = "notifications"
        static let shopId = "shop_id"
        static let did = "did"
        static let seance = "seance"
        static let sid = "sid"
        static let segment = "segment"
        static let type = "type"
        static let email = "email"
        static let phone = "phone"
        static let externalId = "external_id"
        static let loyaltyId = "loyalty_id"
        static let channel = "channel"
        static let limit = "limit"
        static let page = "page"
        static let shopSecret = "shop_secret"
        static let dateFrom = "date_from"
    }
    
    private func getRequest(
        path: String,
        params: [String: String],
        timeout: TimeInterval?,
        completion: @escaping (Result<[String: Any], SdkError>) -> Void
    ) {
        sdk?.getRequest(path: path, params: params, timeout: timeout) { result in
            switch result {
            case let .success(successResult):
                completion(.success(successResult))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    private func postRequest(
        path: String,
        params: [String: String],
        timeout: TimeInterval?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        sdk?.postRequest(path: path, params: params, timeout: timeout) { result in
            switch result {
            case .success:
                completion(.success(Void()))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    private func createParams(
        type: String,
        shopSecret: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        userExternalId: String? = nil,
        userLoyaltyId: String? = nil,
        channel: String? = nil,
        limit: Int? = nil,
        page: Int? = nil,
        dateFrom: String? = nil
    ) -> [String: String] {
        var params = [
            Constants.shopId: sdk?.shopId ?? "",
            Constants.did: sdk?.deviceId ?? "",
            Constants.seance: sdk?.userSeance ?? "",
            Constants.sid: sdk?.userSeance ?? "",
            Constants.segment: sdk?.segment ?? "",
            Constants.type: type,
        ]
        
        if let userPhone = phone {
            params[Constants.phone] = userPhone
        }
        if let userEmail = email {
            params[Constants.email] = userEmail
        }
        if let userExternalId = userExternalId {
            params[Constants.externalId] = userExternalId
        }
        if let userLoyaltyId = userLoyaltyId {
            params[Constants.loyaltyId] = userLoyaltyId
        }
        if let channel = channel {
            params[Constants.channel] = channel
        }
        if let limit = limit {
            params[Constants.limit] = String(limit)
        }
        if let page = page {
            params[Constants.page] = String(page)
        }
        if let dateFrom = dateFrom {
            params[Constants.dateFrom] = dateFrom
        }
        if let shopSecret = shopSecret {
            params[Constants.shopSecret] = shopSecret
        }
        
        return params
    }
    
    func getAllNotifications(
        type: String,
        phone: String? = nil,
        email: String? = nil,
        userExternalId: String? = nil,
        userLoyaltyId: String? = nil,
        channel: String? = nil,
        limit: Int? = nil,
        page: Int? = nil,
        dateFrom: String? = nil,
        completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void
    ) {
        loadNotifications(
            shopSecret: nil,
            type: type,
            phone: phone,
            email: email,
            userExternalId: userExternalId,
            userLoyaltyId: userLoyaltyId,
            channel: channel,
            limit: limit,
            page: page,
            dateFrom: dateFrom,
            completion: completion
        )
    }

    func getAllNotifications(
        shopSecret: String,
        type: String,
        phone: String? = nil,
        email: String? = nil,
        userExternalId: String? = nil,
        userLoyaltyId: String? = nil,
        channel: String? = nil,
        limit: Int? = nil,
        page: Int? = nil,
        dateFrom: String? = nil,
        completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void
    ) {
        loadNotifications(
            shopSecret: shopSecret,
            type: type,
            phone: phone,
            email: email,
            userExternalId: userExternalId,
            userLoyaltyId: userLoyaltyId,
            channel: channel,
            limit: limit,
            page: page,
            dateFrom: dateFrom,
            completion: completion
        )
    }

    private func loadNotifications(
        shopSecret: String?,
        type: String,
        phone: String?,
        email: String?,
        userExternalId: String?,
        userLoyaltyId: String?,
        channel: String?,
        limit: Int?,
        page: Int?,
        dateFrom: String?,
        completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void
    ) {
        guard sdk != nil else { return }
        
        sessionQueue.addOperation {
            let params = self.createParams(
                type: type,
                shopSecret: shopSecret,
                phone: phone,
                email: email,
                userExternalId: userExternalId,
                userLoyaltyId: userLoyaltyId,
                channel: channel,
                limit: limit,
                page: page,
                dateFrom: dateFrom
            )
            
            self.getRequest(path: Constants.notificationPath, params: params, timeout: nil) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let result = UserPayloadResponse(json: resJSON)
                    completion(.success(result))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func trackNotification(
        path: String,
        type: String,
        code: String,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ){
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            let params: [String: String] = [
                "shop_id": sdk.shopId,
                "did": sdk.deviceId,
                "code": code,
                "type": type
            ]
            
            self.postRequest(path: path, params: params, timeout: nil, completion: completion)
        }
    }
}
