//
//  PersonalizationSDK.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation
import UIKit

public enum Event {
    case productView (id: String)
    case categoryView (id: String)
    case productAddedToFavorites(id: String)
    case productRemovedFromFavorites(id: String)
    case productAddedToCart (id: String, amount: Int = 1)
    case productRemovedFromCart (id: String)
    case search (query: String)
    case synchronizeCart (items: [CartItem])
    case synchronizeFavorites(items: [CartItem])
    case slideView(storyId: String, slideId: String)
    case slideClick(storyId: String, slideId: String)
    case orderCreated(orderId: String, totalValue: Double, products: [(id: String, amount: Int, price: Float)], deliveryAddress: String? = nil, deliveryType: String? = nil, promocode: String? = nil, paymentType: String? = nil, taxFree: Bool? = nil)
}

public enum SDKError: Error, CustomStringConvertible {
    case noError
    case incorrectAPIKey
    case initializationFailed
    case responseError
    case invalidResponse
    case decodeError
    case networkOfflineError
    case airplaneModeError
    case custom(error: String)
    
    public var description: String {
        switch self {
        case .noError:
            return "No Errors"
        case .incorrectAPIKey:
            return "Incorrect API Key"
        case .initializationFailed:
            return "Initialization Failed"
        case .responseError:
            return "Response Error"
        case .invalidResponse:
            return "Invalid Response"
        case .decodeError:
            return "Decode Error"
        case .networkOfflineError:
            return "Network Offline"
        case .airplaneModeError:
            return "Airplane Mode Error"
        case .custom(error: let error):
            return "Custom Error \(error)"
        }
    }
}

public enum PushEventType: String {
    case web = "web"
    case category = "category"
    case product = "product"
    case carousel = "carousel"
    case custom = "custom"
    
    static func findType(value: String) -> PushEventType? {
        switch value {
        case PushEventType.web.rawValue:
            return .web
        case PushEventType.category.rawValue:
            return .category
        case PushEventType.product.rawValue:
            return .product
        case PushEventType.carousel.rawValue:
            return .carousel
        case PushEventType.custom.rawValue:
            return .custom
        default:
            return nil
        }
    }
}

public protocol PersonalizationSDK {
    func setProfileData(userEmail: String?, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: Int?, firstName: String?, lastName: String?, location: String?, gender: Gender?, fbID: String?, vkID: String?, telegramId: String?, loyaltyCardLocation: String?, loyaltyStatus: String?, loyaltyBonuses: Int?, loyaltyBonusesToNextLevel: Int?, boughtSomething: Bool?, userId: String?, customProperties: [String: Any?]?, completion: @escaping (Result<Void, SDKError>) -> Void)
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SDKError>) -> Void)
    func trackSource(source: RecommendedByCase, code: String)
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SDKError>) -> Void)
    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?,timeOut: Double?, withLocations: Bool, extended: Bool, completion: @escaping (Result<RecommenderResponse, SDKError>) -> Void)
    func suggest(query: String, locations: String?, timeOut: Double?, extended: String?, completion: @escaping(Result<SearchResponse, SDKError>) -> Void)
    func getProductsList(brands: String?, merchants: String?, categories: String?, locations: String?, limit: Int?, page: Int?, filters: [String: Any]?, completion: @escaping(Result<ProductsListResponse, SDKError>) -> Void)
    func getProductsFromCart(completion: @escaping(Result<[CartItem], SDKError>) -> Void)
    func getProductInfo(id: String, completion: @escaping(Result<ProductInfo, SDKError>) -> Void)
    func getDeviceId() -> String
    func getSession() -> String
    func getCurrentSegment() -> String
    func getShopId() -> String
    func setPushTokenNotification(token: String, isFirebaseNotification: Bool, completion: @escaping(Result<Void, SDKError>) -> Void)
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping(Result<Void, SDKError>) -> Void)
    func searchBlank(completion: @escaping(Result<SearchBlankResponse, SDKError>) -> Void)
    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, categories: String?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping(Result<SearchResponse, SDKError>) -> Void)
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SDKError>) -> Void)
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SDKError>) -> Void)
    func subscribeForBackInStock(id: String, email: String?, phone: String?, fashionSize: [String]?, completion: @escaping(Result<Void, SDKError>) -> Void)
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String?, phone: String?, completion: @escaping(Result<Void, SDKError>) -> Void)
    func getStories(code: String, completion: @escaping(Result<StoryContent, SDKError>) -> Void)
    func addToSegment(segmentId: String, email: String?, phone: String?, completion: @escaping(Result<Void, SDKError>) -> Void)
    func removeFromSegment(segmentId: String, email: String?, phone: String?, completion: @escaping(Result<Void, SDKError>) -> Void)
    func manageSubscription(email: String?, phone: String?, userExternalId: String?, userLoyaltyId: String?, telegramId: String?, emailBulk: Bool?, emailChain: Bool?, emailTransactional: Bool?, smsBulk: Bool?, smsChain: Bool?, smsTransactional: Bool?, webPushBulk: Bool?, webPushChain: Bool?, webPushTransactional: Bool?, mobilePushBulk: Bool?, mobilePushChain: Bool?, mobilePushTransactional: Bool?, completion: @escaping(Result<Void, SDKError>) -> Void)
    //func getAllNotifications(type: String, phone: String?, email: String?, userExternalId: String?, userLoyaltyId: String?, channel: String?, limit: Int?, page: Int?, dateFrom: String?, completion: @escaping(Result<UserPayloadResponse, SDKError>) -> Void)
    func configuration() -> SdkConfiguration.Type
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SDKError>) -> Void)
    func deleteUserCredentials()
}

