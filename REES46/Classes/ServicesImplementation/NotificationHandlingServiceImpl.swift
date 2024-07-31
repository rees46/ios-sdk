import Foundation

class NotificationHandlerServiceImpl: NotificationHandlingService {
    
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
    }
    
    private func configureSession(timeOut: Double? = 1) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
        sessionConfig.waitsForConnectivity = true
        sessionConfig.shouldUseExtendedBackgroundIdleMode = true
        sdk?.configureURLSession(configuration: sessionConfig)
    }
    
    private func getRequest(
        path: String,
        params: [String: String],
        completion: @escaping (Result<[String: Any], SDKError>) -> Void
    ) {
        sdk?.getRequest(path: path, params: params, false) { result in
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
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        sdk?.postRequest(path: path, params: params) { result in
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
        completion: @escaping(Result<UserPayloadResponse, SDKError>) -> Void
    ) {
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            let params = self.createParams(
                type: type,
                phone: phone,
                email: email,
                userExternalId: userExternalId,
                userLoyaltyId: userLoyaltyId,
                channel: channel,
                limit: limit,
                page: page,
                dateFrom: dateFrom
            )
            
            self.configureSession()
            
            self.getRequest(path: Constants.notificationPath, params: params) { result in
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
        completion: @escaping (Result<Void, SDKError>) -> Void
    ){
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            let params: [String: String] = [
                "shop_id": sdk.shopId,
                "did": sdk.deviceId,
                "code": code,
                "type": type
            ]
            
            self.configureSession()
            
            self.postRequest(path: path, params: params, completion: completion)
        }
    }
}
