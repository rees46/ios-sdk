//
//  PersonalizationSDK.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Main SDK Protocol

public protocol PersonalizationSDK {
    var shopId: String { get }
    var deviceId: String { get }
    var userSeance: String { get }
    var segment: String { get }
    var storiesCode: String? { get }
    var sessionQueue: SessionQueue { get }
    var parentViewController: UIViewController? {get}
    var urlSession: URLSession { get set }
    
    // New popup presentation properties
    var popupPresentationDelegate: PopupPresentationDelegate? { get set }
    var enableAutoPopupPresentation: Bool { get set }
    var popupPresenter: PopupPresenter { get }
    
    /// Standard tracking events, grouped: `sdk.tracking.productView(itemId:)`, `.addToCart(item:)`, …
    ///
    /// Conformers get a working implementation for free (see the default below), so adding this
    /// requirement does not break types that already conform.
    var tracking: TrackingAPI { get }

    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void)
    func getRequest(path: String, params: [String: String], _ isInit: Bool, completion: @escaping (Result<[String: Any], SdkError>) -> Void)
    func configureURLSession(configuration: URLSessionConfiguration)
    func generateString(array : [String]) -> String
    
    func setProfileData(userEmail: String?, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: Int?, firstName: String?, lastName: String?, location: String?, gender: Gender?,  advertisingId: String?, fbID: String?, vkID: String?, telegramId: String?, loyaltyCardLocation: String?, loyaltyStatus: String?, loyaltyBonuses: Int?, loyaltyBonusesToNextLevel: Int?, boughtSomething: Bool?, userId: String?, customProperties: [String: Any?]?, completion: @escaping (Result<Void, SdkError>) -> Void)
    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.productView(itemId:), .addToCart(item:), .storyView(storyId:slideId:) and the rest.")
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.purchase(request).")
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.setSource(TrackingSource(type:code:)).")
    func trackSource(source: RecommendedByCase, code: String)
    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.custom(event:).")
    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void)
    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?,timeOut: Double?, withLocations: Bool, extended: Bool, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void)
    /// Instant search. `excludedMerchants` applies only together with non-empty `locations`: the server
    /// filters merchants inside the given locations, so without them the parameter is not sent.
    func suggest(query: String, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void)
    func getProductsList(brands: String?, merchants: String?, categories: String?, locations: String?, limit: Int?, page: Int?, filters: [String: Any]?, completion: @escaping(Result<ProductsListResponse, SdkError>) -> Void)
    func getProductsFromCart(completion: @escaping(Result<[CartItem], SdkError>) -> Void)
    func getProductInfo(id: String, completion: @escaping(Result<ProductInfo, SdkError>) -> Void)
    func getLastOrderProducts(completion: @escaping(Result<LastOrderProductsResponse, SdkError>) -> Void)
    func getUserOrders(shopSecret: String, did: String?, email: String?, phone: String?, loyaltyId: String?, externalId: String?, dateFrom: String?, completion: @escaping(Result<[Order], SdkError>) -> Void)
    /// Notification history (`GET /notifications`). Has a default implementation below, so types that
    /// already conform keep compiling.
    func getAllNotifications(shopSecret: String, type: String, phone: String?, email: String?, userExternalId: String?, userLoyaltyId: String?, channel: String?, limit: Int?, page: Int?, dateFrom: String?, completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void)
    func joinLoyalty(phone: String, email: String?, firstName: String?, lastName: String?, completion: @escaping(Result<LoyaltyJoinResponse, SdkError>) -> Void)
    func getLoyaltyStatus(identifier: String, completion: @escaping(Result<LoyaltyStatusResponse, SdkError>) -> Void)
    func getProfile(completion: @escaping(Result<GetProfileResponse, SdkError>) -> Void)
    func getProductCounters(item: String, completion: @escaping(Result<ProductCountersResponse, SdkError>) -> Void)
    func getCategory(category: String, limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, completion: @escaping(Result<CategoryResponse, SdkError>) -> Void)
    /// Category page with a price range and sorting on top of brands and facets. Has a default
    /// implementation below, so types that already conform keep compiling.
    func getCategory(category: String, limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, sortBy: String?, sortDir: String?, completion: @escaping(Result<CategoryResponse, SdkError>) -> Void)
    func getCollection(collectionId: String, location: String?, email: String?, phone: String?, externalId: String?, loyaltyId: String?, completion: @escaping(Result<CollectionResponse, SdkError>) -> Void)
    func getDeviceId() -> String
    @available(*, deprecated, message: "Use enableAutoPopupPresentation or popupPresentationDelegate instead")
    func setParentViewController(controller: UIViewController, completion: @escaping () -> Void)
    func getNotificationWidget() -> NotificationWidget?
    func getSession() -> String
    func getCurrentSegment() -> String
    func getShopId() -> String
    func setPushTokenNotification(token: String, isFirebaseNotification: Bool, completion: @escaping(Result<Void, SdkError>) -> Void)
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func searchBlank(completion: @escaping(Result<SearchBlankResponse, SdkError>) -> Void)
    /// Full search. `excludedMerchants` applies only together with non-empty `locations`, as in `suggest`.
    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?,brandLimit: Int?, categories: [Int]?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping(Result<SearchResponse, SdkError>) -> Void)
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void)
    func notificationDelivered(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void)
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void)
    func subscribeForBackInStock(
        id: String,
        email: String?,
        phone: String?,
        fashionSize: String?,
        fashionColor: String?,
        barcode: String?,
        completion: @escaping(Result<Void, SdkError>) -> Void
    )
    func unsubscribeForBackInStock(itemIds: [String], email: String?, phone: String? , completion: @escaping (Result<Void, SdkError>) -> Void)
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String?, phone: String?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func unsubscribeForPriceDrop(
        itemIds: [String],
        currentPrice: Double,
        email: String?,
        phone: String?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    )
    func getStories(code: String, completion: @escaping(Result<StoryContent, SdkError>) -> Void)
    func getProbabilityToPurchase(params: PurchasePredictParams, completion: @escaping (Result<ProbabilityToPurchaseResponse, SdkError>) -> Void)
    func addToSegment(segmentId: String, email: String?, phone: String?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func removeFromSegment(segmentId: String, email: String?, phone: String?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func manageSubscription(email: String?, phone: String?, userExternalId: String?, userLoyaltyId: String?, telegramId: String?, emailBulk: Bool?, emailChain: Bool?, emailTransactional: Bool?, smsBulk: Bool?, smsChain: Bool?, smsTransactional: Bool?, webPushBulk: Bool?, webPushChain: Bool?, webPushTransactional: Bool?, mobilePushBulk: Bool?, mobilePushChain: Bool?, mobilePushTransactional: Bool?, telegramBulk: Bool?, telegramChain: Bool?, telegramTransactional: Bool?, whatsappBulk: Bool?, whatsappChain: Bool?, whatsappTransactional: Bool?, maxBulk: Bool?, maxChain: Bool?, maxTransactional: Bool?, walletBulk: Bool?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func configuration() -> SdkConfiguration.Type
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void)
    func deleteUserCredentials()
}

public extension PersonalizationSDK {

    /// Default `tracking` implementation, so conformers that predate the namespace keep compiling.
    /// Seeing only the public protocol, it builds its own services; `SimplePersonalizationSDK`
    /// overrides it with one that reuses the SDK's own long-lived services.
    var tracking: TrackingAPI {
        TrackingAPIImpl(sdk: self)
    }

    func setPushTokenNotification(token: String,isFirebaseNotification: Bool = false, completion: @escaping(Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            setPushTokenNotification(token: token, isFirebaseNotification: isFirebaseNotification, completion: completion)
        }, orFail: completion)
    }
    
    func review(rate: Int, channel: String, category: String, orderId: String? = nil, comment: String? = nil, completion: @escaping(Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            review(rate: rate, channel: channel, category: category, orderId: orderId, comment: comment, completion: completion)
        }, orFail: completion)
    }
    
    func setProfileData(userEmail: String? = nil, userPhone: String? = nil, userLoyaltyId: String? = nil, birthday: Date? = nil, age: Int? = nil, firstName: String? = nil, lastName: String? = nil, location: String? = nil, gender: Gender? = nil, advertisingId: String? = nil, fbID: String? = nil, vkID: String? = nil, telegramId: String? = nil, loyaltyCardLocation: String? = nil, loyaltyStatus: String? = nil, loyaltyBonuses: Int? = nil, loyaltyBonusesToNextLevel: Int? = nil, boughtSomething: Bool? = nil, userId: String? = nil, customProperties: [String: Any?]? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            setProfileData(userEmail: userEmail, userPhone: userPhone, userLoyaltyId: userLoyaltyId, birthday: birthday, age: age, firstName: firstName, lastName: lastName, location: location, gender: gender, advertisingId: advertisingId, fbID: fbID, vkID: vkID, telegramId: telegramId, loyaltyCardLocation: loyaltyCardLocation, loyaltyStatus: loyaltyStatus, loyaltyBonuses: loyaltyBonuses, loyaltyBonusesToNextLevel: loyaltyBonusesToNextLevel, boughtSomething: boughtSomething, userId: userId, customProperties: customProperties, completion: completion)
        }, orFail: completion)
    }
    
    func recommend(blockId: String, currentProductId: String? = nil, currentCategoryId: String? = nil, locations: String? = nil, imageSize: String? = nil, timeOut: Double? = nil, withLocations: Bool = false, extended: Bool = false, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            recommend(blockId: blockId, currentProductId: currentProductId, currentCategoryId: currentCategoryId, locations: locations, imageSize: imageSize, timeOut: timeOut, withLocations: withLocations, extended: extended, completion: completion)
        }, orFail: completion)
    }
    
    func suggest(query: String, locations: String? = nil, excludedMerchants: [String]? = nil, excludedBrands: [String]? = nil, timeOut: Double? = nil, extended: String? = nil, completion: @escaping(Result<SearchResponse, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            suggest(query: query, locations: locations, excludedMerchants: excludedMerchants, excludedBrands: excludedBrands, timeOut: timeOut, extended: extended, completion: completion)
        }, orFail: completion)
    }
    
    func getProductsList(brands: String? = nil, merchants: String? = nil, categories: String? = nil, locations: String? = nil, limit: Int? = nil, page: Int? = nil, filters: [String: Any]? = nil, completion: @escaping(Result<ProductsListResponse, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            getProductsList(brands: brands, merchants: merchants, categories: categories, locations: locations, limit:limit, page: page, filters: filters, completion: completion)
        }, orFail: completion)
    }
    
    func getProductsFromCart(completion: @escaping(Result<[CartItem], SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            getProductsFromCart(completion: completion)
        }, orFail: completion)
    }

    func getUserOrders(shopSecret: String, did: String? = nil, email: String? = nil, phone: String? = nil, loyaltyId: String? = nil, externalId: String? = nil, dateFrom: String? = nil, completion: @escaping(Result<[Order], SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            getUserOrders(shopSecret: shopSecret, did: did, email: email, phone: phone, loyaltyId: loyaltyId, externalId: externalId, dateFrom: dateFrom, completion: completion)
        }, orFail: completion)
    }

    /// Notification history: `GET /notifications`. The endpoint is server-to-server and needs the shop
    /// secret — without it the API answers 400 "Incorrect shop credentials".
    ///
    /// Default implementation of the requirement: it builds its own notification service, so
    /// conformers that predate the method (mocks in apps) keep compiling and working. Shorter calls
    /// are the overloads below; they go through the requirement, so a conformer's own
    /// implementation receives them too.
    func getAllNotifications(shopSecret: String, type: String, phone: String?, email: String?, userExternalId: String?, userLoyaltyId: String?, channel: String?, limit: Int?, page: Int?, dateFrom: String?, completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void) {
        NotificationHandlerServiceImpl(sdk: self).getAllNotifications(
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

    /// Notification history of `type`, no filters.
    func getAllNotifications(shopSecret: String, type: String, completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void) {
        getAllNotifications(shopSecret: shopSecret, type: type, phone: nil, email: nil, userExternalId: nil, userLoyaltyId: nil, channel: nil, limit: nil, page: nil, dateFrom: nil, completion: completion)
    }

    /// One page of the notification history of `type`.
    func getAllNotifications(shopSecret: String, type: String, limit: Int?, page: Int?, completion: @escaping(Result<UserPayloadResponse, SdkError>) -> Void) {
        getAllNotifications(shopSecret: shopSecret, type: type, phone: nil, email: nil, userExternalId: nil, userLoyaltyId: nil, channel: nil, limit: limit, page: page, dateFrom: nil, completion: completion)
    }

    func joinLoyalty(phone: String, email: String? = nil, firstName: String? = nil, lastName: String? = nil, completion: @escaping(Result<LoyaltyJoinResponse, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            joinLoyalty(phone: phone, email: email, firstName: firstName, lastName: lastName, completion: completion)
        }, orFail: completion)
    }

    func getCategory(category: String, limit: Int? = nil, page: Int? = nil, brands: String? = nil, locations: String? = nil, filters: [String: Any]? = nil, completion: @escaping(Result<CategoryResponse, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            getCategory(category: category, limit: limit, page: page, brands: brands, locations: locations, filters: filters, completion: completion)
        }, orFail: completion)
    }

    /// Category page (`GET /category/{category}`) with a price range (`price_min` / `price_max`) and
    /// sorting (`sort_by`: `price`, `discount`, `popular`, …; `sort_dir`: `asc` / `desc`) on top of
    /// brands (comma-separated) and facets (`filters`, name → values).
    ///
    /// Default implementation of the requirement, so conformers that predate it keep compiling and
    /// working: with no price or sorting asked the call goes to their own `getCategory` above,
    /// otherwise the request goes out through their `getRequest`.
    func getCategory(category: String, limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, sortBy: String?, sortDir: String?, completion: @escaping(Result<CategoryResponse, SdkError>) -> Void) {
        guard priceMin != nil || priceMax != nil || sortBy != nil || sortDir != nil else {
            return getCategory(category: category, limit: limit, page: page, brands: brands, locations: locations, filters: filters, completion: completion)
        }
        let params = categoryParams(limit: limit, page: page, brands: brands, locations: locations, filters: filters, priceMin: priceMin, priceMax: priceMax, sortBy: sortBy, sortDir: sortDir)
        getRequest(path: "category/\(category)", params: params, false) { result in
            completion(result.map { CategoryResponse(json: $0) })
        }
    }

    func getCollection(collectionId: String, location: String? = nil, email: String? = nil, phone: String? = nil, externalId: String? = nil, loyaltyId: String? = nil, completion: @escaping(Result<CollectionResponse, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            getCollection(collectionId: collectionId, location: location, email: email, phone: phone, externalId: externalId, loyaltyId: loyaltyId, completion: completion)
        }, orFail: completion)
    }

    func search(
        query: String,
        limit: Int? = nil,
        offset: Int? = nil,
        categoryLimit: Int? = nil,
        brandLimit: Int? = nil,
        categories: [Int]? = nil,
        extended: String? = nil,
        sortBy: String? = nil,
        sortDir: String? = nil,
        locations: String? = nil,
        excludedMerchants: [String]? = nil,
        excludedBrands: [String]? = nil,
        brands: String? = nil,
        filters: [String: Any]? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        colors: [String]? = nil,
        fashionSizes: [String]? = nil,
        exclude: String? = nil,
        email: String? = nil,
        timeOut: Double? = nil,
        disableClarification: Bool? = nil,
        completion: @escaping(Result<SearchResponse, SdkError>) -> Void
    ) {
        ProtocolDefault.forward(on: self, to: {
            search(
                query:query,
                limit:limit,
                offset:offset,
                categoryLimit:categoryLimit,
                brandLimit:brandLimit,
                categories:categories,
                extended:extended,
                sortBy:sortBy,
                sortDir:sortDir,
                locations:locations,
                excludedMerchants:excludedMerchants,
                excludedBrands:excludedBrands,
                brands:brands,
                filters:filters,
                priceMin:priceMin,
                priceMax:priceMax,
                colors:colors,
                fashionSizes:fashionSizes,
                exclude:exclude,
                email:email,
                timeOut:timeOut,
                disableClarification:disableClarification,
                completion: completion
            )
        }, orFail: completion)
    }
    
    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.productView(itemId:), .addToCart(item:), .storyView(storyId:slideId:) and the rest.")
    func track(event: Event, recommendedBy: RecomendedBy? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            track(event: event, recommendedBy: recommendedBy, completion: completion)
        }, orFail: completion)
    }

    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.purchase(request).")
    func trackPurchase(_ request: PurchaseTrackingRequest, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackPurchase(request, recommendedBy: nil, completion: completion)
    }
    
    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.custom(event:).")
    func trackEvent(
        event: String,
        category: String? = nil,
        label: String? = nil,
        value: Int? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        trackEvent(event: event, time: nil, category: category, label: label, value: value, customFields: nil, completion: completion)
    }
    
    @available(*, deprecated, message: "Use the tracking namespace: sdk.tracking.custom(event:).")
    func trackEvent(
        event: String,
        time: Int? = nil,
        category: String? = nil,
        label: String? = nil,
        value: Int? = nil,
        customFields: [String: Any]? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        ProtocolDefault.forward(on: self, to: {
            trackEvent(event: event, time: time, category: category, label: label, value: value, customFields: customFields, completion: completion)
        }, orFail: completion)
    }
    
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            notificationClicked(type: type, code: code, completion: completion)
        }, orFail: completion)
    }
    
    func subscribeForBackInStock(
        id: String,
        email: String? = nil,
        phone: String? = nil,
        fashionSize: String? = nil,
        fashionColor: String? = nil,
        barcode: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        ProtocolDefault.forward(on: self, to: {
            subscribeForBackInStock(
                id: id,
                email: email,
                phone: phone,
                fashionSize: fashionSize,
                fashionColor:fashionColor,
                barcode: barcode,
                completion: completion
            )
        }, orFail: completion)
    }
    
    func unsubscribeForBackInStock(
        itemIds: [String],
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        ProtocolDefault.forward(on: self, to: {
            unsubscribeForBackInStock(itemIds: itemIds, email: email,phone:phone,completion: completion)
        }, orFail: completion)
    }
    
    func unsubscribeForPriceDrop(
        itemIds: [String],
        currentPrice: Double,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ){
        ProtocolDefault.forward(on: self, to: {
            unsubscribeForPriceDrop(itemIds: itemIds,currentPrice: currentPrice, email: email,phone:phone,completion: completion)
        }, orFail: completion)
    }
    
    func subscribeForPriceDrop(
        id: String,
        currentPrice: Double,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        ProtocolDefault.forward(on: self, to: {
            subscribeForPriceDrop(id: id, currentPrice: currentPrice, email: email, phone: phone, completion: completion)
        }, orFail: completion)
    }
    
    func getProbabilityToPurchase(
        params: PurchasePredictParams = PurchasePredictParams(),
        completion: @escaping (Result<ProbabilityToPurchaseResponse, SdkError>) -> Void
    ) {
        ProtocolDefault.forward(on: self, to: {
            getProbabilityToPurchase(params: params, completion: completion)
        }, orFail: completion)
    }

    func addToSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            addToSegment(segmentId: segmentId, email: email, phone: phone, completion: completion)
        }, orFail: completion)
    }
    
    func removeFromSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping(Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            removeFromSegment(segmentId: segmentId, email: email, phone: phone, completion: completion)
        }, orFail: completion)
    }
    
    func manageSubscription(email: String? = nil, phone: String? = nil, userExternalId: String? = nil, userLoyaltyId: String? = nil, telegramId: String? = nil, emailBulk: Bool? = nil, emailChain: Bool? = nil, emailTransactional: Bool? = nil, smsBulk: Bool? = nil, smsChain: Bool? = nil, smsTransactional: Bool? = nil, webPushBulk: Bool? = nil, webPushChain: Bool? = nil, webPushTransactional: Bool? = nil, mobilePushBulk: Bool? = nil, mobilePushChain: Bool? = nil, mobilePushTransactional: Bool? = nil, telegramBulk: Bool? = nil, telegramChain: Bool? = nil, telegramTransactional: Bool? = nil, whatsappBulk: Bool? = nil, whatsappChain: Bool? = nil, whatsappTransactional: Bool? = nil, maxBulk: Bool? = nil, maxChain: Bool? = nil, maxTransactional: Bool? = nil, walletBulk: Bool? = nil, completion: @escaping(Result<Void, SdkError>) -> Void) {
        ProtocolDefault.forward(on: self, to: {
            manageSubscription(email: email, phone: phone, userExternalId: userExternalId, userLoyaltyId: userLoyaltyId, telegramId: telegramId, emailBulk: emailBulk, emailChain: emailChain, emailTransactional: emailTransactional, smsBulk: smsBulk, smsChain: smsChain, smsTransactional: smsTransactional, webPushBulk: webPushBulk, webPushChain: webPushChain, webPushTransactional: webPushTransactional, mobilePushBulk: mobilePushBulk, mobilePushChain: mobilePushChain, mobilePushTransactional: mobilePushTransactional, telegramBulk: telegramBulk, telegramChain: telegramChain, telegramTransactional: telegramTransactional, whatsappBulk: whatsappBulk, whatsappChain: whatsappChain, whatsappTransactional: whatsappTransactional, maxBulk: maxBulk, maxChain: maxChain, maxTransactional: maxTransactional, walletBulk: walletBulk, completion: completion)
        }, orFail: completion)
    }
    
    func deleteUserCredentials() {
        ProtocolDefault.forward(on: self, to: {
            deleteUserCredentials()
        })
    }
    
    // R2: these caches are partitioned per shop — delegate to the shop's [LocalStateRepository] via
    // the internal `localState` bridge instead of scanning the shared `.standard` domain.
    func resetSdkCache() {
        localState?.clearViewedSlides()
        resetDownloadedStoriesStates()
    }

    func resetDownloadedStoriesStates() {
        localState?.clearDownloadedMedia()
    }

    func resetCartProductStates() {
        localState?.clearCartProducts()
    }

    func resetFavoritesProductStates() {
        localState?.clearFavoriteProducts()
    }
}

