import UIKit
import Foundation
import AdSupport
import AppTrackingTransparency

public var global_EL: Bool = true

// MARK: - SimplePersonalizationSDK

private enum ProbabilityToPurchaseNetworkConstants {
    /// Default `URLSessionConfiguration.timeoutIntervalForRequest` for purchase probability API calls.
    static let requestTimeoutIntervalSeconds: TimeInterval = 15
}

class SimplePersonalizationSDK: PersonalizationSDK {
    private var global_EL: Bool = false
    
    var parentViewController: UIViewController?
    
    weak var popupPresentationDelegate: PopupPresentationDelegate?
    var enableAutoPopupPresentation: Bool
    
    var storiesCode: String?
    var shopId: String
    var deviceId: String
    var userSeance: String
    var stream: String
    var baseURL: String
    let baseInitJsonFileName = ".json"
    let autoSendPushToken: Bool
    let needReInitialization: Bool
    let sendAdvertisingId: Bool

    /// This shop's identity/session storage (R2): `device_id` / `seance` / `IDFA` are read and written
    /// through this typed port, backed by a per-shop partition so two shops in one app do not share
    /// identity. The push token stays device-global. See [UserIdentityRepository].
    let userIdentity: UserIdentityRepository

    /// This shop's keychain-backed init-secret backup (R2), keyed per shop so the did that survives a
    /// reinstall belongs to this shop only. See [KeychainInitStore].
    let keychainStore: KeychainInitStore

    /// Owns the session id with a rolling 2h TTL, persisted per shop and reused across cold starts —
    /// aligned with Android/RN. See [SessionManager].
    let sessionManager: SessionManager

    /// Per-shop stories UI state (viewed slides / downloaded media / cart / favourites). Reached from
    /// the stories views through the `PersonalizationSDK.localState` bridge. See [LocalStateRepository].
    let localStateStore: LocalStateRepository

    /// Per-shop attribution set through `tracking.setSource(_:)`. Reached from the tracking services
    /// through the `PersonalizationSDK.trackingSourceStore` bridge. See [TrackingSourceStore].
    let sourceStore: TrackingSourceStore
    
    let sdkBundleId = Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier
    let appBundleId = Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier
    
    var userEmail: String?
    var userPhone: String?
    var userLoyaltyId: String?
    var segment: String
    /// The session every request goes through. Each request carries its own timeout.
    var urlSession: URLSession
    /// For stories reloaded by hand: without network a request fails at once.
    let sessionWithoutWaiting: URLSession
    var userInfo: InitResponse = InitResponse()
    
    /// This shop's requests: another shop's wait for its device id does not hold them.
    private let requestQueue: ShopSessionQueue
    var sessionQueue: SessionQueue { requestQueue }
    private var requestOperation: RequestOperation?
    let bodyMutableData = NSMutableData()
    private let initSemaphore = DispatchSemaphore(value: 0)
    private let serialSemaphore = DispatchSemaphore(value: 0)
    
    lazy var trackEventService: TrackEventServiceProtocol = {
        return TrackEventServiceImpl(sdk: self)
    }()
    
    lazy var trackSourceService: TrackSourceServiceProtocol = {
        return TrackSourceServiceImpl(store: self.sourceStore)
    }()

