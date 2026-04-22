import UIKit
import Foundation

class TrackEventServiceImpl: TrackEventServiceProtocol {
    
    private var sdk: PersonalizationSDK?
    private let sessionQueue: SessionQueue
    private var notificationWidget: NotificationWidget?
    
    init(sdk: PersonalizationSDK) {
        self.sdk = sdk
        self.sessionQueue = sdk.sessionQueue
    }
    
    private struct Constants {
        static let trackStoriesPath = "track/stories"
        static let trackCustomEventPath = "push/custom"
        static let popupShownPath = "popup/showed"
        
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
        static let time = "time"
        static let label = "label"
        static let value = "value"
        static let payload = "payload"
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
        static let quantity = "quantity"
        static let lineId = "line_id"
        static let fashionSize = "fashion_size"
        static let custom = "custom"
        static let recommendedSource = "recommended_source"
        static let orderCash = "order_cash"
        static let orderBonuses = "order_bonuses"
        static let orderDelivery = "order_delivery"
        static let orderDiscount = "order_discount"
        static let channel = "channel"
        static let stream = "stream"
    }

    private static let reservedCustomEventKeys: Set<String> = [
        Constants.shopId,
        Constants.did,
        Constants.seance,
        Constants.sid,
        Constants.segment,
        Constants.event,
        Constants.time,
        Constants.category,
        Constants.label,
        Constants.value,
        Constants.source,
        Constants.payload
    ]