extension PersonalizationSDK {

    /// `getRequest` with the call's own timeout, for the SDK's services. The SDK's own client gives
    /// the timeout to the request; another conformer gets the call as before.
    func getRequest(path: String, params: [String: String], timeout: TimeInterval?, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        if let client = self as? SimplePersonalizationSDK {
            client.getRequest(path: path, params: params, timeout: timeout, completion: completion)
        } else {
            getRequest(path: path, params: params, false, completion: completion)
        }
    }

    /// `postRequest` with the call's own timeout, for the SDK's services.
    func postRequest(path: String, params: [String: Any], timeout: TimeInterval?, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        if let client = self as? SimplePersonalizationSDK {
            client.postRequest(path: path, params: params, timeout: timeout, completion: completion)
        } else {
            postRequest(path: path, params: params, completion: completion)
        }
    }

    /// Query of `GET /category/{category}`: the session plus whatever was asked. Shared by the SDK's
    /// own `getCategory` and the protocol's default one.
    func categoryParams(limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, sortBy: String?, sortDir: String?) -> [String: String] {
        var params: [String: String] = [
            "shop_id": shopId,
            "did": deviceId,
            "seance": userSeance,
            "sid": userSeance
        ]
        if let limit = limit { params["limit"] = String(limit) }
        if let page = page { params["page"] = String(page) }
        if let brands = brands { params["brands"] = brands }
        if let locations = locations { params["locations"] = locations }
        if let filters = filters,
           let data = try? JSONSerialization.data(withJSONObject: filters, options: []),
           let text = String(data: data, encoding: .utf8) {
            params["filters"] = text
        }
        // The same wire format as the search sends.
        if let priceMin = priceMin { params[SdkConstants.priceMin] = String(describing: priceMin) }
        if let priceMax = priceMax { params[SdkConstants.priceMax] = String(describing: priceMax) }
        if let sortBy = sortBy { params[SdkConstants.sortBy] = sortBy }
        if let sortDir = sortDir { params[SdkConstants.sortDir] = sortDir }
        return params
    }
}

