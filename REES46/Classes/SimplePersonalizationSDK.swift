//
//  SimplePersonaliztionSDK.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import UIKit
import Foundation

public var global_EL: Bool = true

class SimplePersonalizationSDK: PersonalizationSDK {
    private var storiesCode: String? = nil
    var shopId: String
    var deviceID: String
    var userSeance: String
    var stream: String
    
    var baseURL: String
    let baseInitJsonFileName = "sdkinit.json"

    var userEmail: String?
    var userPhone: String?
    var userLoyaltyId: String?
    
    var segment: String

    var urlSession: URLSession

    var userInfo: InitResponse = InitResponse()

    private let sessionQueue = SessionQueue.manager
    
    private var requestOperation: RequestOperation?
    
    private let semaphore = DispatchSemaphore(value: 0)

    init(shopId: String, userEmail: String? = nil, userPhone: String? = nil, userLoyaltyId: String? = nil, apiDomain: String, stream: String = "ios", enableLogs: Bool = false, completion: ((SDKError?) -> Void)? = nil) {
        self.shopId = shopId
        
        global_EL = enableLogs
        self.baseURL = "https://" + apiDomain + "/"
        
        self.userEmail = userEmail
        self.userPhone = userPhone
        self.userLoyaltyId = userLoyaltyId
        self.stream = stream

        // Generate seance
        userSeance = UUID().uuidString
        
        // Generate segment
        segment = ["A", "B"].randomElement() ?? "A"
        
        // Trying to fetch user session (permanent user ID)
        deviceID = UserDefaults.standard.string(forKey: "device_id") ?? ""
        
        urlSession = URLSession.shared
        sessionQueue.addOperation {
            self.sendInitRequest { initResult in
                switch initResult {
                case .success:
                    if let res = try? initResult.get() {
                        self.userInfo = res
                        self.userSeance = res.seance
                        self.deviceID = res.deviceID
                        if let completion = completion {
                            completion(nil)
                        }
                    } else {
                        if let completion = completion {
                            completion(.decodeError)
                        }
                    }
                    self.semaphore.signal()
                case .failure(let error):
                    if let completion = completion {
                        completion(error)
                        
                        let networkManager = NetworkStatus.nManager
                        let connectionStatus = networkManager.connectionStatus
                        let typeOfConnection = networkManager.connectionType
                        print("SDK Network status: \(connectionStatus) \nConnection Type: \(typeOfConnection ?? .notdetected)")
                        //print("Connection Type: \(typeOfConnection ?? .notdetected)")
                        
                        if connectionStatus == .Online {
                            completion(error)
                        } else if connectionStatus == .Offline {
                            //completion(.networkOfflineError)
                            completion(.custom(error: typeOfConnection?.description ?? "Network Error" ))
                        }
                    }
                    self.semaphore.signal()
                    break
                }
            }
            self.semaphore.wait()
        }
    }

    func getDeviceID() -> String {
        return deviceID
    }

    func getSession() -> String {
        return userSeance
    }
    
    func getCurrentSegment() -> String {
        return segment
    }