    /// The `tracking` namespace, built over the very services the deprecated root-level tracking
    /// methods use — so both entry points share one popup handler, one session queue and one stored
    /// source. Overrides the protocol's default (which has to build its own services, having only the
    /// public protocol to work with) and, being stored, costs one allocation instead of one per call.
    lazy var tracking: TrackingAPI = {
        return TrackingAPIImpl(
            trackService: self.trackEventService,
            sourceService: self.trackSourceService
        )
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
    
    lazy var updateAdvertisingIdUseCase: UpdateAdvertisingIdUseCase = {
        let advertisingIdAdapter = IDFAAdapter()
        return UpdateAdvertisingIdUseCase(
            advertisingIdPort: advertisingIdAdapter,
            profileData: self.profileData
        )
    }()
    
    lazy var popupPresenter: PopupPresenter = {
        return PopupPresenter(sdk: self)
    }()

    /// Popups v3 of this instance (behind the v3 gate, see `PersonalizationSDK.popups`). Created
    /// at the end of `init`, so it never races between the session queue and the host.
    lazy var popupsV3: PersonalizationPopups = {
        return PersonalizationPopups(sdk: self)
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
        sendAdvertisingId: Bool = false,
        parentViewController: UIViewController? = nil,
        enableAutoPopupPresentation: Bool = true,
        needReInitialization: Bool = false,
        storageKey: String? = nil,
        userIdentity: UserIdentityRepository? = nil,
        keychainStore: KeychainInitStore? = nil,
        sessionManager: SessionManager? = nil,
        localState: LocalStateRepository? = nil,
        completion: ((SdkError?) -> Void)? = nil
    ) {
        self.shopId = shopId
        self.requestQueue = ShopSessionQueue(name: "com.personalization.sdk.requests.\(shopId)")

        // R2: identity/session live in this shop's partition. The default repository migrates the
        // pre-partition identity in once (existing installs keep their did); an injected repository
        // (tests) is used verbatim.
        let identity = userIdentity ?? UserIdentityRepositoryImpl(shopId: shopId, storageKey: storageKey)
        self.userIdentity = identity

        // R2: stories UI state (viewed/downloaded/cart/favourites) shares this shop's partition suite.
        self.localStateStore = localState
            ?? LocalStateRepositoryImpl(store: StoragePartition.store(for: shopId, storageKey: storageKey))

        // R2: the attribution `tracking.setSource(_:)` stores is shop-scoped too — a source set for one
        // shop must not colour another shop's events. Reads still fall back to the legacy shared keys
        // so an install upgrading mid-window keeps its source.
        self.sourceStore = TrackingSourceStoreImpl(
            store: StoragePartition.store(for: shopId, storageKey: storageKey)
        )

        // R2: the keychain init-secret backup is keyed per shop, adopting the legacy item once so a
        // reinstall keeps this shop's did — also the one a CocoaPods build kept under the framework's
        // bundle id, for an app now linking the SDK through SwiftPM. Injected (tests) is used verbatim.
        let keychainService = Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier ?? "com.rees46.sdk"
        self.keychainStore = keychainStore ?? KeychainInitStoreImpl(
            shopId: shopId,
            service: keychainService,
            previousServices: [KeychainPartition.cocoaPodsFrameworkService]
        )

        // Session (aligned with Android/RN): a rolling 2h client session over the per-shop partition.
        self.sessionManager = sessionManager ?? SessionManagerImpl(identity: identity)

        self.autoSendPushToken = autoSendPushToken
        self.parentViewController = parentViewController
        self.enableAutoPopupPresentation = enableAutoPopupPresentation
        
        global_EL = enableLogs
        self.baseURL = "https://" + apiDomain + "/"
        self.userEmail = userEmail
        self.userPhone = userPhone
        self.userLoyaltyId = userLoyaltyId
        self.stream = stream
        self.storiesCode = nil
        self.needReInitialization = needReInitialization
        self.sendAdvertisingId = sendAdvertisingId
        
        // Resolve the session (reuse the persisted one within the 2h window, else start a new one)
        // and the device's A/B segment.
        userSeance = self.sessionManager.currentSessionId()
        segment = Self.abSegment(of: identity)
        
        // Fetch user session (permanent user Id)
        if !needReInitialization {
            Self.restoreDeviceId(into: identity, from: self.keychainStore)
        }
        // A forced re-initialization drops the stored device id: requests wait for the new one.
        deviceId = needReInitialization ? "" : (self.userIdentity.deviceId ?? "")
        urlSession = URLSession(configuration: Self.sessionConfiguration(waitsForConnectivity: true))
        sessionWithoutWaiting = URLSession(configuration: Self.sessionConfiguration(waitsForConnectivity: false))
        _ = popupsV3
        
        let initOperation = BlockOperation {
            self.sendInitRequest { initResult in
                switch initResult {
                case .success(let response):
                    self.userInfo = response
                    // Session is client-owned (see SessionManager) — the server-assigned seance is
                    // intentionally not adopted, matching Android/RN.
                    self.deviceId = response.deviceId

                    // The contacts given at creation identify the user: they go to the profile.
                    if self.userEmail != nil || self.userPhone != nil || self.userLoyaltyId != nil {
                        self.setProfileData(
                            userEmail: self.userEmail,
                            userPhone: self.userPhone,
                            userLoyaltyId: self.userLoyaltyId
                        ) { _ in }
                    }
                    
                    if let popup = response.popup {
                        self.popupPresenter.presentPopup(popup)
                    }
                    self.popupsV3.initFinished(flag: response.popupsV3)
                    
                    // Handle push token if autoSendPushToken is true
                    if self.autoSendPushToken {
                        self.handleAutoSendPushToken()
                    }

                    if self.sendAdvertisingId {
                        self.updateAdvertisingIdUseCase.execute { result in
                            #if DEBUG
                            switch result {
                            case .success(let advertisingId):
                                print("Advertising ID sent successfully: \(advertisingId.value)")
                            case .failure(let error):
                                print("Failed to send Advertising ID: \(error.localizedDescription)")
                            }
                            #endif
                        }
                    }
                    
                    completion?(nil)
                    
                case .failure(let error):
                    completion?(error)
                }
                
                self.initSemaphore.signal()
            }
        }
        // Requests made before the device id is known wait for /init and go out with its id.
        if deviceId.isEmpty {
            requestQueue.hold(until: initOperation)
        }
        sessionQueue.addOperation(initOperation)
        
        initializeNotificationRegistrar()
    }
    
    func getDeviceId() -> String {
        return deviceId
    }
    
    @available(*, deprecated, message: "Use enableAutoPopupPresentation or popupPresentationDelegate instead")
    func setParentViewController(controller: UIViewController, completion: @escaping () -> Void) {
        self.parentViewController = controller
        DispatchQueue.main.async {
            completion()
        }
    }
    
    func getNotificationWidget() -> NotificationWidget? {
        return popupPresenter.currentPopup
    }
    
    func getSession() -> String {
        return userSeance
    }
    
    func getCurrentSegment() -> String {
        return segment
    }

    /// The device's A/B segment: assigned once, then kept across launches, as Android and React
    /// Native do. Picked anew on every launch, it moved the device between A and B, and a block under
    /// an A/B test showed products on one launch and nothing on the next.
    static func abSegment(of identity: UserIdentityRepository) -> String {
        let segments = ["A", "B"]
        if let stored = identity.abSegment, segments.contains(stored) {
            return stored
        }
        let assigned = segments.randomElement() ?? "A"
        identity.abSegment = assigned
        return assigned
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
    
    @available(*, deprecated, message: "GET /notifications requires the shop secret: use getAllNotifications(shopSecret:type:...).")
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
            
            self.postRequest(path: path, params: params, timeout: nil) { (result) in
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
        excludedMerchants: [String]?,
        excludedBrands: [String]?,
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
        advertisingId: String?,
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
        popupsV3.contextChanged("profile", signature: String(describing: [
            userEmail, userPhone, userLoyaltyId, birthday.map { "\($0)" }, age.map(String.init), firstName, lastName, location,
            gender?.rawValue, telegramId, loyaltyStatus, userId, customProperties.map { properties in
                properties.keys.sorted().map { key in "\(key)=\(String(describing: properties[key] ?? nil))" }.joined(separator: ",")
            }
        ]))
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
                advertisingId:advertisingId,
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

    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackEventService.trackPurchase(request, recommendedBy: recommendedBy, completion: completion)
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
        trackEventService.trackEvent(
            event: event,
            time: time,
            category: category,
            label: label,
            value: value,
            customFields: customFields,
            completion: completion
        )
    }
    
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackEventService.trackPopupShown(popupId: popupId, completion: completion)
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
            
            self.getRequest(path: path, params: params, timeout: timeOut) { result in
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

    func getProbabilityToPurchase(
        params: PurchasePredictParams,
        completion: @escaping (Result<ProbabilityToPurchaseResponse, SdkError>) -> Void
    ) {
        sessionQueue.addOperation {
            let path = "predict/probability-to-purchase"
            var queryParams: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceId,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment": self.segment
            ]
            if let email = params.email, !email.isEmpty {
                queryParams["email"] = email
            }
            if let phone = params.phone, !phone.isEmpty {
                queryParams["phone"] = phone
            }
            if let telegramId = params.telegramId, !telegramId.isEmpty {
                queryParams["telegram_id"] = telegramId
            }
            if let loyaltyId = params.loyaltyId, !loyaltyId.isEmpty {
                queryParams["loyalty_id"] = loyaltyId
            }

            self.getRequest(path: path, params: queryParams, timeout: ProbabilityToPurchaseNetworkConstants.requestTimeoutIntervalSeconds) { result in
                switch result {
                case let .success(json):
                    if let parsed = ProbabilityToPurchaseResponse(json: json) {
                        completion(.success(parsed))
                    } else {
                        completion(.failure(.decodeError))
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func suggest(query: String, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {
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
            if let excludedMerchants = SearchFilterParams.excludedMerchants(excludedMerchants, locations: locations) {
                params["excluded_merchants"] = excludedMerchants
            }
            if let excludedBrands = excludedBrands {
                params["excluded_brands"] = excludedBrands.joined(separator: ",")
            }
            if let extended = extended {
                params["extended"] = extended
            }
            
            self.getRequest(path: path, params: params, timeout: timeOut) { result in
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
            
            self.getRequest(path: path, params: params, timeout: nil) { result in
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
            
            self.getRequest(path: path, params: params, timeout: nil) { result in
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
            
            self.getRequest(path: path, params: params, timeout: nil) { result in
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
    
    func getLastOrderProducts(completion: @escaping (Result<LastOrderProductsResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let path = "orders/last_for_user"
            let params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceId,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment": self.segment
            ]

            self.getArrayRequest(path: path, params: params, timeout: nil) { result in
                switch result {
                case let .success(array):
                    completion(.success(LastOrderProductsResponse(array: array)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func getUserOrders(shopSecret: String, did: String?, email: String?, phone: String?, loyaltyId: String?, externalId: String?, dateFrom: String?, completion: @escaping (Result<[Order], SdkError>) -> Void) {
        sessionQueue.addOperation {
            var params: [String: String] = [
                "shop_id": self.shopId,
                "shop_secret": shopSecret
            ]

            let hasIdentifier = [did, email, phone, loyaltyId, externalId].contains { $0 != nil }
            if let did = did { params["did"] = did }
            if let email = email { params["email"] = email }
            if let phone = phone { params["phone"] = phone }
            if let loyaltyId = loyaltyId { params["loyalty_id"] = loyaltyId }
            if let externalId = externalId { params["external_id"] = externalId }
            // Default to the current device id when no explicit identifier is provided.
            if !hasIdentifier { params["did"] = self.deviceId }
            if let dateFrom = dateFrom { params["date_from"] = dateFrom }

            // Envelope: { "status": ..., "data": { "orders": [...] } }
            self.getRequest(path: "orders/by_user", params: params, timeout: nil) { result in
                switch result {
                case let .success(json):
                    let ordersJson = (json["data"] as? [String: Any])?["orders"] as? [[String: Any]] ?? []
                    completion(.success(ordersJson.map { Order(json: $0) }))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func joinLoyalty(phone: String, email: String?, firstName: String?, lastName: String?, completion: @escaping (Result<LoyaltyJoinResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            // The shop is identified by `shop_id`; only the member fields are passed here.
            var params: [String: Any] = [
                "shop_id": self.shopId,
                "phone": phone
            ]
            if let email = email { params["email"] = email }
            if let firstName = firstName { params["first_name"] = firstName }
            if let lastName = lastName { params["last_name"] = lastName }

            self.postRequest(path: "loyalty/members/join", params: params, timeout: nil) { result in
                switch result {
                case let .success(json):
                    completion(.success(LoyaltyJoinResponse(json: json)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func getLoyaltyStatus(identifier: String, completion: @escaping (Result<LoyaltyStatusResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceId,
                "seance": self.userSeance,
                "sid": self.userSeance,
                "segment": self.segment,
                "identifier": identifier
            ]

            self.getRequest(path: "loyalty/members/status", params: params, timeout: nil) { result in
                switch result {
                case let .success(json):
                    completion(.success(LoyaltyStatusResponse(json: json)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func getProfile(completion: @escaping (Result<GetProfileResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceId
            ]

            self.getRequest(path: "profile", params: params, timeout: nil) { result in
                switch result {
                case let .success(json):
                    completion(.success(GetProfileResponse(json: json)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func getProductCounters(item: String, completion: @escaping (Result<ProductCountersResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let params: [String: String] = [
                "shop_id": self.shopId,
                "item": item
            ]

            self.getRequest(path: "products/counters", params: params, timeout: nil) { result in
                switch result {
                case let .success(json):
                    completion(.success(ProductCountersResponse(json: json)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func getCategory(category: String, limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, completion: @escaping (Result<CategoryResponse, SdkError>) -> Void) {
        getCategory(category: category, limit: limit, page: page, brands: brands, locations: locations, filters: filters, priceMin: nil, priceMax: nil, sortBy: nil, sortDir: nil, completion: completion)
    }

    func getCategory(category: String, limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, sortBy: String?, sortDir: String?, completion: @escaping (Result<CategoryResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            let params = self.categoryParams(limit: limit, page: page, brands: brands, locations: locations, filters: filters, priceMin: priceMin, priceMax: priceMax, sortBy: sortBy, sortDir: sortDir)

            self.getRequest(path: "category/\(category)", params: params, timeout: nil) { result in
                switch result {
                case let .success(json):
                    completion(.success(CategoryResponse(json: json)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func getCollection(collectionId: String, location: String?, email: String?, phone: String?, externalId: String?, loyaltyId: String?, completion: @escaping (Result<CollectionResponse, SdkError>) -> Void) {
        sessionQueue.addOperation {
            var params: [String: String] = [
                "shop_id": self.shopId,
                "did": self.deviceId
            ]
            if let location = location { params["location"] = location }
            if let email = email { params["email"] = email }
            if let phone = phone { params["phone"] = phone }
            if let externalId = externalId { params["external_id"] = externalId }
            if let loyaltyId = loyaltyId { params["loyalty_id"] = loyaltyId }

            self.getRequest(path: "collection/\(collectionId)", params: params, timeout: nil) { result in
                switch result {
                case let .success(json):
                    completion(.success(CollectionResponse(json: json)))
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
        telegramBulk: Bool? = nil,
        telegramChain: Bool? = nil,
        telegramTransactional: Bool? = nil,
        whatsappBulk: Bool? = nil,
        whatsappChain: Bool? = nil,
        whatsappTransactional: Bool? = nil,
        maxBulk: Bool? = nil,
        maxChain: Bool? = nil,
        maxTransactional: Bool? = nil,
        walletBulk: Bool? = nil,
        completion: @escaping(Result<Void, SdkError>) -> Void
    ) {
        popupsV3.contextChanged("subscription", signature: String(describing: [
            email, phone, userExternalId, userLoyaltyId, telegramId
        ]) + String(describing: [
            emailBulk, emailChain, emailTransactional, smsBulk, smsChain, smsTransactional, webPushBulk, webPushChain,
            webPushTransactional, mobilePushBulk, mobilePushChain, mobilePushTransactional, telegramBulk, telegramChain,
            telegramTransactional, whatsappBulk, whatsappChain, whatsappTransactional, maxBulk, maxChain, maxTransactional, walletBulk
        ]))
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
            telegramBulk:telegramBulk,
            telegramChain:telegramChain,
            telegramTransactional:telegramTransactional,
            whatsappBulk:whatsappBulk,
            whatsappChain:whatsappChain,
            whatsappTransactional:whatsappTransactional,
            maxBulk:maxBulk,
            maxChain:maxChain,
            maxTransactional:maxTransactional,
            walletBulk:walletBulk,
            completion: completion
        )
    }
    
    func addToSegment(segmentId: String, email: String? = nil, phone: String? = nil, completion: @escaping (Result<Void, SdkError>) -> Void) {
        popupsV3.contextChanged("segment", signature: String(describing: ["add", segmentId, email, phone]))
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
        popupsV3.contextChanged("segment", signature: String(describing: ["remove", segmentId, email, phone]))
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
    
    /// `/init` on every launch. The saved init answer — the documents file and its keychain backup,
    /// written by `sendIDFARequest` — stands in only when no answer came: an answer, a refused shop
    /// among them, is the server's word. The saved answer used to replace `/init` for good: the file
    /// and the keychain took turns answering every launch, and the server never saw the device again.
    private func sendInitRequest(
        completion: @escaping (Result<InitResponse, SdkError>) -> Void
    ) {
        let params = prepareRequestParameters()
        // With a saved answer to stand in, /init does not wait for the network: offline it fails at
        // once and the saved answer takes over. Without one, /init waits for the network, as before.
        let saved = needReInitialization ? nil : savedInitResponse()
        sendGet(
            path: "init",
            params: params,
            timeout: Self.initRequestTimeout,
            session: saved == nil ? nil : sessionWithoutWaiting
        ) { status, result in
            switch result.flatMap(Self.jsonObject) {
            case let .success(json):
                let resultResponse = InitResponse(json: json)
                self.storeSuccessInit(result: resultResponse)
                print("[SDK INIT Response] Successfully received server response: \(resultResponse)")
                completion(.success(resultResponse))
            case let .failure(error):
                if status == nil, let saved = saved {
                    print("[SDK INIT Response] No answer from the server, the saved init answer stands in")
                    completion(.success(saved))
                } else {
                    completion(.failure(error))
                }
            }
            self.serialSemaphore.signal()
        }
        serialSemaphore.wait()
    }

    private func prepareRequestParameters() -> [String: String] {
        let secondsFromGMT = TimeZone.current.secondsFromGMT()
        let hours = secondsFromGMT / 3600
        var params: [String: String] = [
            SdkConstants.shopId: shopId,
            SdkConstants.tz: String(hours)
        ]
        
        if needReInitialization {
            userIdentity.removeDeviceId()
            print("USER DEVICE ID WAS REMOVED")
        }

        if let deviceId = userIdentity.deviceId, !deviceId.isEmpty {
            params[SdkConstants.did] = deviceId
        }

        if let advId = userIdentity.advertisingId, advId != "00000000-0000-0000-0000-000000000000" {
            params["ios_advertising_id"] = advId
        }

        // Popups v3 test mode: the flag also counts popups in the "Test" status.
        if popupsV3.testMode {
            params["testmode"] = "true"
        }
        
        return params
    }
    
    /// The init answer saved on this device, for a launch without network. Its popup was shown when
    /// it came and is not shown again; the device id is the one this shop keeps now.
    private func savedInitResponse() -> InitResponse? {
        let savedFile = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory()
            .appendingPathComponent(shopId + baseInitJsonFileName)
        guard let data = (try? Data(contentsOf: savedFile)) ?? keychainStore.readInitData(),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        var response = InitResponse(json: json)
        response.popup = nil
        if let deviceId = userIdentity.deviceId, !deviceId.isEmpty {
            response.deviceId = deviceId
        }
        return response
    }

    /// A reinstall wipes the app's storage but not the keychain: the device id of the saved init
    /// answer comes back, so `/init` goes out with it and the shop keeps the device.
    private static func restoreDeviceId(into identity: UserIdentityRepository, from keychain: KeychainInitStore) {
        guard (identity.deviceId ?? "").isEmpty,
              let data = keychain.readInitData(),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let deviceId = json["did"] as? String, !deviceId.isEmpty else {
            return
        }
        identity.deviceId = deviceId
    }
    
    func saveDataToJsonFile(_ data: Data, jsonInitFileName: String = "sdkinit.json") throws {
        let jsonFileURL = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(jsonInitFileName)
        do {
            let fileExists = (try? jsonFileURL.checkResourceIsReachable()) ?? false
            if !fileExists {
                try data.write(to: jsonFileURL)
            }
        } catch {
            print(error)
            try data.write(to: jsonFileURL)
        }
    }
    
    public func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void) {
        let path = "init"
        var secondsFromGMT: Int { return TimeZone.current.secondsFromGMT() }
        let hours = secondsFromGMT/3600
        
        var params: [String: String] = [
            SdkConstants.shopId: shopId,
            SdkConstants.tz: String(hours)
        ]
        
        let dId = userIdentity.deviceId ?? ""
        if dId != "" {
            params[SdkConstants.did] = dId
        }

        let advId = idfa.uuidString
        if advId == "00000000-0000-0000-0000-000000000000" || advId == "" {
            return
        }
        params["ios_advertising_id"] = advId
        userIdentity.advertisingId = advId
        
        sendGet(path: path, params: params, isInit: true, timeout: Self.initRequestTimeout) { _, result in
            switch result.flatMap(Self.jsonObject) {
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

        userIdentity.clearIdentity()
        // Also drop the keychain backup — otherwise a re-init would restore the very did we just
        // deleted from its reinstall-surviving copy.
        keychainStore.clear()

        // Multi-instance groundwork (R1): this instance is torn down — drop it from push routing so a
        // superseded object is not fed push tokens or resolved by `shop_id`.
        SdkRegistry.shared.unregister(self)
    }

    deinit {
        // Weak registry (see SdkRegistry): a host-released instance deallocs here — purge its routing
        // slots eagerly instead of waiting for the next compaction.
        SdkRegistry.shared.unregister(self)
    }
    
    func getStories(code: String, completion: @escaping (Result<StoryContent, SdkError>) -> Void) {
        sessionQueue.addOperation {
            self.storiesCode = code
            let path = "stories/\(code)"
            let params: [String: String] = [
                SdkConstants.shopId: self.shopId,
                SdkConstants.did: self.deviceId
            ]
            // Reloaded by hand, a slide fails at once without network, so it can offer a retry.
            let manualReload = SdkConfiguration.stories.storiesSlideReloadManually
            self.sendGet(
                path: path,
                params: params,
                timeout: manualReload ? SdkConfiguration.stories.storiesSlideReloadTimeoutInterval : 5,
                session: manualReload ? self.sessionWithoutWaiting : nil
            ) { _, result in
                switch result.flatMap(Self.jsonObject) {
                case let .success(successResult):
                    let res = StoryContent(json: successResult, shopId: self.shopId)
                    completion(.success(res))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func storeSuccessInit(result: InitResponse) {
        persistDeviceIdIfAbsent(result.deviceId)
        // Session is client-owned (see SessionManager) — the server seance is not persisted here.
    }

    private static let deviceIdPersistLock = NSObject()

    /// Persists the server-assigned device id exactly once — only when none is stored yet.
    ///
    /// Gated on the *current* stored value under a process-wide lock (not a one-shot token), so
    /// concurrent inits can't clobber each other with different ids, while a deliberate reset
    /// (`needReInitialization`, `deleteUserCredentials`) can still re-establish it afterwards.
    private func persistDeviceIdIfAbsent(_ deviceId: String?) {
        guard let deviceId = deviceId, !deviceId.isEmpty else { return }
        objc_sync_enter(Self.deviceIdPersistLock)
        defer { objc_sync_exit(Self.deviceIdPersistLock) }
        let current = userIdentity.deviceId ?? ""
        if current.isEmpty {
            userIdentity.deviceId = deviceId
        }
    }
    
    internal func configuration() -> SdkConfiguration.Type {
        return SdkConfiguration.self
    }
    
    /// Idle timeout of a request that does not ask for its own: the read timeout of the Android SDK.
    static let defaultRequestTimeout: TimeInterval = 10

    /// Timeout of `/init`: the server itself gives up after five seconds.
    static let initRequestTimeout: TimeInterval = 5

    func getRequest(path: String, params: [String: String], _ isInit: Bool = false, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        sendGet(path: path, params: params, isInit: isInit, timeout: nil) { _, result in
            completion(result.flatMap(Self.jsonObject))
        }
    }

    /// `getRequest` with the call's own timeout.
    func getRequest(path: String, params: [String: String], timeout: TimeInterval?, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        sendGet(path: path, params: params, timeout: timeout) { _, result in
            completion(result.flatMap(Self.jsonObject))
        }
    }

    /// Variant of `getRequest` for endpoints that return a top-level JSON array
    /// (e.g. `orders/last_for_user`), which `getRequest` cannot decode into `[String: Any]`.
    private func getArrayRequest(path: String, params: [String: String], timeout: TimeInterval?, completion: @escaping (Result<[[String: Any]], SdkError>) -> Void) {
        sendGet(path: path, params: params, timeout: timeout, forgetsSavedInit: false) { _, result in
            completion(result.flatMap { json in
                (json as? [[String: Any]]).map { .success($0) } ?? .failure(.decodeError)
            })
        }
    }

    static func jsonObject(_ json: Any) -> Result<[String: Any], SdkError> {
        (json as? [String: Any]).map { .success($0) } ?? .failure(.decodeError)
    }

    /// One GET of `path` with the call's own timeout. Hands back the answer's HTTP status — nil when
    /// no answer came — and its decoded JSON.
    func sendGet(
        path: String,
        params: [String: String],
        isInit: Bool = false,
        timeout: TimeInterval?,
        session: URLSession? = nil,
        forgetsSavedInit: Bool = true,
        completion: @escaping (_ status: Int?, _ result: Result<Any, SdkError>) -> Void
    ) {
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

        if forgetsSavedInit && needReInitialization {
            print("Reinitialization needed. Clearing saved data...")
            let convertedInitJsonFileName = self.shopId + baseInitJsonFileName
            let initFileNamePath = SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(convertedInitJsonFileName)
            do {
                if FileManager.default.fileExists(atPath: initFileNamePath.path) {
                    try FileManager.default.removeItem(at: initFileNamePath)
                    print("Saved data deleted successfully.")
                }
            } catch {
                print("Error deleting saved data: \(error)")
            }
        }

        guard let endUrl = url?.url else {
            completion(nil, .failure(.invalidResponse))
            return
        }
        (session ?? urlSession).postTask(with: request(for: endUrl, timeout: timeout)) { result in
            switch result {
            case .success(let (response, data)):
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard 200 ..< 299 ~= statusCode else {
                    let json = try? JSONSerialization.jsonObject(with: data)
                    if let jsonObject = json as? [String: Any] {
                        let statusMessage = jsonObject["message"] as? String ?? ""
                        print("\nStatus message: ", statusMessage)
                    }
                    completion(statusCode, .failure(.invalidResponse))
                    return
                }
                do {
                    if isInit {
                        let convertedInitJsonFileName = self.shopId + self.baseInitJsonFileName
                        try self.saveDataToJsonFile(data, jsonInitFileName: convertedInitJsonFileName)
                        self.keychainStore.writeInitData(data)
                    }
                    completion(statusCode, .success(try JSONSerialization.jsonObject(with: data)))
                } catch {
                    completion(statusCode, .failure(.decodeError))
                }
            case .failure:
                completion(nil, .failure(Self.transportError()))
            }
        }.resume()
    }

    /// A request with the call's own timeout. The session is shared: a call that swapped in a session
    /// with its own timeout changed it for every call in flight on the session queue.
    private func request(for url: URL, timeout: TimeInterval?) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout ?? Self.defaultRequestTimeout
        return request
    }

    /// A request that got no answer: offline, or the connection failed or timed out.
    private static func transportError() -> SdkError {
        NetworkStatus.nManager.connectionStatus == .Offline ? .networkOfflineError : .invalidResponse
    }

    /// The configuration of the SDK's sessions. Waiting for connectivity, a request starts its timeout
    /// once the network is back.
    static func sessionConfiguration(waitsForConnectivity: Bool) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = waitsForConnectivity
        configuration.shouldUseExtendedBackgroundIdleMode = waitsForConnectivity
        return configuration
    }

    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        postRequest(path: path, params: params, timeout: nil, completion: completion)
    }

    /// `postRequest` with the call's own timeout.
    func postRequest(path: String, params: [String: Any], timeout: TimeInterval?, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
#if DEBUG
        print("LOG: postRequest to: \(self.baseURL + path)")
#endif
        var requestParams : [String: Any] = [
            "stream": stream
        ]
        for (key, value) in params {
            requestParams[key] = value
        }
        // A request made before the device id was known waited for /init on the queue; when /init
        // failed, the stored id is the best there is.
        if self.deviceId == "" {
            let dId = self.userIdentity.deviceId ?? ""
            self.deviceId = dId
            requestParams["did"] = dId
        }
        if let url = URL(string: baseURL + path) {
            var request = self.request(for: url, timeout: timeout)
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
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    guard 200 ..< 299 ~= statusCode else {
#if DEBUG
                        let errorBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body, \(data.count) bytes>"
                        print("LOG: postRequest HTTP \(statusCode) path=\(path) response=\(errorBody)")
#endif
                        if let json = try? JSONSerialization.jsonObject(with: data) {
                            if let jsonObject = json as? [String:Any] {
                                if let status = jsonObject["status"] as? String, status == "error" {
                                    if let errorMessage = jsonObject["message"] as? String {
                                        completion(.failure(.custom(error: errorMessage)))
                                        return
                                    }
                                }
                            }
                        }
                        completion(.failure(.invalidResponse))
                        return
                    }
#if DEBUG
                    let successBody = data.isEmpty
                        ? "<empty>"
                        : (String(data: data, encoding: .utf8) ?? "<non-utf8 body, \(data.count) bytes>")
                    print("LOG: postRequest HTTP \(statusCode) path=\(path) response=\(successBody)")
#endif
                    do {
                        if data.isEmpty {
                            if path.contains("clicked") || path.contains("closed") || path.contains("received") || path.contains("showed") {
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
                    completion(.failure(Self.transportError()))
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