/**
 Creates and registers a single SDK instance.

 Deprecated in favour of the multi-instance `Rees46` facade (R3): `Rees46.initialize(_:)` for an eager
 instance, or `Rees46.register(shops:)` + `Rees46.instance(for:)` for several shops. It still works and
 still registers the instance (same return type), so existing hosts keep compiling and running.
 */
@available(*, deprecated, message: "Use Rees46.initialize(_:) or Rees46.register(shops:) + Rees46.instance(for:)")
public func createPersonalizationSDK(
    shopId: String,
    userEmail: String? = nil,
    userPhone: String? = nil,
    userLoyaltyId: String? = nil,
    apiDomain: String = "api.rees46.ru",
    stream: String = "ios",
    enableLogs: Bool = false,
    autoSendPushToken: Bool = true,
    sendAdvertisingId: Bool = false,
    parentViewController: UIViewController? = nil,
    enableAutoPopupPresentation: Bool = true,
    needReInitialization: Bool = false,
    storageKey: String? = nil,
    _ completion: ((SdkError?) -> Void)? = nil
) -> PersonalizationSDK {
    makeRegisteredSDK(
        shopId: shopId,
        userEmail: userEmail,
        userPhone: userPhone,
        userLoyaltyId: userLoyaltyId,
        apiDomain: apiDomain,
        stream: stream,
        enableLogs: enableLogs,
        autoSendPushToken: autoSendPushToken,
        sendAdvertisingId: sendAdvertisingId,
        parentViewController: parentViewController,
        enableAutoPopupPresentation: enableAutoPopupPresentation,
        needReInitialization: needReInitialization,
        storageKey: storageKey,
        completion: completion
    )
}

