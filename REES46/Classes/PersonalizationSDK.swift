//
//  PersonalizationSDK.swift
//  shopTest
//
//  Created by Арсений Дорогин on 29.07.2020.
//

import Foundation

public enum Event {
    case productView (id: String)
    case categoryView (id: String)
    case productAddedToFavorities(id: String)
    case productRemovedToFavorities(id: String)
    case productAddedToCart (id: String)
    case productRemovedFromCart (id: String)
    case syncronizeCart (ids: [String])
    case orderCreated(orderId: String, totalValue: Double, products: [(id: String, amount: Int)])
}

public enum SDKError: Error {
    case incorrectAPIKey
    case initializationFailed
    case noError
    case responseError
    case invalidResponse
    case decodeError
}


public protocol PersonalizationSDK {
    func setProfileData(userEmail: String, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: String?, firstName: String?, secondName: String?, lastName: String?, location: String?, gender: Gender?, completion: @escaping (Result<Void, SDKError>) -> Void)
    func track(event: Event, completion: @escaping (Result<Void, SDKError>) -> Void)
    func recommend(blockId: String, currentProductId: String?, completion: @escaping (Result<RecommenderResponse, SDKError>) -> Void)
    func search(query: String, searchType: SearchType, completion: @escaping(Result<SearchResponse, SDKError>) -> Void)
    func getSSID() -> String
    func getSession() -> String
    func setPushTokenNotification(token: String, completion: @escaping(Result<Void, SDKError>) -> Void)
}

public extension PersonalizationSDK {
    
    func setProfileData(userEmail: String, userPhone: String? = nil, userLoyaltyId: String? = nil, birthday: Date? = nil, age: String? = nil, firstName: String? = nil, secondName: String? = nil, lastName: String? = nil, location: String? = nil, gender: Gender? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        setProfileData(userEmail: userEmail, userPhone: userPhone, userLoyaltyId: userLoyaltyId, birthday: birthday, age: age, firstName: firstName, secondName: secondName, lastName: lastName, location: location, gender: gender, completion: completion)
    }
    
    func recommend(blockId: String, currentProductId: String? = nil, completion: @escaping (Result<RecommenderResponse, SDKError>) -> Void) {
        recommend(blockId: blockId, currentProductId: currentProductId, completion: completion)
    }
    
}
public func createPersonalizationSDK(shopId: String, userId: String? = nil, userEmail: String? = nil, userPhone: String? = nil, userLoyaltyId: String? = nil) -> PersonalizationSDK{
    let sdk = SimplePersonaizationSDK(shopId: shopId, userId: userId, userEmail: userEmail, userPhone: userPhone, userLoyaltyId: userLoyaltyId)
    return sdk
}
