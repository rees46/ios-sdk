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
        static let trackStoriesPath = "track/stories"
        static let trackCustomEventPath = "push/custom"
        
        static let id = "id"
        static let amount = "amount"
        static let price = "price"
        static let shopId = "shop_id"
        static let did = "did"
        static let seance = "seance"
        static let sid = "sid"
        static let segment = "segment"
        static let itemId = "item_id"
        static let email = "email"
        static let phone = "phone"
        static let event = "event"
        static let label = "label"
        static let value = "value"
        static let source = "source"
        static let status = "status"
        static let success = "success"
        static let cart = "cart"
        static let items = "items"
        static let timeStartSaveKey = "timeStartSave"
        static let sourceFrom = "from"
        static let sourceCode = "code"
        static let fullCartValue = "true"
        static let statusSuccess = "success"
        static let storyId = "story_id"
        static let slideId = "slide_id"
        static let view = "view"
        static let click = "click"
        static let searchQuery = "search_query"
        static let search = "search"
        static let categoryId = "category_id"
        static let category = "category"
        static let recomendedCode = "recomendedCode"
        static let recomendedType = "recomendedType"
        static let timeStartSave = "timeStartSave"
        static let orderId = "order_id"
        static let orderPrice = "order_price"
        static let promocode = "promocode"
        static let deliveryType = "delivery_type"
        static let deliveryAddress = "delivery_address"
        static let removeFromCart = "remove_from_cart"
        static let removeWish = "remove_wish"
        static let paymentType = "payment_type"
        static let taxFree = "tax_free"
        static let fullCart = "full_cart"
        static let fullWish = "full_wish"
        static let wish = "wish"
        static let purchase = "purchase"
    }
    
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            var path = "push"
            
            var paramEvent = ""
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment
            ]
            switch event {
            case let .slideView(storyId, slideId):
                params[Constants.storyId] = storyId
                params[Constants.slideId] = slideId
                params[Constants.sourceCode] = sdk.storiesCode
                path = Constants.trackStoriesPath
                
                paramEvent = Constants.view
            case let .slideClick(storyId, slideId):
                params[Constants.storyId] = storyId
                params[Constants.slideId] = slideId
                params[Constants.sourceCode] = sdk.storiesCode
                path = Constants.trackStoriesPath
                
                paramEvent = Constants.click
            case let .search(query):
                params[Constants.searchQuery] = query
                paramEvent = Constants.search
            case let .categoryView(id):
                params[Constants.categoryId] = id
                paramEvent = Constants.category
            case let .productView(id):
                params[Constants.items] = [[Constants.id:id]]
                paramEvent = Constants.view
            case let .productAddedToCart(id, amount):
                params[Constants.items] = [[Constants.id:id, Constants.amount:amount] as [String : Any]]
                paramEvent = Constants.cart
            case let .productAddedToFavorites(id):
                params[Constants.items] = [[Constants.id:id]]
                paramEvent = Constants.wish
            case let .productRemovedFromCart(id):
                params[Constants.items] = [[Constants.id:id]]
                paramEvent = Constants.removeFromCart
            case let .productRemovedFromFavorites(id):
                params[Constants.items] = [[Constants.id:id]]
                paramEvent = Constants.removeWish
            case let .orderCreated(orderId, totalValue, products, deliveryAddress, deliveryType, promocode, paymentType, taxFree):
                var tempItems: [[String: Any]] = []
                for (_, item) in products.enumerated() {
                    tempItems.append([
                        Constants.id: item.id,
                        Constants.amount: String(item.amount),
                        Constants.price: item.price
                    ])
                }
                params[Constants.items] = tempItems
                params[Constants.orderId] = orderId
                params[Constants.orderPrice] = "\(totalValue)"
                if let deliveryAddress = deliveryAddress {
                    params[Constants.deliveryAddress] = deliveryAddress
                }
                if let deliveryType = deliveryType {
                    params[Constants.deliveryType] = deliveryType
                }
                if let promocode = promocode {
                    params[Constants.promocode] = promocode
                }
                if let paymentType = paymentType {
                    params[Constants.paymentType] = paymentType
                }
                if let taxFree = taxFree {
                    params[Constants.taxFree] = taxFree
                }
                paramEvent = Constants.purchase
            case let .synchronizeCart(items):
                var tempItems: [[String: Any]] = []
                for (_, item) in items.enumerated() {
                    tempItems.append([
                        Constants.id: item.productId,
                        Constants.amount: String(item.quantity)
                    ])
                }
                params[Constants.items] = tempItems
                params[Constants.fullCart] = Constants.fullCartValue
                paramEvent = Constants.cart
            case let .synchronizeFavorites(items):
                var tempItems: [[String: Any]] = []
                for (_, item) in items.enumerated() {
                    tempItems.append([
                        Constants.id: item.productId
                    ])
                }
                params[Constants.items] = tempItems
                params[Constants.fullWish] = Constants.fullCartValue
                paramEvent = Constants.wish
            }
            
            params[Constants.event] = paramEvent
            
            // Process recommendedBy parameter
            if let recommendedBy = recommendedBy {
                let recomendedParams = recommendedBy.getParams()
                for item in recomendedParams {
                    params[item.key] = item.value
                }
            }
            
            // Check source tracker params
            let timeValue = UserDefaults.standard.double(forKey: Constants.timeStartSaveKey)
            let nowTimeValue = Date().timeIntervalSince1970
            let diff = nowTimeValue - timeValue
            if diff > 48*60*60 {
                // Recomended params is invalidate
                UserDefaults.standard.setValue(nil, forKey: Constants.recomendedCode)
                UserDefaults.standard.setValue(nil, forKey: Constants.recomendedType)
            } else {
                let savedCode = UserDefaults.standard.string(forKey: Constants.recomendedCode) ?? ""
                let savedType = UserDefaults.standard.string(forKey: Constants.recomendedType) ?? ""
                let sourceParams: [String: Any] = [
                    Constants.sourceFrom: savedType,
                    Constants.sourceCode: savedCode
                ]
                params[Constants.source] = sourceParams
            }
            
            sdk.postRequest(path: path, params: params, completion: { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let status = resJSON[Constants.status] as? String ?? ""
                    if status == Constants.success {
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
    
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let sdk = sdk else { return }
        
        sessionQueue.addOperation {
            
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment,
                Constants.event: event
            ]
            
            if let category = category {
                params[Constants.category] = category
            }
            if let label = label {
                params[Constants.label] = label
            }
            if let value = value {
                params[Constants.value] = String(value)
            }
            
            // Check source tracker params
            let timeValue = UserDefaults.standard.double(forKey: Constants.timeStartSave)
            let nowTimeValue = Date().timeIntervalSince1970
            let diff = nowTimeValue - timeValue
            if diff > 48*60*60 {
                // Recomended params is invalidate
                UserDefaults.standard.setValue(nil, forKey: Constants.recomendedCode)
                UserDefaults.standard.setValue(nil, forKey: Constants.recomendedType)
            } else {
                let savedCode = UserDefaults.standard.string(forKey: Constants.recomendedCode) ?? ""
                let savedType = UserDefaults.standard.string(forKey: Constants.recomendedType) ?? ""
                let sourceParams: [String: Any] = [
                    Constants.sourceFrom: savedType,
                    Constants.sourceCode: savedCode
                ]
                params[Constants.source] = sourceParams
            }
            
            sdk.postRequest(path: Constants.trackCustomEventPath, params: params, completion: { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let status = resJSON[Constants.status] as? String ?? ""
                    if status == Constants.success {
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
        UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: Constants.timeStartSave)
        UserDefaults.standard.setValue(code, forKey: Constants.recomendedCode)
        UserDefaults.standard.setValue(source.rawValue, forKey: Constants.recomendedType)
    }
}
