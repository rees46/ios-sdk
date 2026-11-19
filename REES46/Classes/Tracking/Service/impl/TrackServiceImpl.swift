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
        static let sourceFrom = "from"
        static let sourceCode = "code"
        static let fullCartValue = "true"
        static let statusSuccess = "success"
        static let storyId = "story_id"
        static let slideId = "slide_id"
        static let view = "view"
        static let click = "click"
        static let searchQuery = "search_query"
        static let results = "results"
        static let search = "search"
        static let categoryId = "category_id"
        static let category = "category"
        static let orderId = "order_id"
        static let orderPrice = "order_price"
        static let promocode = "promocode"
        static let deliveryType = "delivery_type"
        static let deliveryAddress = "delivery_address"
        static let removeFromCart = "remove_from_cart"
        static let removeWish = "remove_wish"
        static let paymentType = "payment_type"
        static let taxFree = "tax_free"
        static let giftPackage = "gift_package"
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
        track(
            event: event,
            source: recommendedBy.map(TrackingSourceWire.init),
            details: .none,
            completion: completion
        )
    }

    func track(
        event: Event,
        source: TrackingSourceWire?,
        details: TrackEventDetails,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        track(event: event, source: source, details: details, accepted: nil, completion: completion)
    }

    func track(
        event: Event,
        source: TrackingSourceWire?,
        details: TrackEventDetails,
        accepted: TrackingAccepted?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard let sdk = sdk else {
            accepted?(.notInitialized)
            completion(.failure(.custom(error: "track: SDK is not initialized")))
            return
        }

        // The new core: built now, in the order of the calls, and handed to its queue.
        if Self.queues(sdk) {
            if let problem = Self.invalidArgument(of: event) {
                SdkLogger.forShop(sdk.shopId).warning(LogCode.invalidArgument, "track: \(problem)", ["reason": "empty"])
                Self.refuse(completion, accepted, "track: \(problem)")
                return
            }
            let built = Self.fields(of: event, details: details, sdk: sdk, contract: true)
            // A slide `track/stories` does not take — a story id that is not a positive whole number (a
            // virtual slide of a product campaign, `{story_id}_{index}`), or a slide id that is not one in
            // digits — does not go, and that is no error (`sdk/contract/tracking.md`). The slide still
            // makes its block the stored source.
            if Self.isVirtualSlide(event) {
                Self.storeStoriesSource(built.storiesCode, sdk: sdk)
                SdkLogger.area(.stories, .debug, "the slide of a virtual story is not sent", shopId: sdk.shopId)
                Self.later { accepted?(nil) }
                Self.later(completion, .success(Void()))
                return
            }
            if let problem = Self.missingStoriesCode(event, built.storiesCode) {
                SdkLogger.forShop(sdk.shopId).warning(LogCode.invalidArgument, "track: \(problem)", ["reason": "no_stories_code"])
                Self.refuse(completion, accepted, "track: \(problem)")
                return
            }
            var body = built.fields
            if let source = source {
                for item in source.params() {
                    body[item.key] = item.value
                }
            }
            Self.storeStoriesSource(built.storiesCode, sdk: sdk)
            _ = enqueue(sdk, path: built.path, body: body, accepted: accepted) { result in
                self.finish(result, path: built.path, showsPopup: false, completion: completion)
            }
            return
        }

        let completion = TrackingAnswer.telling(accepted, completion)
        sessionQueue.addOperation {
            var params: [String: Any] = [
                Constants.shopId: sdk.shopId,
                Constants.did: sdk.deviceId,
                Constants.seance: sdk.userSeance,
                Constants.sid: sdk.userSeance,
                Constants.segment: sdk.segment
            ]
            let built = Self.fields(of: event, details: details, sdk: sdk, contract: false)
            // The server refuses a slide without the code of its block (`422`): refused here instead.
            if let problem = Self.missingStoriesCode(event, built.storiesCode) {
                SdkLogger.forShop(sdk.shopId).warning(LogCode.invalidArgument, "track: \(problem)", ["reason": "no_stories_code"])
                completion(.failure(.custom(error: "track: \(problem)")))
                return
            }
            for (key, value) in built.fields {
                params[key] = value
            }

            // Process recommendedBy parameter
            if let source = source {
                for item in source.params() {
                    params[item.key] = item.value
                }
            }

            // A story slide attributes the events that follow it to its block — parity with Android's
            // `StoriesManager.trackStory`, which stores `stories` + code the same way.
            Self.storeStoriesSource(built.storiesCode, sdk: sdk)

            // Check source tracker params
            if let stored = sdk.trackingSourceStore.currentSource() {
                let sourceParams: [String: Any] = [
                    Constants.sourceFrom: stored.type,
                    Constants.sourceCode: stored.code
                ]
                params[Constants.source] = sourceParams
            }

            sdk.postRequest(path: built.path, params: params) { result in
                self.finish(result, path: built.path, showsPopup: true, completion: completion)
            }
        }
    }

    /// Whether `sdk` runs the new core, whose queue takes the events (`sdk/core/queue.md`).
    private static func queues(_ sdk: PersonalizationSDK) -> Bool {
        (sdk as? SimplePersonalizationSDK)?.eventQueue != nil
    }

    /// The new core tells every failure later, never inside the call: the old core keeps calling back as
    /// it always has.
    private static func later(_ completion: @escaping (Result<Void, SdkError>) -> Void, _ result: Result<Void, SdkError>) {
        DispatchQueue.global(qos: .utility).async { completion(result) }
    }

    private static func later(_ body: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async(execute: body)
    }

    /// An argument the new core refuses before the queue: `accepted` hears `invalidArgument`, the old
    /// completion the text, later.
    private static func refuse(_ completion: @escaping (Result<Void, SdkError>) -> Void, _ accepted: TrackingAccepted?, _ problem: String) {
        later {
            accepted?(.invalidArgument(problem))
            completion(.failure(.custom(error: problem)))
        }
    }

    /// Hands an event to the new core's queue; `false` when there is none. `accepted` hears when the
    /// queue took it, or why not.
    private func enqueue(
        _ sdk: PersonalizationSDK,
        path: String,
        body: [String: Any],
        accepted: TrackingAccepted? = nil,
        completion: @escaping (Result<[String: Any], SdkError>) -> Void
    ) -> Bool {
        let queued = (sdk as? SimplePersonalizationSDK)?.enqueueEvent(path: path, body: body, accepted: accepted, completion: completion) ?? false
        if !queued {
            accepted?(.notInitialized)
        }
        return queued
    }

    /// The answer as the tracking methods have always taken it: `status: success` is a success —
    /// with its popup, on the old core; the new core's queue shows popups itself (decision 2) —;
    /// anything else `.responseError`. `path` `track/stories` answers `204` without a body: there an
    /// empty answer is a success too.
    private func finish(
        _ result: Result<[String: Any], SdkError>,
        path: String = "push",
        showsPopup: Bool,
        completion: (Result<Void, SdkError>) -> Void
    ) {
        switch result {
        case let .success(answer):
            let status = answer[Constants.status] as? String ?? ""
            if status == Constants.success || (answer.isEmpty && path == Constants.trackStoriesPath) {
                if showsPopup {
                    showPopup(jsonResult: answer)
                }
                completion(.success(Void()))
            } else {
                completion(.failure(.responseError))
            }
        case let .failure(error):
            completion(.failure(error))
        }
    }

    /// A story slide makes its block the stored source of the events that follow.
    private static func storeStoriesSource(_ code: String?, sdk: PersonalizationSDK) {
        guard let code = code, !code.isEmpty else { return }
        sdk.trackingSourceStore.store(type: TrackingSourceType.stories.rawValue, code: code)
    }

    /// What the new core refuses before an event is queued (`sdk/contract/tracking.md`), as Android
    /// does: an empty item id, category id, search query, story or slide id.
    private static func invalidArgument(of event: Event) -> String? {
        switch event {
        case let .productView(id), let .productAddedToFavorites(id), let .productRemovedFromCart(id),
             let .productRemovedFromFavorites(id), let .productAddedToCart(id, _):
            return blank(id) ? "the item id must not be empty" : nil
        case let .categoryView(id):
            return blank(id) ? "the category id must not be empty" : nil
        case let .search(query):
            return blank(query) ? "the search query must not be empty" : nil
        case let .slideView(storyId, slideId), let .slideClick(storyId, slideId):
            return blank(storyId) || blank(slideId) ? "the story and slide ids must not be empty" : nil
        default:
            return nil
        }
    }

    /// A slide `track/stories` does not take: a story id that is not a positive whole number as such —
    /// the virtual slide of a product campaign, `{story_id}_{index}` —, or a slide id that is not a
    /// positive whole number in digits (`sdk/contract/tracking.md`). As on Android: no sign, no spaces,
    /// and a story id without leading zeros, since it goes as a number.
    static func isVirtualSlide(_ event: Event) -> Bool {
        switch event {
        case let .slideView(storyId, slideId), let .slideClick(storyId, slideId):
            return storyNumber(storyId) == nil || !isPositiveDigits(slideId)
        default:
            return false
        }
    }

    /// Why a slide event cannot go: it has no code of its stories block — none given and no block
    /// loaded —, and `track/stories` refuses a slide without one (`422`, `sdk/contract/tracking.md`).
    /// `nil` for a slide with a code and for any other event.
    static func missingStoriesCode(_ event: Event, _ code: String?) -> String? {
        switch event {
        case .slideView, .slideClick:
            return code == nil ? "a story slide needs the code of its stories block: none was given and no block was loaded" : nil
        default:
            return nil
        }
    }

    /// The code of the stories block a slide event goes with: the one given, else the code of the block
    /// the SDK loaded last. A blank one is none.
    static func storiesBlockCode(given: String?, loaded: String?) -> String? {
        [given, loaded].lazy.compactMap { $0 }.first { !blank($0) }
    }

    /// The story id as the number `track/stories` takes: a positive whole number written as one.
    static func storyNumber(_ value: String) -> Int? {
        guard let number = Int(value), number > 0, String(number) == value else { return nil }
        return number
    }

    /// Digits only, and above zero.
    private static func isPositiveDigits(_ value: String) -> Bool {
        guard !value.isEmpty, value.allSatisfy({ ("0"..."9").contains($0) }), let number = Int(value) else { return false }
        return number > 0
    }

    private static func blank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The address and the fields of `event`, without the fields every request carries. `contract`
    /// is the wire of the new core (`sdk/contract/tracking.md`): a story id as a number, `full_cart`
    /// and `full_wish` as booleans, the quantities as numbers; the old core keeps the wire it has
    /// always sent.
    private static func fields(
        of event: Event,
        details: TrackEventDetails,
        sdk: PersonalizationSDK,
        contract: Bool
    ) -> (path: String, fields: [String: Any], storiesCode: String?) {
        var path = "push"
        var params: [String: Any] = [:]
        var paramEvent = ""
        /// Set by the story branches so the block can be stored as the attribution source.
        var storiesBlockCode: String?
        func storyId(_ id: String) -> Any {
            guard contract, let number = storyNumber(id) else { return id }
            return number
        }
        let fullValue: Any = contract ? true : Constants.fullCartValue
        switch event {
        case let .slideView(storyId: id, slideId: slideId):
            let blockCode = Self.storiesBlockCode(given: details.storiesCode, loaded: sdk.storiesCode)
            params[Constants.storyId] = storyId(id)
            params[Constants.slideId] = slideId
            params[Constants.sourceCode] = blockCode
            path = Constants.trackStoriesPath
            storiesBlockCode = blockCode
            paramEvent = Constants.view
        case let .slideClick(storyId: id, slideId: slideId):
            let blockCode = Self.storiesBlockCode(given: details.storiesCode, loaded: sdk.storiesCode)
            params[Constants.storyId] = storyId(id)
            params[Constants.slideId] = slideId
            params[Constants.sourceCode] = blockCode
            path = Constants.trackStoriesPath
            storiesBlockCode = blockCode
            paramEvent = Constants.click
        case let .search(query):
            params[Constants.searchQuery] = query
            if let results = details.results, !results.isEmpty {
                params[Constants.results] = results.joined(separator: ",")
            }
            paramEvent = Constants.search
        case let .categoryView(id):
            params[Constants.categoryId] = id
            paramEvent = Constants.category
        case let .productView(id):
            params[Constants.items] = [[Constants.id: id]]
            paramEvent = Constants.view
        case let .productAddedToCart(id, amount):
            var item: [String: Any] = [Constants.id: id, Constants.amount: amount]
            if let price = details.price {
                item[Constants.price] = price
            }
            if let size = details.fashionSize?.trimmingCharacters(in: .whitespacesAndNewlines), !size.isEmpty {
                item[Constants.fashionSize] = size
            }
            params[Constants.items] = [item]
            paramEvent = Constants.cart
        case let .productAddedToFavorites(id):
            params[Constants.items] = [[Constants.id: id]]
            paramEvent = Constants.wish
        case let .productRemovedFromCart(id):
            params[Constants.items] = [[Constants.id: id]]
            paramEvent = Constants.removeFromCart
        case let .productRemovedFromFavorites(id):
            params[Constants.items] = [[Constants.id: id]]
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
            for item in items {
                var row: [String: Any] = [
                    Constants.id: item.productId,
                    Constants.amount: contract ? item.quantity as Any : String(item.quantity)
                ]
                if let price = item.price {
                    row[Constants.price] = price
                }
                tempItems.append(row)
            }
            params[Constants.items] = tempItems
            params[Constants.fullCart] = fullValue
            paramEvent = Constants.cart
        case let .synchronizeFavorites(ids):
            var tempItems: [[String: Any]] = []
            for id in ids {
                tempItems.append([
                    Constants.id: id
                ])
            }
            params[Constants.items] = tempItems
            params[Constants.fullWish] = fullValue
            paramEvent = Constants.wish
        }
        params[Constants.event] = paramEvent
        return (path, params, storiesBlockCode)
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackPurchase(request, source: recommendedBy.map(TrackingSourceWire.init), completion: completion)
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, source: TrackingSourceWire?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackPurchase(request, source: source, accepted: nil, completion: completion)
    }

    func trackPurchase(
        _ request: PurchaseTrackingRequest,
        source: TrackingSourceWire?,
        accepted: TrackingAccepted?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard let sdk = sdk else {
            accepted?(.notInitialized)
            completion(.failure(.custom(error: "trackPurchase: SDK is not initialized")))
            return
        }
        if let problem = Self.validatePurchaseRequest(request) ?? Self.validatePurchaseCustomFields(request.custom) {
            if Self.queues(sdk) {
                Self.refuse(completion, accepted, problem)
            } else {
                accepted?(.invalidArgument(problem))
                completion(.failure(.custom(error: problem)))
            }
            return
        }

        // The new core: built now and handed to its queue; `sid` and the stored source go when it is sent.
        if Self.queues(sdk) {
            var body: [String: Any] = [:]
            Self.mergePurchasePayload(request: request, params: &body)
            body[Constants.event] = Constants.purchase
            if let source = source {
                for item in source.params() {
                    body[item.key] = item.value
                }
            }
            _ = enqueue(sdk, path: "push", body: body, accepted: accepted) { result in
                self.finish(result, showsPopup: false) { outcome in
                    if case .success = outcome {
                        // Popups v3: a purchase changes the audience — the list is fetched again.
                        (sdk as? SimplePersonalizationSDK)?.popupsV3.purchased()
                    }
                    completion(outcome)
                }
            }
            return
        }

        let completion = TrackingAnswer.telling(accepted, completion)
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

            if let source = source {
                for item in source.params() {
                    params[item.key] = item.value
                }
            }

            if let stored = sdk.trackingSourceStore.currentSource() {
                let sourceParams: [String: Any] = [
                    Constants.sourceFrom: stored.type,
                    Constants.sourceCode: stored.code
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
                            // Popups v3: a purchase changes the audience — the list is fetched again.
                            (sdk as? SimplePersonalizationSDK)?.popupsV3.purchased()
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
        if request.isGiftPackage {
            params[Constants.giftPackage] = true
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
        trackEvent(
            event: event, time: time, category: category, label: label, value: value, customFields: customFields,
            accepted: nil, completion: completion
        )
    }

    func trackEvent(
        event: String,
        time: Int?,
        category: String?,
        label: String?,
        value: Int?,
        customFields: [String: Any]?,
        accepted: TrackingAccepted?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        guard let sdk = sdk else {
            accepted?(.notInitialized)
            completion(.failure(.custom(error: "trackEvent: SDK is not initialized")))
            return
        }
        // Popups v3: a custom event may be a `track_event` trigger.
        (sdk as? SimplePersonalizationSDK)?.popupsV3.trackEvent(event)

        // The new core: checked and built now, handed to its queue. `time` is the event's own or the
        // time it was made; no source: `push/custom` does not read it.
        if Self.queues(sdk) {
            let logger = SdkLogger.forShop(sdk.shopId)
            guard !Self.blank(event) else {
                logger.warning(LogCode.invalidArgument, "trackEvent: the event must not be empty", ["reason": "empty"])
                Self.refuse(completion, accepted, "trackEvent: the event must not be empty")
                return
            }
            var body: [String: Any] = [Constants.event: event]
            if let time = time { body[Constants.time] = time }
            if let category = category { body[Constants.category] = category }
            if let label = label { body[Constants.label] = label }
            if let value = value { body[Constants.value] = value }
            if let customFields = customFields, !customFields.isEmpty {
                let collisions = Set(customFields.keys).intersection(Self.reservedCustomEventKeys)
                guard collisions.isEmpty else {
                    logger.warning(LogCode.invalidArgument, "trackEvent: customFields use reserved keys", ["reason": "reserved_keys"])
                    Self.refuse(completion, accepted, "trackEvent: customFields contains reserved keys: \(collisions.sorted().joined(separator: ", "))")
                    return
                }
                // NaN, infinity, a date or an object of the app cannot be written: refused here.
                guard SafeJSON.isValid(customFields) else {
                    logger.warning(LogCode.invalidArgument, "trackEvent: customFields are not valid JSON", ["reason": "invalid_json"])
                    Self.refuse(completion, accepted, "trackEvent: customFields are not valid JSON")
                    return
                }
                for (key, value) in customFields {
                    body[key] = value
                }
                body[Constants.payload] = customFields
            }
            _ = enqueue(sdk, path: Constants.trackCustomEventPath, body: body, accepted: accepted) { result in
                self.finish(result, showsPopup: false, completion: completion)
            }
            return
        }

        let completion = TrackingAnswer.telling(accepted, completion)
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
                    SdkLogger.forShop(sdk.shopId).warning(LogCode.invalidArgument, "trackEvent: customFields use reserved keys", ["reason": "reserved_keys"])
                    completion(.failure(.custom(error: "trackEvent: customFields contains reserved keys: \(sorted)")))
                    return
                }
                // A value that is not JSON (a Date, a custom object, NaN) would crash the app when the
                // body is written: fail the call instead.
                guard SafeJSON.isValid(customFields) else {
                    SdkLogger.forShop(sdk.shopId).warning(LogCode.invalidArgument, "trackEvent: customFields are not valid JSON", ["reason": "invalid_json"])
                    completion(.failure(.custom(error: "trackEvent: customFields are not valid JSON")))
                    return
                }
                
                for (key, value) in customFields {
                    params[key] = value
                }
                
                params[Constants.payload] = customFields
            }
            
            // Check source tracker params
            if let stored = sdk.trackingSourceStore.currentSource() {
                let sourceParams: [String: Any] = [
                    Constants.sourceFrom: stored.type,
                    Constants.sourceCode: stored.code
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
        trackPopupShown(popupId: popupId, accepted: nil, completion: completion)
    }

    func trackPopupShown(popupId: Int, accepted: TrackingAccepted?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        guard let sdk = sdk else {
            accepted?(.notInitialized)
            completion(.failure(.custom(error: "trackPopupShown: SDK is not initialized")))
            return
        }

        // The new core: queued; `did` and `sid` go when it is sent, after ready.
        if Self.queues(sdk) {
            _ = enqueue(sdk, path: Constants.popupShownPath, body: ["popup": popupId], accepted: accepted) { result in
                completion(result.map { _ in Void() })
            }
            return
        }

        let completion = TrackingAnswer.telling(accepted, completion)
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

    private let store: TrackingSourceStore

    init(store: TrackingSourceStore) {
        self.store = store
    }

    func trackSource(source: RecommendedByCase, code: String) {
        store.store(type: source.rawValue, code: code)
    }

    func trackSource(type: String, code: String) {
        store.store(type: type, code: code)
    }
}

/**
 The attribution a host set with `tracking.setSource(_:)`, kept for 48 hours and attached to every
 event sent in that window.

 Multi-instance (R2): the values used to live in `UserDefaults.standard` under bare keys, so two shops
 in one app shared one attribution — `shopA.tracking.setSource(…)` coloured shopB's next event. The
 store now writes into the shop's own partition suite, the same one identity and stories state use.
 Reads fall back to the legacy `.standard` keys once, so an app upgrading mid-window keeps the source
 it had already been given.
 */
protocol TrackingSourceStore {

    /// Persists [type] (the raw `recommended_by` value) and [code], starting a fresh 48h window.
    func store(type: String, code: String)

    /// The stored attribution, or `nil` when nothing was set or the window has expired.
    func currentSource() -> (type: String, code: String)?

    /// Forgets the stored attribution: it was the deleted customer's (`deleteUserCredentials`).
    func clear()
}

final class TrackingSourceStoreImpl: TrackingSourceStore {

    enum Keys {
        static let code = "recomendedCode"
        static let type = "recomendedType"
        static let savedAt = "timeStartSave"
    }

    /// How long a stored source keeps colouring events. Unchanged from the original implementation.
    private static let ttl: TimeInterval = 48 * 60 * 60

    private let store: UserDefaults
    private let legacy: UserDefaults

    init(store: UserDefaults, legacy: UserDefaults = .standard) {
        self.store = store
        self.legacy = legacy
    }

    func store(type: String, code: String) {
        store.setValue(Date().timeIntervalSince1970, forKey: Keys.savedAt)
        store.setValue(code, forKey: Keys.code)
        store.setValue(type, forKey: Keys.type)
    }

    func clear() {
        // The shared domain of a pre-partition install too: read as a fallback, it would come back.
        for defaults in [store, legacy] {
            defaults.removeObject(forKey: Keys.code)
            defaults.removeObject(forKey: Keys.type)
            defaults.removeObject(forKey: Keys.savedAt)
        }
    }

    func currentSource() -> (type: String, code: String)? {
        if let source = read(from: store) { return source }
        // Pre-partition install: adopt whatever the shared domain still holds for the rest of its
        // window. Not copied over — it expires on its own, and later shops must not inherit it.
        return read(from: legacy)
    }

    private func read(from defaults: UserDefaults) -> (type: String, code: String)? {
        let savedAt = defaults.double(forKey: Keys.savedAt)
        guard savedAt > 0, Date().timeIntervalSince1970 - savedAt <= Self.ttl else {
            // Expired (or never set) — drop the values so a later read is cheap.
            defaults.setValue(nil, forKey: Keys.code)
            defaults.setValue(nil, forKey: Keys.type)
            return nil
        }
        guard let type = defaults.string(forKey: Keys.type), !type.isEmpty,
              let code = defaults.string(forKey: Keys.code), !code.isEmpty else {
            return nil
        }
        return (type: type, code: code)
    }
}

extension TrackEventServiceImpl {

    /// The SDK's own instance the events go through: the events only its new core sends
    /// (`TrackingAPI.bannerView`, `bannerClick`) need it. `nil` for another conformer of the protocol.
    var instance: SimplePersonalizationSDK? {
        sdk as? SimplePersonalizationSDK
    }
}