    private static let reservedPurchaseCustomKeys: Set<String> = {
        var s = reservedCustomEventKeys
        s.formUnion([
            Constants.items,
            Constants.orderId,
            Constants.orderPrice,
            Constants.deliveryType,
            Constants.deliveryAddress,
            Constants.paymentType,
            Constants.taxFree,
            Constants.promocode,
            Constants.orderCash,
            Constants.orderBonuses,
            Constants.orderDelivery,
            Constants.orderDiscount,
            Constants.channel,
            Constants.custom,
            Constants.recommendedSource,
            Constants.quantity,
            Constants.lineId,
            Constants.fashionSize,
            Constants.stream,
        ])
        return s
    }()
    
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "track: SDK is not initialized")))
            return
        }
        
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
                let mappedItems = products.map { line in
                    PurchaseItemRequest(
                        id: line.id,
                        amount: line.amount,
                        price: Double(line.price)
                    )
                }
                let purchaseRequest = PurchaseTrackingRequest(
                    orderId: orderId,
                    orderPrice: totalValue,
                    items: mappedItems,
                    deliveryType: deliveryType,
                    deliveryAddress: deliveryAddress,
                    paymentType: paymentType,
                    isTaxFree: taxFree ?? false,
                    promocode: promocode,
                    custom: nil,
                    recommendedSource: nil,
                    stream: nil,
                    segment: nil
                )
                Self.mergePurchasePayload(request: purchaseRequest, params: &params)
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
            case let .synchronizeFavorites(ids):
                var tempItems: [[String: Any]] = []
                for id in ids {
                    tempItems.append([
                        Constants.id: id
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
            
            sdk.postRequest(
                path: path, params: params, completion: { result in
                    switch result {
                    case let .success(successResult):
                        let resJSON = successResult
                        let status = resJSON[Constants.status] as? String ?? ""
                        if status == Constants.success {
                            self.showPopup(jsonResult: resJSON)
                            completion(.success(Void()))
                        } else {
                            completion(.failure(.responseError))
                        }
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "trackPurchase: SDK is not initialized")))
            return
        }
        if let validationError = Self.validatePurchaseRequest(request) {
            completion(.failure(.custom(error: validationError)))
            return
        }
        if let customError = Self.validatePurchaseCustomFields(request.custom) {
            completion(.failure(.custom(error: customError)))
            return
        }

        sessionQueue.addOperation {
            let path = "push"
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment,
            ]
            Self.mergePurchasePayload(request: request, params: &params)
            params[Constants.event] = Constants.purchase

            if let recommendedBy = recommendedBy {
                let recomendedParams = recommendedBy.getParams()
                for item in recomendedParams {
                    params[item.key] = item.value
                }
            }

            let timeValue = UserDefaults.standard.double(forKey: Constants.timeStartSaveKey)
            let nowTimeValue = Date().timeIntervalSince1970
            let diff = nowTimeValue - timeValue
            if diff > 48*60*60 {
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

            sdk.postRequest(
                path: path, params: params, completion: { result in
                    switch result {
                    case let .success(successResult):
                        let resJSON = successResult
                        let status = resJSON[Constants.status] as? String ?? ""
                        if status == Constants.success {
                            self.showPopup(jsonResult: resJSON)
                            completion(.success(Void()))
                        } else {
                            completion(.failure(.responseError))
                        }
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            )
        }
    }

    private static func validatePurchaseRequest(_ request: PurchaseTrackingRequest) -> String? {
        if request.orderId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "trackPurchase: orderId must be non-empty"
        }
        if request.items.isEmpty {
            return "trackPurchase: items must not be empty"
        }
        for item in request.items {
            if item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "trackPurchase: each item.id must be non-empty"
            }
            if item.amount <= 0 {
                return "trackPurchase: each item.amount must be > 0"
            }
            if !item.price.isFinite {
                return "trackPurchase: each item.price must be a finite number"
            }
        }
        if !request.orderPrice.isFinite {
            return "trackPurchase: orderPrice must be a finite number"
        }
        return nil
    }

    private static func validatePurchaseCustomFields(_ custom: [String: Any]?) -> String? {
        guard let custom = custom, !custom.isEmpty else { return nil }
        let effectiveKeys = custom.keys.filter { key in
            if key.isEmpty { return false }
            guard let v = custom[key] else { return false }
            return !(v is NSNull)
        }
        let collisions = Set(effectiveKeys).intersection(reservedPurchaseCustomKeys)
        if !collisions.isEmpty {
            return "trackPurchase: custom contains reserved keys: \(collisions.sorted().joined(separator: ", "))"
        }
        return nil
    }

    private static func mergePurchasePayload(request: PurchaseTrackingRequest, params: inout [String: Any]) {
        if let seg = request.segment?.trimmingCharacters(in: .whitespacesAndNewlines), !seg.isEmpty {
            params[Constants.segment] = seg
        }
        if let stream = request.stream?.trimmingCharacters(in: .whitespacesAndNewlines), !stream.isEmpty {
            params[Constants.stream] = stream
        }

        var tempItems: [[String: Any]] = []
        for item in request.items {
            var row: [String: Any] = [
                Constants.id: item.id,
                Constants.amount: item.amount,
                Constants.price: item.price,
            ]
            if let quantity = item.quantity {
                row[Constants.quantity] = quantity
            }
            if let lineId = item.lineId?.trimmingCharacters(in: .whitespacesAndNewlines), !lineId.isEmpty {
                row[Constants.lineId] = lineId
            }
            if let fashionSize = item.fashionSize?.trimmingCharacters(in: .whitespacesAndNewlines), !fashionSize.isEmpty {
                row[Constants.fashionSize] = fashionSize
            }
            tempItems.append(row)
        }
        params[Constants.items] = tempItems
        params[Constants.orderId] = request.orderId
        params[Constants.orderPrice] = request.orderPrice

        if let deliveryAddress = request.deliveryAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !deliveryAddress.isEmpty {
            params[Constants.deliveryAddress] = deliveryAddress
        }
        if let deliveryType = request.deliveryType?.trimmingCharacters(in: .whitespacesAndNewlines), !deliveryType.isEmpty {
            params[Constants.deliveryType] = deliveryType
        }
        if let paymentType = request.paymentType?.trimmingCharacters(in: .whitespacesAndNewlines), !paymentType.isEmpty {
            params[Constants.paymentType] = paymentType
        }
        if request.isTaxFree {
            params[Constants.taxFree] = true
        }
        if let promocode = request.promocode?.trimmingCharacters(in: .whitespacesAndNewlines), !promocode.isEmpty {
            params[Constants.promocode] = promocode
        }
        if let orderCash = request.orderCash {
            params[Constants.orderCash] = orderCash
        }
        if let orderBonuses = request.orderBonuses {
            params[Constants.orderBonuses] = orderBonuses
        }
        if let orderDelivery = request.orderDelivery {
            params[Constants.orderDelivery] = orderDelivery
        }
        if let orderDiscount = request.orderDiscount {
            params[Constants.orderDiscount] = orderDiscount
        }
        if let channel = request.channel?.trimmingCharacters(in: .whitespacesAndNewlines), !channel.isEmpty {
            params[Constants.channel] = channel
        }
        if let custom = request.custom, !custom.isEmpty {
            var cleaned: [String: Any] = [:]
            for (key, value) in custom where !key.isEmpty && !(value is NSNull) {
                cleaned[key] = value
            }
            if !cleaned.isEmpty {
                params[Constants.custom] = cleaned
            }
        }
        if let recommendedSource = request.recommendedSource, !recommendedSource.isEmpty {
            params[Constants.recommendedSource] = recommendedSource
        }
    }
    
    func trackEvent(
        event: String,
        time: Int?,
        category: String?,
        label: String?,
        value: Int?,
        customFields: [String: Any]?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "trackEvent: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment,
                Constants.event: event
            ]
            
            if let time = time {
                params[Constants.time] = time
            }
            
            if let category = category {
                params[Constants.category] = category
            }
            if let label = label {
                params[Constants.label] = label
            }
            if let value = value {
                params[Constants.value] = value
            }

            if let customFields = customFields, !customFields.isEmpty {
                let collisions = Set(customFields.keys).intersection(Self.reservedCustomEventKeys)
                if !collisions.isEmpty {
                    let sorted = collisions.sorted().joined(separator: ", ")
                    completion(.failure(.custom(error: "trackEvent: customFields contains reserved keys: \(sorted)")))
                    return
                }
                
                for (key, value) in customFields {
                    params[key] = value
                }
                
                params[Constants.payload] = customFields
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
                        self.showPopup(jsonResult: resJSON)
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
    
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {
        guard let sdk = sdk else {
            completion(.failure(.custom(error: "trackPopupShown: SDK is not initialized")))
            return
        }
        
        sessionQueue.addOperation {
            let params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.sid: sdk.userSeance,
                "popup": popupId
            ]
            
            sdk.postRequest(path: Constants.popupShownPath, params: params) { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func showPopup(jsonResult: [String: Any]) {
        guard let popupData = jsonResult["popup"] as? [String: Any], !popupData.isEmpty else {
            return
        }
        let popup = Popup(json: popupData)
        sdk?.popupPresenter.presentPopup(popup)
    }
}

class TrackSourceServiceImpl: TrackSourceServiceProtocol {
    private struct Constants {
        static let recomendedCode = "recomendedCode"
        static let recomendedType = "recomendedType"
        static let timeStartSave = "timeStartSave"
    }
    func trackSource(source: RecommendedByCase, code: String) {
        UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: Constants.timeStartSave)
        UserDefaults.standard.setValue(code, forKey: Constants.recomendedCode)
        UserDefaults.standard.setValue(source.rawValue, forKey: Constants.recomendedType)
    }
}
