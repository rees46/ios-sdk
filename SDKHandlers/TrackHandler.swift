import Foundation
import UIKit

class TrackHandler{
    
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
    
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            var path = "push"
            var paramEvent = ""
            var params: [String: Any] = [
                "shop_id": sdk.shopId,
                "did": sdk.deviceId,
                "seance": sdk.userSeance,
                "sid": sdk.userSeance,
                "segment": sdk.segment
            ]
            switch event {
            case let .slideView(storyId, slideId):
                params["story_id"] = storyId
                params["slide_id"] = slideId
                params["code"] = self.storiesCode
                path = "track/stories"
                paramEvent = "view"
            case let .slideClick(storyId, slideId):
                params["story_id"] = storyId
                params["slide_id"] = slideId
                params["code"] = self.storiesCode
                path = "track/stories"
                paramEvent = "click"
            case let .search(query):
                params["search_query"] = query
                paramEvent = "search"
            case let .categoryView(id):
                params["category_id"] = id
                paramEvent = "category"
            case let .productView(id):
                params["items"] = [["id":id]]
                paramEvent = "view"
            case let .productAddedToCart(id, amount):
                params["items"] = [["id":id, "amount":amount] as [String : Any]]
                paramEvent = "cart"
            case let .productAddedToFavorites(id):
                params["items"] = [["id":id]]
                paramEvent = "wish"
            case let .productRemovedFromCart(id):
                params["items"] = [["id":id]]
                paramEvent = "remove_from_cart"
            case let .productRemovedFromFavorites(id):
                params["items"] = [["id":id]]
                paramEvent = "remove_wish"
            case let .orderCreated(orderId, totalValue, products, deliveryAddress, deliveryType, promocode, paymentType, taxFree):
                var tempItems: [[String: Any]] = []
                for (_, item) in products.enumerated() {
                    tempItems.append([
                        "id": item.id,
                        "amount": String(item.amount),
                        "price": item.price
                    ])
                }
                params["items"] = tempItems
                params["order_id"] = orderId
                params["order_price"] = "\(totalValue)"
                if let deliveryAddress = deliveryAddress {
                    params["delivery_address"] = deliveryAddress
                }
                if let deliveryType = deliveryType {
                    params["delivery_type"] = deliveryType
                }
                if let promocode = promocode {
                    params["promocode"] = promocode
                }
                if let paymentType = paymentType {
                    params["payment_type"] = paymentType
                }
                if let taxFree = taxFree {
                    params["tax_free"] = taxFree
                }
                paramEvent = "purchase"
            case let .synchronizeCart(items):
                var tempItems: [[String: Any]] = []
                for (_, item) in items.enumerated() {
                    tempItems.append([
                        "id": item.productId,
                        "amount": String(item.quantity)
                    ])
                }
                params["items"] = tempItems
                params["full_cart"] = "true"
                paramEvent = "cart"
            case let .synchronizeFavorites(items):
                var tempItems: [[String: Any]] = []
                for (_, item) in items.enumerated() {
                    tempItems.append([
                        "id": item.productId
                    ])
                }
                params["items"] = tempItems
                params["full_wish"] = "true"
                paramEvent = "wish"
            }
            
            params["event"] = paramEvent
            
            // Process recommendedBy parameter
            if let recommendedBy = recommendedBy {
                let recomendedParams = recommendedBy.getParams()
                for item in recomendedParams {
                    params[item.key] = item.value
                }
            }
            
            // Check source tracker params
            let timeValue = UserDefaults.standard.double(forKey: "timeStartSave")
            let nowTimeValue = Date().timeIntervalSince1970
            let diff = nowTimeValue - timeValue
            if diff > 48*60*60 {
                // Recomended params is invalidate
                UserDefaults.standard.setValue(nil, forKey: "recomendedCode")
                UserDefaults.standard.setValue(nil, forKey: "recomendedType")
            } else {
                let savedCode = UserDefaults.standard.string(forKey: "recomendedCode") ?? ""
                let savedType = UserDefaults.standard.string(forKey: "recomendedType") ?? ""
                let sourceParams: [String: Any] = [
                    "from": savedType,
                    "code": savedCode
                ]
                params["source"] = sourceParams
            }
            
            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let status = resJSON["status"] as? String ?? ""
                    if status == "success" {
                        completion(.success(Void()))
                    } else {
                        completion(.failure(.responseError))
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    
    // Track custom event
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            let path = "push/custom"
            var params: [String: Any] = [
                "shop_id": sdk.shopId,
                "did": sdk.deviceId,
                "seance": sdk.userSeance,
                "sid": sdk.userSeance,
                "segment": sdk.segment,
                "event": event
            ]
            
            if let category = category {
                params["category"] = category
            }
            if let label = label {
                params["label"] = label
            }
            if let value = value {
                params["value"] = String(value)
            }
            
            // Check source tracker params
            let timeValue = UserDefaults.standard.double(forKey: "timeStartSave")
            let nowTimeValue = Date().timeIntervalSince1970
            let diff = nowTimeValue - timeValue
            if diff > 48*60*60 {
                // Recomended params is invalidate
                UserDefaults.standard.setValue(nil, forKey: "recomendedCode")
                UserDefaults.standard.setValue(nil, forKey: "recomendedType")
            } else {
                let savedCode = UserDefaults.standard.string(forKey: "recomendedCode") ?? ""
                let savedType = UserDefaults.standard.string(forKey: "recomendedType") ?? ""
                let sourceParams: [String: Any] = [
                    "from": savedType,
                    "code": savedCode
                ]
                params["source"] = sourceParams
            }
            
            sdk.postRequest(path: path, params: params, completion: { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let status = resJSON["status"] as? String ?? ""
                    if status == "success" {
                        completion(.success(Void()))
                    } else {
                        completion(.failure(.responseError))
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func trackSource(source: RecommendedByCase, code: String) {
        UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: "timeStartSave")
        UserDefaults.standard.setValue(code, forKey: "recomendedCode")
        UserDefaults.standard.setValue(source.rawValue, forKey: "recomendedType")
    }
}