/**
 Builds a `SimplePersonalizationSDK`, resets its per-shop stories cache, and registers it so it can be
 resolved by `shop_id` and joins the push fan-out set.

 The single construction path shared by the (soon-deprecated) `createPersonalizationSDK` and the
 `Rees46` facade — keeping registration and cache-reset in one place. The registry holds the instance
 weakly, so this does not extend its lifetime; it drops out on dealloc or `deleteUserCredentials`.
 */
internal func makeRegisteredSDK(
    shopId: String,
    userEmail: String? = nil,
    userPhone: String? = nil,
    userLoyaltyId: String? = nil,
    apiDomain: String = "api.rees46.ru",
    stream: String = "ios",
    enableLogs: Bool = false,
    autoSendPushToken: Bool = true,
    sendAdvertisingId: Bool = false,
    parentViewController: UIViewController? = nil,
    enableAutoPopupPresentation: Bool = true,
    needReInitialization: Bool = false,
    storageKey: String? = nil,
    completion: ((SdkError?) -> Void)? = nil
) -> PersonalizationSDK {
    let sdk = SimplePersonalizationSDK(
        shopId: shopId,
        userEmail: userEmail,
        userPhone: userPhone,
        userLoyaltyId: userLoyaltyId,
        apiDomain: apiDomain,
        stream: stream,
        enableLogs: enableLogs,
        autoSendPushToken: autoSendPushToken,
        sendAdvertisingId: sendAdvertisingId,
        parentViewController: parentViewController,
        enableAutoPopupPresentation: enableAutoPopupPresentation,
        needReInitialization: needReInitialization,
        storageKey: storageKey,
        completion: completion
    )

    sdk.resetSdkCache()
    SdkRegistry.shared.register(shopId: shopId, sdk: sdk)
    return sdk
}