    func setPushTokenNotification(token: String, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "mobile_push_tokens"
            let params = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "token": token,
                "platform": self.stream,
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func setFirebasePushToken(token: String, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "mobile_push_tokens"
            let params = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "token": token,
                "platform": "ios",
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "search/blank"
            let params: [String : String] = [
                "did": self.deviceID,
                "shop_id": self.shopId
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            self.getRequest(path: path, params: params) { (result) in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = SearchBlankResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "nps/create"
            let params: [String : String] = [
                "did": self.deviceID,
                "shop_id": self.shopId,
                "rate": String(rate),
                "channel": channel,
                "category": category,
                "order_id": orderId ?? "",
                "comment": comment ?? ""
            ]
            if rate < 1 || rate > 10 {
                completion(.failure(.custom(error: "Error: rating can be between 1 and 10 only")))
                return // Exit from review
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.postRequest(path: path, params: params) { (result) in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func setProfileData(userEmail: String?, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: Int?, firstName: String?, lastName: String?, location: String?, gender: Gender?, fbID: String?, vkID: String?, telegramId: String?, loyaltyCardLocation: String?, loyaltyStatus: String?, loyaltyBonuses: Int?, loyaltyBonusesToNextLevel: Int?, boughtSomething: Bool?, userId: String?, customProperties: [String: Any?]?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "profile/set"
            var paramsTemp: [String: Any?] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
            ]
            
            if let userEmail = userEmail {
                paramsTemp["email"] = String(userEmail)
            }
            
            if let firstName = firstName {
                paramsTemp["first_name"] = String(firstName)
            }
            
            if let lastName = lastName {
                paramsTemp["last_name"] = String(lastName)
            }
            
            if let userPhone = userPhone {
                paramsTemp["phone"] = String(userPhone)
            }
            
            if let location = location {
                paramsTemp["location"] = String(location)
            }

            if let loyaltyCardLocation = loyaltyCardLocation {
                paramsTemp["loyalty_card_location"] = String(loyaltyCardLocation)
            }

            if let userLoyaltyId = userLoyaltyId {
                paramsTemp["loyalty_id"] = String(userLoyaltyId)
            }

            if let loyaltyStatus = loyaltyStatus {
                paramsTemp["loyalty_status"] = String(loyaltyStatus)
            }

            if let fbID = fbID {
                paramsTemp["fb_id"] = String(fbID)
            }
            
            if let vkID = vkID {
                paramsTemp["vk_id"] = String(vkID)
            }
            
            if let telegramId = telegramId {
                paramsTemp["telegram_id"] = String(telegramId)
            }
            
            if let userId = userId {
                paramsTemp["id"] = String(userId)
            }
            
            if gender == .male {
                paramsTemp["gender"] = "m"
            }
            if gender == .female {
                paramsTemp["gender"] = "f"
            }
            
            if let birthday = birthday {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let birthdayString = dateFormatter.string(from: birthday)
                paramsTemp["birthday"] = birthdayString
            }
            
            if let loyaltyBonuses = loyaltyBonuses {
                paramsTemp["loyalty_bonuses"] = String(loyaltyBonuses)
            }
            
            if let loyaltyBonusesToNextLevel = loyaltyBonusesToNextLevel {
                paramsTemp["loyalty_bonuses_to_next_level"] = String(loyaltyBonusesToNextLevel)
            }
            
            if let boughtSomething = boughtSomething {
                paramsTemp["bought_something"] = boughtSomething == true ? "1" : "0"
            }
            
            if let age = age {
                paramsTemp["age"] = String(age)
            }
            
            // Merge custom properties (custom properties overwrite initial values)
            if let customProperties = customProperties {
                paramsTemp.merge(customProperties) { (_, new) in new }
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            var params: [String: Any] = [String: Any]()
            for item in paramsTemp {
                if item.value is Date {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "YYYY-MM-dd"
                    guard let date = item.value as? Date else {continue}
                    params[item.key] = formatter.string(from: date)
                } else {
                    params[item.key] = item.value
                }
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

    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            var path = "push"
            var paramEvent = ""
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment": self.segment
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
            case let .productAddedToFavorities(id):
                params["items"] = [["id":id]]
                paramEvent = "wish"
            case let .productRemovedFromCart(id):
                params["items"] = [["id":id]]
                paramEvent = "remove_from_cart"
            case let .productRemovedToFavorities(id):
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
    
    /**
     * Track custom event.
     *
     */
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "push/custom"
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment": self.segment,
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
    
    func trackSource(source: RecommendedByCase, code: String) {
        UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: "timeStartSave")
        UserDefaults.standard.setValue(code, forKey: "recomendedCode")
        UserDefaults.standard.setValue(source.rawValue, forKey: "recomendedType")
    }

    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?, timeOut: Double?, completion: @escaping (Result<RecommenderResponse, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "recommend/\(blockId)"
            var params = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "extended": "true",
                "resize_image": "180",
                "segment": self.segment
            ]

            if let productId = currentProductId {
                params["item_id"] = productId
            }
            
            if let categoryId = currentCategoryId {
                params["categories"] = categoryId
            }
            
            if let imageSize = imageSize {
                params["resize_image"] = imageSize
            }

            if let locations = locations{
                params["locations"] = locations
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)

            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = RecommenderResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, categories: String?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: String?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping (Result<SearchResponse, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "search"
            var params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "type": "full_search",
                "search_query": query,
                "segment": self.segment
            ]
            if let limit = limit{
                params["limit"] = String(limit)
            }
            if let offset = offset{
                params["offset"] = String(offset)
            }
            if let categoryLimit = categoryLimit{
                params["category_limit"] = String(categoryLimit)
            }
            if let categories = categories{
                params["categories"] = categories
            }
            if let extended = extended{
                params["extended"] = extended
            }
            if let sortBy = sortBy{
                params["sort_by"] = String(sortBy)
            }
            if let sortDir = sortDir{
                params["sort_dir"] = String(sortDir)
            }
            if let locations = locations{
                params["locations"] = locations
            }
            if let brands = brands{
                params["brands"] = brands
            }
            if let filters = filters{
                if let theJSONData = try? JSONSerialization.data(
                    withJSONObject: filters,
                    options: []) {
                    let theJSONText = String(data: theJSONData,
                                             encoding: .utf8)
                    params["filters"] = theJSONText
                }
            }
            if let priceMin = priceMin{
                params["price_min"] = String(priceMin)
            }
            if let priceMax = priceMax{
                params["price_max"] = String(priceMax)
            }
            if let colors = colors{
                params["colors"] = colors
            }
            if let exclude = exclude{
                params["exclude"] = exclude
            }
            if let email = email{
                params["email"] = email
            }
            if let disableClarification = disableClarification {
                if disableClarification == true {
                    params["no_clarification"] = "1"
                }
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = SearchResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func suggest(query: String, locations: String?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "search"
            var params = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "type": "instant_search",
                "search_query": query,
                "segment": self.segment
            ]
            
            if let locations = locations{
                params["locations"] = locations
            }
            if let extended = extended{
                params["extended"] = extended
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = SearchResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Send tracking event when user clicked mobile push notification
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "track/clicked"
            let params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "code": code,
                "type": type
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    // Send tracking event when user receive mobile push notification
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "track/received"
            let params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "code": code,
                "type": type
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "subscriptions/subscribe_for_product_price"
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment": self.segment,
                "item_id": id,
                "price": currentPrice
            ]
            
            // If has email
            if let email = email {
                params["email"] = email
            }
            
            // If has phone
            if let phone = phone {
                params["phone"] = phone
            }

            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success(_):
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func subscribeForBackInStock(id: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "subscriptions/subscribe_for_product_available"
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment": self.segment,
                "item_id": id
            ]
            
            // If has email
            if let email = email {
                params["email"] = email
            }
            
            // If has phone
            if let phone = phone {
                params["phone"] = phone
            }

            self.postRequest(path: path, params: params, completion: { result in
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
        
        let path = "subscriptions/manage"
        var params: [String: Any] = [
            "shop_id": self.shopId,
            "did": self.deviceID,
            "seance": self.userSeance,
            "sid": self.userSeance,
            "segment": self.segment
        ]
        
        // If has email
        if let email = email {
            params["email"] = email
        }
        
        // If has phone
        if let phone = phone {
            params["phone"] = phone
        }
        
        if let userExternalId          = userExternalId             { params["external_id"]                 = userExternalId }
        if let userLoyaltyId           = userLoyaltyId              { params["loyalty_id"]                  = userLoyaltyId }
        if let telegramId              = telegramId                 { params["telegram_id"]                 = telegramId }
        if let emailBulk               = emailBulk                  { params["email_bulk"]                  = emailBulk }
        if let emailChain              = emailChain                 { params["email_chain"]                 = emailChain }
        if let emailTransactional      = emailTransactional         { params["email_transactional"]         = emailTransactional }
        if let smsBulk                 = smsBulk                    { params["sms_bulk"]                    = smsBulk }
        if let smsChain                = smsChain                   { params["sms_chain"]                   = smsChain }
        if let smsTransactional        = smsTransactional           { params["sms_transactional"]           = smsTransactional }
        if let webPushBulk             = webPushBulk                { params["web_push_bulk"]               = webPushBulk }
        if let webPushChain            = webPushChain               { params["web_push_chain"]              = webPushChain }
        if let webPushTransactional    = webPushTransactional       { params["web_push_transactional"]      = webPushTransactional }
        if let mobilePushBulk          = mobilePushBulk             { params["mobile_push_bulk"]            = mobilePushBulk }
        if let mobilePushChain         = mobilePushChain            { params["mobile_push_chain"]           = mobilePushChain }
        if let mobilePushTransactional = mobilePushTransactional    { params["mobile_push_transactional"]   = mobilePushTransactional }
        
        self.postRequest(path: path, params: params, completion: { result in
            switch result {
            case .success(_):
                completion(.success(Void()))
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }
    
    func addToSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "segments/add"
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment_id": segmentId
            ]
            
            // If has email
            if let email = email {
                params["email"] = email
            }
            
            // If has phone
            if let phone = phone {
                params["phone"] = phone
            }

            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success(_):
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }
    
    func removeFromSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        sessionQueue.addOperation {
            let path = "segments/remove"
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceID,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment_id": segmentId
            ]
            
            // If has email
            if let email = email {
                params["email"] = email
            }
            
            // If has phone
            if let phone = phone {
                params["phone"] = phone
            }

            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success(_):
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }

    private func sendInitRequest(completion: @escaping (Result<InitResponse, SDKError>) -> Void) {
        let path = "init"
        var secondsFromGMT: Int { return TimeZone.current.secondsFromGMT() }
        let hours = secondsFromGMT/3600
        let params: [String: String] = [
            "shop_id": shopId,
            "tz": String(hours)
        ]
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 1
        sessionConfig.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: sessionConfig)
        
        if SdkConfiguration.stories.useSdkOldInitialization == true {
            getRequest(path: path, params: params, true) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = InitResponse(json: resJSON)
                    UserDefaults.standard.set(resultResponse.deviceID, forKey: "device_id")
                    UserDefaults.standard.set(resultResponse.seance, forKey: "seance_id")
                    UserDefaults.standard.set(self.baseURL, forKey: "base_url")
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        } else {
            let initFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(baseInitJsonFileName)
            if self.baseURL != UserDefaults.standard.string(forKey: "base_url") ?? "" {
                try? FileManager.default.removeItem(at: initFileNamePath)
            }
            
            let initData = NSData(contentsOf: initFileNamePath)
            let json = try? JSONSerialization.jsonObject(with: initData as? Data ?? Data())
            if let jsonObject = json as? [String: Any] {
                let resultResponse = InitResponse(json: jsonObject)
                UserDefaults.standard.set(resultResponse.deviceID, forKey: "device_id")
                UserDefaults.standard.set(resultResponse.seance, forKey: "seance_id")
                UserDefaults.standard.set(self.baseURL, forKey: "base_url")
                sleep(2)
                completion(.success(resultResponse))
            } else {
                getRequest(path: path, params: params, true) { result in
                    switch result {
                    case let .success(successResult):
                        let resJSON = successResult
                        let resultResponse = InitResponse(json: resJSON)
                        
                        UserDefaults.standard.set(resultResponse.deviceID, forKey: "device_id")
                        //self.saveToTextFile(didToken: resultResponse.deviceID)
                        //print("DID TOKEN NOW =", resultResponse.deviceID)
                        
                        UserDefaults.standard.set(resultResponse.seance, forKey: "seance_id")
                        //self.saveToTextFile(seanceToken: resultResponse.seance)
                        //print("SEANCE TOKEN NOW =", resultResponse.seance)
                        
                        UserDefaults.standard.set(self.baseURL, forKey: "base_url")
                        completion(.success(resultResponse))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    func getStories(code: String, completion: @escaping (Result<StoryContent, SDKError>) -> Void) {
        self.storiesCode = code
        let path = "stories/\(code)"
        let params: [String: String] = [
            "shop_id": shopId,
            "did": deviceID
        ]
        let sessionConfig = URLSessionConfiguration.default
        if SdkConfiguration.stories.storiesSlideReloadManually {
            sessionConfig.timeoutIntervalForRequest = SdkConfiguration.stories.storiesSlideReloadTimeoutInterval
            sessionConfig.waitsForConnectivity = false
        } else {
            sessionConfig.timeoutIntervalForRequest = 5
            sessionConfig.waitsForConnectivity = true
        }
        self.urlSession = URLSession(configuration: sessionConfig)
        
        getRequest(path: path, params: params, false) { result in
            switch result {
            case let .success(successResult):
                let res = StoryContent(json: successResult)
                completion(.success(res))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        jsonDecoder.dateDecodingStrategy = .formatted(dateFormatter)
        return jsonDecoder
    }()
    
    func saveDataToJsonFile(_ data: Data, jsonInitFileName: String = "sdkinit.json") throws {
        let jsonFileURL = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(jsonInitFileName)
        try data.write(to: jsonFileURL)
    }
    
    func saveToTextFile(didToken: String) {
        let didFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent("did.txt")
        do {
            try didToken.write(to: didFileNamePath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("SDK Error Write DID token")
        }
    }
    
    func saveToTextFile(sidToken: String) {
        let sidFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent("sid.txt")
        do {
            try sidToken.write(to: sidFileNamePath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("SDK Error Write seance SID token")
        }
    }
    
    internal func configuration() -> SdkConfiguration.Type {
        return SdkConfiguration.self
    }

    private func getRequest(path: String, params: [String: String], _ isInit: Bool = false, completion: @escaping (Result<[String: Any], SDKError>) -> Void) {

        let urlString = baseURL + path
        var url = URLComponents(string: urlString)

        var queryItems = [URLQueryItem]()
        for item in params{
            queryItems.append(URLQueryItem(name: item.key, value: item.value))
        }
        queryItems.append(URLQueryItem(name: "stream", value: stream))
        url?.queryItems = queryItems
        
        if SdkConfiguration.stories.useSdkOldInitialization == false {
            if (!isInit && path == "init") {
                let initFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(baseInitJsonFileName)
                let iData = NSData(contentsOf: initFileNamePath)
                let json = try? JSONSerialization.jsonObject(with: iData! as Data)
                if let jsonObject = json as? [String: Any] {
                    completion(.success(jsonObject))
                } else {
                    completion(.failure(.decodeError))
                }
            }
        }

        if let endUrl = url?.url {
            urlSession.dataTask(with: endUrl) { result in
                switch result {
                case .success(let (response, data)):
                    guard let statusCode = (response as? HTTPURLResponse)?.statusCode, 200 ..< 299 ~= statusCode else {
                        let json = try? JSONSerialization.jsonObject(with: data)
                        if let jsonObject = json as? [String: Any] {
                            let statusMessage = jsonObject["message"] as? String ?? ""
                            print("Status message: ", statusMessage)
                        }
                        completion(.failure(.invalidResponse))
                        return
                    }
                    do {
                        if SdkConfiguration.stories.useSdkOldInitialization == false {
                            if isInit {
                                try self.saveDataToJsonFile(data, jsonInitFileName: self.baseInitJsonFileName)
                            }
                        }
                        
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let jsonObject = json as? [String: Any] {
                            completion(.success(jsonObject))
                        } else {
                            completion(.failure(.decodeError))
                        }
                    } catch {
                        completion(.failure(.decodeError))
                    }
                case .failure:
                    let networkManager = NetworkStatus.nManager
                    let connectionStatus = networkManager.connectionStatus
                    
                    if connectionStatus == .Online {
                        completion(.failure(.invalidResponse))
                    } else if connectionStatus == .Offline {
                        completion(.failure(.networkOfflineError))
                    }
                }
            }.resume()
        } else {
            completion(.failure(.invalidResponse))
        }
    }

    private func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SDKError>) -> Void) {
        
        var requestParams : [String: Any] = [
            "stream": stream
        ]
        for (key, value) in params {
            requestParams[key] = value
        }

        if let url = URL(string: baseURL + path) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
//            do {
//                let sBody = try JSONSerialization.data(withJSONObject: requestParams, options: .prettyPrinted)
//                request.httpBody = try JSONSerialization.data(withJSONObject: requestParams, options: .prettyPrinted)
//            } catch let error {
//                completion(.failure(.custom(error: "00001: \(error.localizedDescription)")))
//                return
//            }
            
            let boundary = generateBoundary()
            let jsonData = createDataForBody(withParameters: requestParams, content: [], boundary: boundary)
            
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            urlSession.postTask(with: request, bodyData: jsonData) { result in
                switch result {
                case .success(let (response, data)):
                    guard let statusCode = (response as? HTTPURLResponse)?.statusCode, 200 ..< 299 ~= statusCode else {
                        if let json = try? JSONSerialization.jsonObject(with: data) {
                            if let jsonObject = json as? [String:Any] {
                                if let status = jsonObject["status"] as? String, status == "error" {
                                    if let errorMessage = jsonObject["message"] as? String {
                                        completion(.failure(.custom(error: errorMessage)))
                                    }
                                }
                            }
                        }
                        completion(.failure(.invalidResponse))
                        return
                    }
                    do {
                        if data.isEmpty {
                            if path.contains("clicked") || path.contains("closed") || path.contains("received") {
                                completion(.success([:]))
                                return
                            }
                        }
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let jsonObject = json as? [String: Any] {
                            completion(.success(jsonObject))
                        } else {
                            completion(.failure(.decodeError))
                        }
                    } catch {
                        completion(.failure(.decodeError))
                    }
                case .failure:
                    let networkManager = NetworkStatus.nManager
                    let connectionStatus = networkManager.connectionStatus
                    //let typeOfConnection = networkManager.connectionType
                    //print("SDK Network status: \(connectionStatus) \nConnection Type: \(typeOfConnection ?? .notdetected)")
                    
                    if connectionStatus == .Online {
                        completion(.failure(.invalidResponse))
                    } else if connectionStatus == .Offline {
                        completion(.failure(.networkOfflineError))
                    }
                }
            }.resume()
        } else {
            completion(.failure(.invalidResponse))
        }
    }
    
    func createDataForBody(withParameters params: [String: Any]?, content: [DataUploadStruct]?, boundary: String) -> Data {
        let lineBreak = "\r\n"
        var body = Data()

        if let parameters = params {
            for (key, value) in parameters {
                body.append("--\(boundary + lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)")
                
                if let vString = value as? String {
                    body.append("\(vString + lineBreak)")
                }
            }
        }

        if let content = content {
            for uploadData in content {
                body.append("--\(boundary + lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(uploadData.key)\"; filename=\"\(uploadData.fileName)\"\(lineBreak)")
                body.append("Content-Type: \(uploadData.mimeType + lineBreak + lineBreak)")
                body.append(uploadData.data)
                body.append(lineBreak)
            }
        }

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
    
    func generateBoundary() -> String {
        return "Boundary-\(NSUUID().uuidString)"
    }
    
    struct DataUploadStruct {
        let key: String
        let fileName: String
        let data: Data
        let mimeType: String

        init?(withImage image: UIImage, forKey key: String) {
            self.key = key
            self.mimeType = "image/jpg"
            self.fileName = "\(arc4random()).jpeg"

            guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }
            self.data = data
        }
    }
}


extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}


extension URLSession {
    func dataTask(with url: URL, result: @escaping (Result<(URLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: url) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response, let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            result(.success((response, data)))
        }
    }

    func postTask(with request: URLRequest, bodyData: Data, result: @escaping (Result<(URLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return uploadTask(with: request, from: bodyData) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response, let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            result(.success((response, data)))
        }
    }
}
