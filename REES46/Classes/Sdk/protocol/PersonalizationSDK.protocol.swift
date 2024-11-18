//
//  PersonalizationSDK.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation
import UIKit

public protocol PersonalizationSDK {
    var shopId: String { get }
    var deviceId: String { get }
    var userSeance: String { get }
    var segment: String { get }
    var storiesCode: String? { get }
    var sessionQueue: SessionQueue { get }
    var urlSession: URLSession { get set }
    
    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void)
    func getRequest(path: String, params: [String: String], _ isInit: Bool, completion: @escaping (Result<[String: Any], SdkError>) -> Void)
    func configureURLSession(configuration: URLSessionConfiguration)
    func generateString(array : [String]) -> String
    
    func setProfileData(userEmail: String?, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: Int?, firstName: String?, lastName: String?, location: String?, gender: Gender?, fbID: String?, vkID: String?, telegramId: String?, loyaltyCardLocation: String?, loyaltyStatus: String?, loyaltyBonuses: Int?, loyaltyBonusesToNextLevel: Int?, boughtSomething: Bool?, userId: String?, customProperties: [String: Any?]?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func trackSource(source: RecommendedByCase, code: String)
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SdkError>) -> Void)
    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?,timeOut: Double?, withLocations: Bool, extended: Bool, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void)
    func suggest(query: String, locations: String?, timeOut: Double?, extended: String?, completion: @escaping(Result<SearchResponse, SdkError>) -> Void)
    func getProductsList(brands: String?, merchants: String?, categories: String?, locations: String?, limit: Int?, page: Int?, filters: [String: Any]?, completion: @escaping(Result<ProductsListResponse, SdkError>) -> Void)
    func getProductsFromCart(completion: @escaping(Result<[CartItem], SdkError>) -> Void)
    func getProductInfo(id: String, completion: @escaping(Result<ProductInfo, SdkError>) -> Void)
    func getDeviceId() -> String
    func getSession() -> String
    func getCurrentSegment() -> String
    func getShopId() -> String
    func setPushTokenNotification(token: String, isFirebaseNotification: Bool, completion: @escaping(Result<Void, SdkError>) -> Void)
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func searchBlank(completion: @escaping(Result<SearchBlankResponse, SdkError>) -> Void)
    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?,brandLimit: Int?, categories: [Int]?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping(Result<SearchResponse, SdkError>) -> Void)
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
    func addToSegment(segmentId: String, email: String?, phone: String?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func removeFromSegment(segmentId: String, email: String?, phone: String?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func manageSubscription(email: String?, phone: String?, userExternalId: String?, userLoyaltyId: String?, telegramId: String?, emailBulk: Bool?, emailChain: Bool?, emailTransactional: Bool?, smsBulk: Bool?, smsChain: Bool?, smsTransactional: Bool?, webPushBulk: Bool?, webPushChain: Bool?, webPushTransactional: Bool?, mobilePushBulk: Bool?, mobilePushChain: Bool?, mobilePushTransactional: Bool?, completion: @escaping(Result<Void, SdkError>) -> Void)
    func configuration() -> SdkConfiguration.Type
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void)
    func deleteUserCredentials()
}

public extension PersonalizationSDK {
    func setPushTokenNotification(token: String,isFirebaseNotification: Bool = false, completion: @escaping(Result<Void, SdkError>) -> Void) {
        setPushTokenNotification(token: token, isFirebaseNotification: isFirebaseNotification, completion: completion)
    }
    
    func review(rate: Int, channel: String, category: String, orderId: String? = nil, comment: String? = nil, completion: @escaping(Result<Void, SdkError>) -> Void) {
        review(rate: rate, channel: channel, category: category, orderId: orderId, comment: comment, completion: completion)
    }
    
    func setProfileData(userEmail: String? = nil, userPhone: String? = nil, userLoyaltyId: String? = nil, birthday: Date? = nil, age: Int? = nil, firstName: String? = nil, lastName: String? = nil, location: String? = nil, gender: Gender? = nil, fbID: String? = nil, vkID: String? = nil, telegramId: String? = nil, loyaltyCardLocation: String? = nil, loyaltyStatus: String? = nil, loyaltyBonuses: Int? = nil, loyaltyBonusesToNextLevel: Int? = nil, boughtSomething: Bool? = nil, userId: String? = nil, customProperties: [String: Any?]? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        setProfileData(userEmail: userEmail, userPhone: userPhone, userLoyaltyId: userLoyaltyId, birthday: birthday, age: age, firstName: firstName, lastName: lastName, location: location, gender: gender, fbID: fbID, vkID: vkID, telegramId: telegramId, loyaltyCardLocation: loyaltyCardLocation, loyaltyStatus: loyaltyStatus, loyaltyBonuses: loyaltyBonuses, loyaltyBonusesToNextLevel: loyaltyBonusesToNextLevel, boughtSomething: boughtSomething, userId: userId, customProperties: customProperties, completion: completion)
    }
    
    func recommend(blockId: String, currentProductId: String? = nil, currentCategoryId: String? = nil, locations: String? = nil, imageSize: String? = nil, timeOut: Double? = nil, withLocations: Bool = false, extended: Bool = false, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void) {
        recommend(blockId: blockId, currentProductId: currentProductId, currentCategoryId: currentCategoryId, locations: locations, imageSize: imageSize, timeOut: timeOut, withLocations: withLocations, extended: extended, completion: completion)
    }
    
    func suggest(query: String, locations: String? = nil, timeOut: Double? = nil, extended: String? = nil, completion: @escaping(Result<SearchResponse, SdkError>) -> Void) {
        suggest(query: query, locations: locations, timeOut: timeOut, extended: extended, completion: completion)
    }
    
