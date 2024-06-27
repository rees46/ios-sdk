import Foundation
import UIKit

class SubscriptionHandler {
    private weak var sdk: SimplePersonalizationSDK?
    private let sessionQueue: SessionQueue
    
    init(sdk: SimplePersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private struct Constants {
        static let subscribeForProductPricePath = "subscriptions/subscribe_for_product_price"
        static let subscribePath = "subscriptions/subscribe_for_product_available"
        static let unsubscribePath = "subscriptions/unsubscribe_from_product_available"
        static let manageSubscriptionPath = "subscriptions/manage"
        
        static let shopId = "shop_id"
        static let did = "did"
        static let seance = "seance"
        static let sid = "sid"
        static let segment = "segment"
        static let itemId = "item_id"
        static let itemIds = "item_ids"
        static let properties = "properties"
        static let fashionSize = "fashion_size"
        static let email = "email"
        static let phone = "phone"
        static let price = "price"
        
        static let externalId = "external_id"
        static let loyaltyId = "loyalty_id"
        static let telegramId = "telegram_id"
        static let emailBulk = "email_bulk"
        static let emailChain = "email_chain"
        static let emailTransactional = "email_transactional"
        static let smsBulk = "sms_bulk"
        static let smsChain = "sms_chain"
        static let smsTransactional = "sms_transactional"
        static let webPushBulk = "web_push_bulk"
        static let webPushChain = "web_push_chain"
        static let webPushTransactional = "web_push_transactional"
        static let mobilePushBulk = "mobile_push_bulk"
        static let mobilePushChain = "mobile_push_chain"
        static let mobilePushTransactional = "mobile_push_transactional"
    }
    
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment,
                Constants.itemId: id,
                Constants.price: currentPrice
            ]
            
            if let email = email {
                params[Constants.email] = email
            }
            
            if let phone = phone {
                params[Constants.phone] = phone
            }
            
            sdk.postRequest(path: Constants.subscribeForProductPricePath, params: params, completion: { result in
                switch result {
                case .success(_):
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func subscribeForBackInStock(id: String, email: String? = nil, phone: String? = nil, fashionSize: [String]? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sdk.sessionQueue.addOperation {
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment,
                Constants.itemId: id
            ]
            
            if let fashionSize = fashionSize {
                let tmpSizesArray = sdk.generateString(array: fashionSize)
                params[Constants.properties] = [Constants.fashionSize: tmpSizesArray]
            }
            
            if let email = email {
                params[Constants.email] = email
            }
            if let phone = phone {
                params[Constants.phone] = phone
            }
            
            sdk.postRequest(path: Constants.subscribePath, params: params, completion: { result in
                switch result {
                case .success(_):
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func unsubscribeForBackInStock(itemIds: [String], email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sdk.sessionQueue.addOperation {
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.itemIds: itemIds
            ]
            
            if let email = email {
                params[Constants.email] = email
            }
            if let phone = phone {
                params[Constants.phone] = phone
            }
            
            sdk.postRequest(path: Constants.unsubscribePath, params: params, completion: { result in
                switch result {
                case .success(_):
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func manageSubscription(email: String? = nil, phone: String? = nil, userExternalId: String? = nil, userLoyaltyId: String? = nil, telegramId: String? = nil, emailBulk: Bool? = nil, emailChain: Bool? = nil, emailTransactional: Bool? = nil, smsBulk: Bool? = nil, smsChain: Bool? = nil, smsTransactional: Bool? = nil, webPushBulk: Bool? = nil, webPushChain: Bool? = nil, webPushTransactional: Bool? = nil, mobilePushBulk: Bool? = nil, mobilePushChain: Bool? = nil, mobilePushTransactional: Bool? = nil, completion: @escaping(Result<Void, SDKError>) -> Void) {
        
        guard let sdk = sdk else { return }
        
        var params: [String: Any] = [
            Constants.shopId: sdk.shopId,
            Constants.did: sdk.deviceId,
            Constants.seance: sdk.userSeance,
            Constants.sid: sdk.userSeance,
            Constants.segment: sdk.segment
        ]
        
        if let email = email {
            params[Constants.email] = email
        }
        if let phone = phone {
            params[Constants.phone] = phone
        }
        
        if let userExternalId          = userExternalId             { params[Constants.externalId]                 = userExternalId }
        if let userLoyaltyId           = userLoyaltyId              { params[Constants.loyaltyId]                  = userLoyaltyId }
        if let telegramId              = telegramId                 { params[Constants.telegramId]                 = telegramId }
        if let emailBulk               = emailBulk                  { params[Constants.emailBulk]                  = emailBulk }
        if let emailChain              = emailChain                 { params[Constants.emailChain]                 = emailChain }
        if let emailTransactional      = emailTransactional         { params[Constants.emailTransactional]         = emailTransactional }
        if let smsBulk                 = smsBulk                    { params[Constants.smsBulk]                    = smsBulk }
        if let smsChain                = smsChain                   { params[Constants.smsChain]                   = smsChain }
        if let smsTransactional        = smsTransactional           { params[Constants.smsTransactional]           = smsTransactional }
        if let webPushBulk             = webPushBulk                { params[Constants.webPushBulk]               = webPushBulk }
        if let webPushChain            = webPushChain               { params[Constants.webPushChain]              = webPushChain }
        if let webPushTransactional    = webPushTransactional       { params[Constants.webPushTransactional]      = webPushTransactional }
        if let mobilePushBulk          = mobilePushBulk             { params[Constants.mobilePushBulk]            = mobilePushBulk }
        if let mobilePushChain         = mobilePushChain            { params[Constants.mobilePushChain]           = mobilePushChain }
        if let mobilePushTransactional = mobilePushTransactional    { params[Constants.mobilePushTransactional]   = mobilePushTransactional }
        
        sdk.postRequest(path: Constants.manageSubscriptionPath, params: params, completion: { result in
            switch result {
            case .success(_):
                completion(.success(Void()))
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }
}