public extension PersonalizationSDK {
    func setPushTokenNotification(token: String, platform: String? = nil, completion: @escaping(Result<Void, SDKError>) -> Void) {
        setPushTokenNotification(token: token, platform: platform, completion: completion)
    }
    
    func review(rate: Int, channel: String, category: String, orderId: String? = nil, comment: String? = nil, completion: @escaping(Result<Void, SDKError>) -> Void) {
        review(rate: rate, channel: channel, category: category, orderId: orderId, comment: comment, completion: completion)
    }

    func setProfileData(userEmail: String? = nil, userPhone: String? = nil, userLoyaltyId: String? = nil, birthday: Date? = nil, age: Int? = nil, firstName: String? = nil, lastName: String? = nil, location: String? = nil, gender: Gender? = nil, fbID: String? = nil, vkID: String? = nil, telegramId: String? = nil, loyaltyCardLocation: String? = nil, loyaltyStatus: String? = nil, loyaltyBonuses: Int? = nil, loyaltyBonusesToNextLevel: Int? = nil, boughtSomething: Bool? = nil, userId: String? = nil, customProperties: [String: Any?]? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        setProfileData(userEmail: userEmail, userPhone: userPhone, userLoyaltyId: userLoyaltyId, birthday: birthday, age: age, firstName: firstName, lastName: lastName, location: location, gender: gender, fbID: fbID, vkID: vkID, telegramId: telegramId, loyaltyCardLocation: loyaltyCardLocation, loyaltyStatus: loyaltyStatus, loyaltyBonuses: loyaltyBonuses, loyaltyBonusesToNextLevel: loyaltyBonusesToNextLevel, boughtSomething: boughtSomething, userId: userId, customProperties: customProperties, completion: completion)
    }

    func recommend(blockId: String, currentProductId: String? = nil, currentCategoryId: String? = nil, locations: String? = nil, imageSize: String? = nil, timeOut: Double? = nil, withLocations: Bool = false, extended: Bool = false, completion: @escaping (Result<RecommenderResponse, SDKError>) -> Void) {
        recommend(blockId: blockId, currentProductId: currentProductId, currentCategoryId: currentCategoryId, locations: locations, imageSize: imageSize, timeOut: timeOut, withLocations: withLocations, extended: extended, completion: completion)
    }
    
    func suggest(query: String, locations: String? = nil, timeOut: Double? = nil, extended: String? = nil, completion: @escaping(Result<SearchResponse, SDKError>) -> Void) {
        suggest(query: query, locations: locations, timeOut: timeOut, extended: extended, completion: completion)
    }
    
    func getProductsList(brands: String? = nil, merchants: String? = nil, categories: String? = nil, locations: String? = nil, limit: Int? = nil, page: Int? = nil, filters: [String: Any]? = nil, completion: @escaping(Result<ProductsListResponse, SDKError>) -> Void) {
        getProductsList(brands: brands, merchants: merchants, categories: categories, locations: locations, limit:limit, page: page, filters: filters, completion: completion)
    }
    
    func getProductsFromCart(completion: @escaping(Result<[CartItem], SDKError>) -> Void) {
        getProductsFromCart(completion: completion)
    }
    