    func getProductsList(brands: String? = nil, merchants: String? = nil, categories: String? = nil, locations: String? = nil, limit: Int? = nil, page: Int? = nil, filters: [String: Any]? = nil, completion: @escaping(Result<ProductsListResponse, SdkError>) -> Void) {
        getProductsList(brands: brands, merchants: merchants, categories: categories, locations: locations, limit:limit, page: page, filters: filters, completion: completion)
    }
    
    func getProductsFromCart(completion: @escaping(Result<[CartItem], SdkError>) -> Void) {
        getProductsFromCart(completion: completion)
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
    }
    
    func track(event: Event, recommendedBy: RecomendedBy? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        track(event: event, recommendedBy: recommendedBy, completion: completion)
    }
    
    func trackEvent(event: String, category: String? = nil, label: String? = nil, value: Int? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackEvent(event: event, category: category, label: label, value: value, completion: completion)
    }
    
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        notificationClicked(type: type, code: code, completion: completion)
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
        subscribeForBackInStock(
            id: id,
            email: email,
            phone: phone,
            fashionSize: fashionSize,
            fashionColor:fashionColor,
            barcode: barcode,
            completion: completion
        )
    }
    
    func unsubscribeForBackInStock(
        itemIds: [String],
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        unsubscribeForBackInStock(itemIds: itemIds, email: email,phone:phone,completion: completion)
    }
    
    func unsubscribeForPriceDrop(
        itemIds: [String],
        currentPrice: Double,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ){
        unsubscribeForPriceDrop(itemIds: itemIds,currentPrice: currentPrice, email: email,phone:phone,completion: completion)
    }
    
    func subscribeForPriceDrop(
        id: String,
        currentPrice: Double,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        subscribeForPriceDrop(id: id, currentPrice: currentPrice, email: email, phone: phone, completion: completion)
    }
    
    func addToSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        addToSegment(segmentId: segmentId, email: email, phone: phone, completion: completion)
    }
    
    func removeFromSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping(Result<Void, SdkError>) -> Void) {
        removeFromSegment(segmentId: segmentId, email: email, phone: phone, completion: completion)
    }
    
    func manageSubscription(email: String? = nil, phone: String? = nil, userExternalId: String? = nil, userLoyaltyId: String? = nil, telegramId: String? = nil, emailBulk: Bool? = nil, emailChain: Bool? = nil, emailTransactional: Bool? = nil, smsBulk: Bool? = nil, smsChain: Bool? = nil, smsTransactional: Bool? = nil, webPushBulk: Bool? = nil, webPushChain: Bool? = nil, webPushTransactional: Bool? = nil, mobilePushBulk: Bool? = nil, mobilePushChain: Bool? = nil, mobilePushTransactional: Bool? = nil, completion: @escaping(Result<Void, SdkError>) -> Void) {
        manageSubscription(email: email, phone: phone, userExternalId: userExternalId, userLoyaltyId: userLoyaltyId, telegramId: telegramId, emailBulk: emailBulk, emailChain: emailChain, emailTransactional: emailTransactional, smsBulk: smsBulk, smsChain: smsChain, smsTransactional: smsTransactional, webPushBulk: webPushBulk, webPushChain: webPushChain, webPushTransactional: webPushTransactional, mobilePushBulk: mobilePushBulk, mobilePushChain: mobilePushChain, mobilePushTransactional: mobilePushTransactional, completion: completion)
    }
    
    func deleteUserCredentials() {
        deleteUserCredentials()
    }
    
    func resetSdkCache() {
        let included_prefixes = ["viewed.slide."]
        let dict = UserDefaults.standard.dictionaryRepresentation()
        let keys = dict.keys.filter { key in
            for prefix in included_prefixes {
                if key.hasPrefix(prefix) {
                    return true
                }
            }
            return false
        }
        for key in keys {
            if dict[key] != nil { 
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.synchronize()
        resetDownloadedStoriesStates()
    }
    
    func resetDownloadedStoriesStates() {
        let included_prefixes = ["cached.slide."]
        let dict = UserDefaults.standard.dictionaryRepresentation()
        let keys = dict.keys.filter { key in
            for prefix in included_prefixes {
                if key.hasPrefix(prefix) {
                    return true
                }
            }
            return false
        }
        for key in keys {
            if dict[key] != nil {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.synchronize()
    }
    
    func resetCartProductStates() {
        let included_prefixes = ["cart.product."]
        let dict = UserDefaults.standard.dictionaryRepresentation()
        let keys = dict.keys.filter { key in
            for prefix in included_prefixes {
                if key.hasPrefix(prefix) {
                    return true
                }
            }
            return false
        }
        for key in keys {
            if dict[key] != nil {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.synchronize()
    }
    
    func resetFavoritesProductStates() {
        let included_prefixes = ["favorites.product."]
        let dict = UserDefaults.standard.dictionaryRepresentation()
        let keys = dict.keys.filter { key in
            for prefix in included_prefixes {
                if key.hasPrefix(prefix) {
                    return true
                }
            }
            return false
        }
        for key in keys {
            if dict[key] != nil {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.synchronize()
    }
}


public func createPersonalizationSDK(
    shopId: String,
    userEmail: String? = nil,
    userPhone: String? = nil,
    userLoyaltyId: String? = nil,
    apiDomain: String = "",
    stream: String = "ios",
    enableLogs: Bool = false,
    autoSendPushToken: Bool = true,
    parentViewController: UIViewController? = nil,
    _ completion: ((SdkError?) -> Void)? = nil
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
        parentViewController: parentViewController!,
        completion: completion
    )
    
    sdk.resetSdkCache()
    
    return sdk
}
