import UIKit
import Foundation
import AdSupport
import AppTrackingTransparency

public var global_EL: Bool = true

class SimplePersonalizationSDK: PersonalizationSDK {
    
    var storiesCode: String?
    var shopId: String
    var deviceId: String
    var userSeance: String
    var stream: String
    var baseURL: String
    let baseInitJsonFileName = ".json"
    let autoSendPushToken: Bool
    
    let sdkBundleId = Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier
    let appBundleId = Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier
    
    var userEmail: String?
    var userPhone: String?
    var userLoyaltyId: String?
    var segment: String
    var urlSession: URLSession
    var userInfo: InitResponse = InitResponse()
    
    let sessionQueue = SessionQueue.manager
    private var requestOperation: RequestOperation?
    let bodyMutableData = NSMutableData()
    private let initSemaphore = DispatchSemaphore(value: 0)
    private let serialSemaphore = DispatchSemaphore(value: 0)
    
    lazy var trackEventService: TrackEventServiceProtocol = {
        return TrackEventServiceImpl(sdk: self)
    }()
    
    lazy var trackSourceService: TrackSourceServiceProtocol = {
        return TrackSourceServiceImpl()
    }()
    
    lazy var subscriptionService: SubscriptionServiceProtocol = {
        return SubscriptionServiceImpl(sdk: self)
    }()
    
    lazy var notificationService: NotificationHandlerServiceProtocol = {
        return NotificationHandlerServiceImpl(sdk: self)
    }()
    
    lazy var pushTokenService: PushTokenNotificationServiceProtocol = {
        return PushTokenHandlerServiceImpl(sdk: self)
    }()
    
    lazy var searchService: SearchServiceProtocol = {
        return SearchServiceImpl(sdk: self)
    }()
    
    lazy var profileData: ProfileDataProtocol = {
        return ProfileDataImpl(sdk: self, configProvider: self)
    }()
    
    init(
        shopId: String,
        userEmail: String? = nil,
        userPhone: String? = nil,
        userLoyaltyId: String? = nil,
        apiDomain: String,
        stream: String = "ios",
        enableLogs: Bool = false,
        autoSendPushToken: Bool = true,
        completion: ((SdkError?) -> Void)? = nil
    ) {
        self.shopId = shopId
        self.autoSendPushToken = autoSendPushToken
        
        global_EL = enableLogs
        
        self.baseURL = "https://" + apiDomain + "/"
        
        self.userEmail = userEmail
        self.userPhone = userPhone
        self.userLoyaltyId = userLoyaltyId
        self.stream = stream
        self.storiesCode = nil
        
        // Generate seance
        userSeance = UUID().uuidString
        
        // Generate segment
        segment = ["A", "B"].randomElement() ?? "A"
        
        // Trying to fetch user session (permanent user Id)
        deviceId = UserDefaults.standard.string(forKey: SdkConstants.deviceIdKey) ?? ""
        
        urlSession = URLSession.shared
        sessionQueue.addOperation {
            self.sendInitRequest { initResult in
                switch initResult {
                case .success:
                    if let res = try? initResult.get() {
                        self.userInfo = res
                        self.userSeance = res.seance
                        self.deviceId = res.deviceId
                        completion?(nil)
                        // Automatically handle push token if autoSendPushToken is true
                        if self.autoSendPushToken {
                            self.handleAutoSendPushToken()
                        }
                    } else {
                        completion?(.decodeError)
                    }
                    self.initSemaphore.signal()
                case .failure(let error):
                    completion?(error)
                    self.initSemaphore.signal()
                }
            }
            self.initSemaphore.wait()
        }
        
        initializeNotificationRegistrar()
    }
    
    func getDeviceId() -> String {
        return deviceId
    }
    
    func getSession() -> String {
        return userSeance
    }
    
    func getCurrentSegment() -> String {
        return segment
    }
    
    func getShopId() -> String {
        return shopId
    }
    