/**
 Calls of the protocol's defaults that give a requirement its default arguments.

 Such a default has the requirement's own signature, so for a conformer without that method — an
 app's own mock — the default is the method, and its call to the requirement called itself until the
 stack ran out. A method of one instance runs once per thread: met again inside itself, the method is
 missing, and the caller gets an error instead. Another instance's call — a wrapper passing the call
 on to the SDK it wraps — runs.
 */
enum ProtocolDefault {

    private static let runningKey = "com.personalization.sdk.protocolDefaults"

    /// Runs `call` — the requirement — unless `method` already runs on this thread; then `completion`
    /// gets the error that the conformer does not implement it.
    static func forward<T>(
        _ method: String = #function,
        on sdk: PersonalizationSDK,
        to call: () -> Void,
        orFail completion: (Result<T, SdkError>) -> Void
    ) {
        let key = runningKey(method, sdk)
        guard enter(key) else {
            return completion(.failure(.custom(error: "\(method) is not implemented by this PersonalizationSDK")))
        }
        defer { leave(key) }
        call()
    }

    /// Runs `call` unless `method` already runs on this thread; then nothing happens.
    static func forward(_ method: String = #function, on sdk: PersonalizationSDK, to call: () -> Void) {
        let key = runningKey(method, sdk)
        guard enter(key) else {
            print("\(method) is not implemented by this PersonalizationSDK")
            return
        }
        defer { leave(key) }
        call()
    }

    /// `method` of this instance; a conformer that is not a class has no identity, its type stands in.
    private static func runningKey(_ method: String, _ sdk: PersonalizationSDK) -> String {
        if type(of: sdk) is AnyClass {
            return "\(method)#\(ObjectIdentifier(sdk as AnyObject).hashValue)"
        }
        return "\(method)#\(String(reflecting: type(of: sdk)))"
    }

    private static func enter(_ method: String) -> Bool {
        let thread = Thread.current.threadDictionary
        var running = thread[runningKey] as? Set<String> ?? []
        guard running.insert(method).inserted else { return false }
        thread[runningKey] = running
        return true
    }

    private static func leave(_ method: String) {
        let thread = Thread.current.threadDictionary
        var running = thread[runningKey] as? Set<String> ?? []
        running.remove(method)
        thread[runningKey] = running
    }
}