    func search(query: String, limit: Int? = nil, offset: Int? = nil, categoryLimit: Int? = nil, categories: String? = nil, extended: String? = nil, sortBy: String? = nil, sortDir: String? = nil, locations: String? = nil, brands: String? = nil, filters: [String: Any]? = nil, priceMin: Double? = nil, priceMax: Double? = nil, colors: [String]? = nil, fashionSizes: [String]? = nil, exclude: String? = nil, email: String? = nil, timeOut: Double? = nil, disableClarification: Bool? = nil, completion: @escaping(Result<SearchResponse, SDKError>) -> Void) {
        search(query: query, limit: limit, offset: offset, categoryLimit: categoryLimit, categories: categories, extended: extended, sortBy: sortBy, sortDir: sortDir, locations: locations, brands: brands, filters: filters, priceMin: priceMin, priceMax: priceMax, colors: colors, fashionSizes: fashionSizes, exclude: exclude, email: email, timeOut: timeOut, disableClarification: disableClarification, completion: completion)
    }
    
    func track(event: Event, recommendedBy: RecomendedBy? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        track(event: event, recommendedBy: recommendedBy, completion: completion)
    }
    
    func trackEvent(event: String, category: String? = nil, label: String? = nil, value: Int? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        trackEvent(event: event, category: category, label: label, value: value, completion: completion)
    }
    
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SDKError>) -> Void) {
        notificationClicked(type: type, code: code, completion: completion)
    }
    
    func subscribeForBackInStock(id: String, email: String? = nil, phone: String? = nil, fashionSize: [String]? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        subscribeForBackInStock(id: id, email: email, phone: phone, fashionSize: fashionSize, completion: completion)
    }
    
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        subscribeForPriceDrop(id: id, currentPrice: currentPrice, email: email, phone: phone, completion: completion)
    }
    
    func addToSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        addToSegment(segmentId: segmentId, email: email, phone: phone, completion: completion)
    }
    
    func removeFromSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping(Result<Void, SDKError>) -> Void) {
        removeFromSegment(segmentId: segmentId, email: email, phone: phone, completion: completion)
    }
    
    func manageSubscription(email: String? = nil, phone: String? = nil, userExternalId: String? = nil, userLoyaltyId: String? = nil, telegramId: String? = nil, emailBulk: Bool? = nil, emailChain: Bool? = nil, emailTransactional: Bool? = nil, smsBulk: Bool? = nil, smsChain: Bool? = nil, smsTransactional: Bool? = nil, webPushBulk: Bool? = nil, webPushChain: Bool? = nil, webPushTransactional: Bool? = nil, mobilePushBulk: Bool? = nil, mobilePushChain: Bool? = nil, mobilePushTransactional: Bool? = nil, completion: @escaping(Result<Void, SDKError>) -> Void) {
        manageSubscription(email: email, phone: phone, userExternalId: userExternalId, userLoyaltyId: userLoyaltyId, telegramId: telegramId, emailBulk: emailBulk, emailChain: emailChain, emailTransactional: emailTransactional, smsBulk: smsBulk, smsChain: smsChain, smsTransactional: smsTransactional, webPushBulk: webPushBulk, webPushChain: webPushChain, webPushTransactional: webPushTransactional, mobilePushBulk: mobilePushBulk, mobilePushChain: mobilePushChain, mobilePushTransactional: mobilePushTransactional, completion: completion)
    }
    
    //    func getAllNotifications(type: String, phone: String? = nil, email: String? = nil, userExternalId: String? = nil, userLoyaltyId: String? = nil, channel: String? = nil, limit: Int? = nil, page: Int? = nil, dateFrom: String? = nil, completion: @escaping(Result<UserPayloadResponse, SDKError>) -> Void) {
    //        getAllNotifications(type: type, phone: phone, email: email, userExternalId: userExternalId, userLoyaltyId:userLoyaltyId, channel: channel, limit: limit, page: page, dateFrom: dateFrom, completion: completion)
    //    }
    
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
            if dict[key] != nil { //if let value = dict[key] {
                //print("Clear local stories cache for \(key) = \(value)")
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
        //resetCartProductStates()
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
        //resetFavoritesProductStates()
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
    apiDomain: String = "api.rees46.com",
    stream: String = "ios",
    enableLogs: Bool = false,
    autoSendPushToken: Bool = true,
    _ completion: ((SDKError?) -> Void)? = nil
) -> PersonalizationSDK {
    let sdk = SimplePersonalizationSDK(shopId: shopId, userEmail: userEmail, userPhone: userPhone, userLoyaltyId: userLoyaltyId, apiDomain: apiDomain, stream: stream, enableLogs: enableLogs, autoSendPushToken: autoSendPushToken, completion: completion)
    
    sdk.resetSdkCache()
    
    return sdk
}