    func setPushTokenNotification(token: String, isFirebaseNotification: Bool = false, completion: @escaping (Result<Void, SdkError>) -> Void) {
        pushTokenService.setPushToken(token: token, isFirebaseNotification: isFirebaseNotification, completion: completion)
    }
    
    private func initializeNotificationRegistrar() {
        if autoSendPushToken {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
                guard let self = self else { return }
                
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    
                    // Attempt to send the push token if available
                    if let deviceToken = UserDefaults.standard.data(forKey: SdkConstants.deviceToken) {
                        let notificationRegistrar = NotificationRegistrar(sdk: self)
                        notificationRegistrar.registerWithDeviceToken(deviceToken: deviceToken)
                    }
                } else if let error = error {
#if DEBUG
                    print("Error requesting notification authorization: \(error.localizedDescription)")
#endif
                }
            }
        } else {
#if DEBUG
            print("Auto-send push token is disabled.")
#endif
        }
    }
    
    private func handleAutoSendPushToken() {
        if let deviceToken = UserDefaults.standard.data(forKey: SdkConstants.deviceToken) {
            let notificationRegistrar = NotificationRegistrar(sdk: self)
            notificationRegistrar.registerWithDeviceToken(deviceToken: deviceToken)
        }
    }
    
    func getAllNotifications(
        type: String,
        phone: String? = nil,
        email: String? = nil,
        userExternalId: String? = nil,
        userLoyaltyId: String? = nil,
        channel: String?,
        limit: Int?,
        page: Int?,
        dateFrom: String?,
        completion: @escaping (Result<UserPayloadResponse, SdkError>) -> Void
    ) {
        notificationService.getAllNotifications(
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
    
    func configureURLSession(configuration: URLSessionConfiguration) {
        self.urlSession = URLSession(configuration: configuration)
    }
    
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "nps/create"
            let params: [String : String] = [
                "did": self.deviceId,
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
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
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
    
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SdkError>) -> Void) {
        searchService.searchBlank(completion: completion)
    }
    
    func search(
        query: String,
        limit: Int?,
        offset: Int?,
        categoryLimit: Int?,
        brandLimit: Int?,
        categories: [Int]?,
        extended: String?,
        sortBy: String?,
        sortDir: String?,
        locations: String?,
        brands: String?,
        filters: [String: Any]?,
        priceMin: Double?,
        priceMax: Double?,
        colors: [String]?,
        fashionSizes: [String]?,
        exclude: String?,
        email: String?,
        timeOut: Double?,
        disableClarification: Bool?,
        completion: @escaping (Result<SearchResponse, SdkError>) -> Void
    ) {
        searchService.search(
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
    
    func setProfileData(
        userEmail: String?,
        userPhone: String?,
        userLoyaltyId: String?,
        birthday: Date?,
        age: Int?,
        firstName: String?,
        lastName: String?,
        location: String?,
        gender: Gender?,
        fbID: String?,
        vkID: String?,
        telegramId: String?,
        loyaltyCardLocation: String?,
        loyaltyStatus: String?,
        loyaltyBonuses: Int?,
        loyaltyBonusesToNextLevel: Int?,
        boughtSomething: Bool?,
        userId: String?,
        customProperties: [String: Any?]?,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        profileData.setProfileData(
            profileData:ProfileData(
                userEmail:userEmail,
                userPhone:userPhone,
                userLoyaltyId:userLoyaltyId,
                birthday:birthday,
                age:age,
                firstName:firstName,
                lastName:lastName,
                location:location,
                gender:gender,
                fbID:fbID,
                vkID:vkID,
                telegramId:telegramId,
                loyaltyCardLocation:loyaltyCardLocation,
                loyaltyStatus:loyaltyStatus,
                loyaltyBonuses:loyaltyBonuses,
                loyaltyBonusesToNextLevel:loyaltyBonusesToNextLevel,
                boughtSomething:boughtSomething,
                userId:userId,
                customProperties:customProperties
            ),
            completion:completion
        )
    }
    
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackEventService.track(event: event, recommendedBy: recommendedBy, completion: completion)
    }
    
    func trackEvent(event: String, category: String?, label: String?, value: Int?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackEventService.trackEvent(event: event, category: category, label: label, value: value, completion: completion)
    }
    
    func trackSource(source: RecommendedByCase, code: String) {
        trackSourceService.trackSource(source: source, code: code)
    }
    
    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?, timeOut: Double?, withLocations: Bool = false, extended: Bool = false, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "recommend/\(blockId)"
            var params = [
                "shop_id": self.shopId,
                "did": self.deviceId,
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
            if let locations = locations {
                params["locations"] = locations
            }
            
            if extended {
                params["extended"] = "true"
                if withLocations {
                    params["with_locations"] = "true"
                }
            } else {
                params.removeValue(forKey: "with_locations")
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
            sessionConfig.waitsForConnectivity = true
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
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
    
    func suggest(query: String, locations: String?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "search"
            var params = [
                "shop_id": self.shopId,
                "did": self.deviceId,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "type": "instant_search",
                "search_query": query,
                "segment": self.segment
            ]
            
            if let locations = locations {
                params["locations"] = locations
            }
            if let extended = extended {
                params["extended"] = extended
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = timeOut ?? 1
            sessionConfig.waitsForConnectivity = true
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
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
    
    func getProductsList(brands: String?, merchants: String?, categories: String?, locations: String?, limit: Int?, page: Int?, filters: [String: Any]?, completion: @escaping (Result<ProductsListResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "products"
            var params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceId,
                "seance": self.userSeance,
                "sid": self.userSeance
            ]
            if let brands = brands {
                params["brands"] = brands
            }
            if let merchants = merchants {
                params["merchants"] = merchants
            }
            if let categories = categories {
                params["categories"] = categories
            }
            if let locations = locations {
                params["locations"] = locations
            }
            if let limit = limit {
                params["limit"] = String(limit)
            }
            if let page = page {
                params["page"] = String(page)
            }
            if let filters = filters {
                if let theJSONData = try? JSONSerialization.data(
                    withJSONObject: filters,
                    options: []) {
                    let theJSONText = String(data: theJSONData,
                                             encoding: .utf8)
                    params["filters"] = theJSONText
                }
            }
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = ProductsListResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func getProductInfo(id: String, completion: @escaping (Result<ProductInfo, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "products/get"
            let params: [String : String] = [
                "shop_id": self.shopId,
                "did": self.deviceId,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "item_id": id
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = ProductInfo(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func getProductsFromCart(completion: @escaping (Result<[CartItem], SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "products/cart"
            let params: [String : String] = [
                "shop_id": self.shopId,
                "did": self.deviceId
            ]
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 1
            sessionConfig.waitsForConnectivity = true
            sessionConfig.shouldUseExtendedBackgroundIdleMode = true
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(responseJson):
                    guard let data = responseJson["data"] as? [String: Any],
                          let itemsJSON = data["items"] as? [[String: Any]]
                    else {
                        completion(.failure(.custom(error: "cant find JSON data")))
                        return
                    }
                    let items = itemsJSON.map({ CartItem(json: $0)})
                    completion(.success(items))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        notificationService.trackNotification(
            path: "track/clicked",
            type: type,
            code: code,
            completion: completion
        )
    }
    
    func notificationDelivered(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        notificationService.trackNotification(
            path: "track/delivered",
            type: type,
            code: code,
            completion: completion
        )
    }
    
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        notificationService.trackNotification(
            path: "track/received",
            type: type,
            code: code,
            completion: completion
        )
    }
    
    func subscribeForPriceDrop(
        id: String,
        currentPrice: Double,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        subscriptionService.subscribeForPriceDrop(
            id:id,
            currentPrice: currentPrice,
            email: email,
            phone: phone,
            completion: completion
        )
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
        subscriptionService.subscribeForBackInStock(
            id: id,
            email: email,
            phone: phone,
            fashionSize: fashionSize,
            fashionColor: fashionColor,
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
        subscriptionService.unsubscribeForBackInStock(itemIds: itemIds, email: email, phone: phone, completion: completion)
    }
    
    func unsubscribeForPriceDrop(
        itemIds: [String],
        currentPrice: Double,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        subscriptionService.unsubscribeForPriceDrop(itemIds: itemIds,currentPrice: currentPrice, email: email, phone: phone, completion: completion)
    }
    
    func manageSubscription(
        email: String? = nil,
        phone: String? = nil,
        userExternalId: String? = nil,
        userLoyaltyId: String? = nil,
        telegramId: String? = nil,
        emailBulk: Bool? = nil,
        emailChain: Bool? = nil,
        emailTransactional: Bool? = nil,
        smsBulk: Bool? = nil,
        smsChain: Bool? = nil,
        smsTransactional: Bool? = nil,
        webPushBulk: Bool? = nil,
        webPushChain: Bool? = nil,
        webPushTransactional: Bool? = nil,
        mobilePushBulk: Bool? = nil,
        mobilePushChain: Bool? = nil,
        mobilePushTransactional: Bool? = nil,
        completion: @escaping(Result<Void, SdkError>) -> Void
    ) {
        subscriptionService.manageSubscription(
            email:email,
            phone:phone,
            userExternalId:userExternalId,
            userLoyaltyId:userLoyaltyId,
            telegramId:telegramId,
            emailBulk:emailBulk,
            emailChain:emailChain,
            emailTransactional:emailTransactional,
            smsBulk:smsBulk,
            smsChain:smsChain,
            smsTransactional:smsTransactional,
            webPushBulk:webPushBulk,
            webPushChain:webPushChain,
            webPushTransactional:webPushTransactional,
            mobilePushBulk:mobilePushBulk,
            mobilePushChain:mobilePushChain,
            mobilePushTransactional:mobilePushTransactional,
            completion: completion
        )
    }
    
    func addToSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "segments/add"
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceId,
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
    
    func removeFromSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "segments/remove"
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "did": self.deviceId,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment_id": segmentId
            ]
            
            if let email = email {
                params["email"] = email
            }
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
    
    private func sendInitRequest(completion: @escaping (Result<InitResponse, SdkError>) -> Void) {
        let path = "init"
        var secondsFromGMT: Int { return TimeZone.current.secondsFromGMT() }
        let hours = secondsFromGMT/3600
        
        var params: [String: String] = [
            "shop_id": shopId,
            "tz": String(hours)
        ]
        let deviceId = UserDefaults.standard.string(forKey: "device_id") ?? ""
        if deviceId != "" {
            params["did"] = deviceId
        }
        
        let advId = UserDefaults.standard.string(forKey: "IDFA") ?? nil
        if (advId != "00000000-0000-0000-0000-000000000000" && advId != nil) {
            params["ios_advertising_id"] = advId
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 1
        sessionConfig.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: sessionConfig)
        
        let convertedInitJsonFileName = self.shopId + baseInitJsonFileName
        let initFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(convertedInitJsonFileName)
        
        let initData = NSData(contentsOf: initFileNamePath)
        let json = try? JSONSerialization.jsonObject(with: initData as? Data ?? Data())
        if let jsonObject = json as? [String: Any] {
            let resultResponse = InitResponse(json: jsonObject)
            let successInitDeviceId: String? = resultResponse.deviceId
            let successSeanceId: String? = resultResponse.seance
            let keychainDid: String? = UserDefaults.standard.string(forKey: "device_id") ?? ""
            if (keychainDid == nil || keychainDid == "") {
                DispatchQueue.onceTechService(token: "keychainDid") {
                    UserDefaults.standard.set(successInitDeviceId, forKey: "device_id")
                }
                UserDefaults.standard.set(successSeanceId, forKey: "seance_id")
                sleep(1)
                completion(.success(resultResponse))
                self.serialSemaphore.signal()
            } else {
                if let keychainIpfsSecret = try? InitService.getKeychainDidToken(identifier: sdkBundleId!, instanceKeychainService: appBundleId!) {
                    try? FileManager.default.removeItem(at: initFileNamePath)
                    let jsonSecret = try? JSONSerialization.jsonObject(with: keychainIpfsSecret)
                    let resultResponse = InitResponse(json: jsonSecret as! [String : Any])
                    self.storeSuccessInit(result: resultResponse)
                    
                    try? self.saveDataToJsonFile(keychainIpfsSecret, jsonInitFileName: convertedInitJsonFileName)
                }
                sleep(1)
                completion(.success(resultResponse))
                self.serialSemaphore.signal()
            }
            
        } else if let keychainIpfsSecret = try? InitService.getKeychainDidToken(identifier: sdkBundleId!, instanceKeychainService: appBundleId!) {
            try? FileManager.default.removeItem(at: initFileNamePath)
            let jsonSecret = try? JSONSerialization.jsonObject(with: keychainIpfsSecret)
            let resultResponse = InitResponse(json: jsonSecret as! [String : Any])
            self.storeSuccessInit(result: resultResponse)
            
            try? self.saveDataToJsonFile(keychainIpfsSecret, jsonInitFileName: convertedInitJsonFileName)
            sleep(1)
            completion(.success(resultResponse))
            self.serialSemaphore.signal()
        } else {
            getRequest(path: path, params: params, true) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = InitResponse(json: resJSON)
                    self.storeSuccessInit(result: resultResponse)
                    completion(.success(resultResponse))
                    self.serialSemaphore.signal()
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
        self.serialSemaphore.wait()
    }
    
    public func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void) {
        let path = "init"
        var secondsFromGMT: Int { return TimeZone.current.secondsFromGMT() }
        let hours = secondsFromGMT/3600
        
        var params: [String: String] = [
            "shop_id": shopId,
            "tz": String(hours)
        ]
        
        let dId = UserDefaults.standard.string(forKey: "device_id") ?? ""
        if dId != "" {
            params["did"] = dId
        }
        
        let advId = idfa.uuidString
        if advId == "00000000-0000-0000-0000-000000000000" || advId == "" {
            return
        }
        params["ios_advertising_id"] = advId
        UserDefaults.standard.set(advId, forKey: "IDFA")
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 1
        sessionConfig.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: sessionConfig)
        
        getRequest(path: path, params: params, true) { result in
            switch result {
            case let .success(successResult):
                let resJSON = successResult
                let resultResponse = InitResponse(json: resJSON)
                completion(.success(resultResponse))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
    
    public func deleteUserCredentials() {
        let convertedInitJsonFileName = self.shopId + baseInitJsonFileName
        let initFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(convertedInitJsonFileName)
        try? FileManager.default.removeItem(at: initFileNamePath)
        
        UserDefaults.standard.set(nil, forKey: "device_id")
        UserDefaults.standard.set(nil, forKey: "seance_id")
    }
    
    func getStories(code: String, completion: @escaping (Result<StoryContent, SdkError>) -> Void) {
        sessionQueue.addOperation {
            self.storiesCode = code
            let path = "stories/\(code)"
            let params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceId
            ]
            let sessionConfig = URLSessionConfiguration.default
            if SdkConfiguration.stories.storiesSlideReloadManually {
                sessionConfig.timeoutIntervalForRequest = SdkConfiguration.stories.storiesSlideReloadTimeoutInterval
                sessionConfig.waitsForConnectivity = false
                sessionConfig.shouldUseExtendedBackgroundIdleMode = false
            } else {
                sessionConfig.timeoutIntervalForRequest = 5
                sessionConfig.waitsForConnectivity = true
                sessionConfig.shouldUseExtendedBackgroundIdleMode = true
            }
            self.urlSession = URLSession(configuration: sessionConfig)
            
            self.getRequest(path: path, params: params, false) { result in
                switch result {
                case let .success(successResult):
                    let res = StoryContent(json: successResult)
                    completion(.success(res))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func saveDataToJsonFile(_ data: Data, jsonInitFileName: String = "sdkinit.json") throws {
        let jsonFileURL = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(jsonInitFileName)
        do {
            let fileExists = (try? jsonFileURL.checkResourceIsReachable()) ?? false
            print("SDK Success initialization with exist json file\n\(jsonFileURL)\n")
            if !fileExists {
                try data.write(to: jsonFileURL)
            }
            
        } catch let error as NSError {
            print(error)
            try data.write(to: jsonFileURL)
        }
    }
    
    func storeSuccessInit(result: InitResponse) {
        let successInitDeviceId: String? = result.deviceId
        let successSeanceId: String? = result.seance
        let keychainDid: String? = UserDefaults.standard.string(forKey: "device_id") ?? ""
        if (keychainDid == nil || keychainDid == "") {
            DispatchQueue.onceTechService(token: "keychainDid") {
                UserDefaults.standard.set(successInitDeviceId, forKey: "device_id")
            }
        }
        UserDefaults.standard.set(successSeanceId, forKey: "seance_id")
    }
    
    internal func configuration() -> SdkConfiguration.Type {
        return SdkConfiguration.self
    }
    
    func getRequest(path: String, params: [String: String], _ isInit: Bool = false, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        let urlString = baseURL + path
#if DEBUG
        print("LOG: getRequest to: \(urlString)")
#endif
        
        var url = URLComponents(string: urlString)
        
        var queryItems = [URLQueryItem]()
        for item in params {
            queryItems.append(URLQueryItem(name: item.key, value: item.value))
        }
        
        queryItems.append(URLQueryItem(name: "stream", value: stream))
        url?.queryItems = queryItems
        
        if (!isInit && path == "init") {
            let convertedInitJsonFileName = self.shopId + baseInitJsonFileName
            let initFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(convertedInitJsonFileName)
            let iData = NSData(contentsOf: initFileNamePath)
            let json = try? JSONSerialization.jsonObject(with: iData! as Data)
            if let jsonObject = json as? [String: Any] {
                completion(.success(jsonObject))
            } else {
                completion(.failure(.decodeError))
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
                            print("\nStatus message: ", statusMessage)
                        }
                        completion(.failure(.invalidResponse))
                        return
                    }
                    do {
                        if isInit {
                            let convertedInitJsonFileName = self.shopId + self.baseInitJsonFileName
                            try self.saveDataToJsonFile(data, jsonInitFileName: convertedInitJsonFileName)
                            try InitService.insertKeychainDidToken(data, identifier: self.sdkBundleId!, instanceKeychainService: self.appBundleId!)
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
    
    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
#if DEBUG
        print("LOG: postRequest to: \(self.baseURL + path)")
#endif
        var requestParams : [String: Any] = [
            "stream": stream
        ]
        for (key, value) in params {
            requestParams[key] = value
        }
        if self.deviceId == "" {
            self.sessionQueue.pause()
            sleep(5)
            let dId = UserDefaults.standard.string(forKey: "device_id") ?? ""
            self.deviceId = dId
            requestParams["did"] = dId
            self.sessionQueue.resume()
        }
        if let url = URL(string: baseURL + path) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestParams, options: .prettyPrinted)
            } catch let error {
                completion(.failure(.custom(error: "00001: \(error.localizedDescription)")))
                return
            }
            
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            urlSession.postTask(with: request) { result in
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
    
    func generateString(array : [String]) -> String {
        let mapArray = array.map{ String($0) }
        return mapArray.joined(separator: ",")
    }
    
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        jsonDecoder.dateDecodingStrategy = .formatted(dateFormatter)
        return jsonDecoder
    }()
}
