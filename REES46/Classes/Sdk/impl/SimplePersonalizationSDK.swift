import UIKit
import Foundation
import AdSupport
import AppTrackingTransparency

@available(*, deprecated, message: "Has no effect: set Rees46Config.logLevel.")
public var global_EL: Bool = true

// MARK: - SimplePersonalizationSDK

private enum ProbabilityToPurchaseNetworkConstants {
    /// Default `URLSessionConfiguration.timeoutIntervalForRequest` for purchase probability API calls.
    static let requestTimeoutIntervalSeconds: TimeInterval = 15
}

class SimplePersonalizationSDK: PersonalizationSDK {
    
    var parentViewController: UIViewController?
    
    weak var popupPresentationDelegate: PopupPresentationDelegate?
    var enableAutoPopupPresentation: Bool
    
    var storiesCode: String?
    var shopId: String
    var deviceId: String
    var userSeance: String
    var stream: String
    var baseURL: String
    let autoSendPushToken: Bool
    let needReInitialization: Bool
    let sendAdvertisingId: Bool
    /// The app's prefix of the shop's storage (`Rees46Config.storageKey`).
    let storageKey: String?

    /// This shop's identity/session storage (R2): `device_id` / `seance` / `IDFA` are read and written
    /// through this typed port, backed by a per-shop partition so two shops in one app do not share
    /// identity. The push token stays device-global. See [UserIdentityRepository].
    let userIdentity: UserIdentityRepository

    /// This shop's keychain-backed init-secret backup (R2), keyed per shop so the did that survives a
    /// reinstall belongs to this shop only. See [KeychainInitStore].
    let keychainStore: KeychainInitStore

    /// This shop's partition and files: the saved `/init` answer, `refused`, the queue's folder, the
    /// migration flags. See [ShopStorage].
    let storage: ShopStorage

    /// Owns the session id with a rolling 2h TTL, persisted per shop and reused across cold starts —
    /// aligned with Android/RN. See [SessionManager].
    let sessionManager: SessionManager

    /// This instance's logger: its `logLevel`, its shop on every message.
    let logger: SdkLogger

    /// Whether the device is online; a failed request offline is `networkOfflineError`.
    let connectivity: ConnectivityMonitor

    /// Whether this instance runs the new core: the process's `Rees46Config.coreV2` (`CoreFlag`).
    let usesCoreV2: Bool

    /// The configuration the instance was made with: a later `Rees46.initialize` of the shop compares.
    let config: Rees46Config

    /// The instance's state (`Rees46.SdkState`) and its listeners.
    let instanceState = InstanceState()

    /// The completion of `Rees46.initialize`, also of later calls for the shop: once, with the outcome
    /// of the first initialization.
    let initCompletion: InitCompletion

    /// The new core's seams: time, pauses, the app's lifecycle.
    let environment: CoreEnvironment

    /// Where this instance's requests go: the old paths (`LegacyCore`) or the new client (`CoreV2`).
    /// Made at the end of `init`, before any request can reach it.
    lazy var core: Core = makeCore()

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
    /// The session of the old core's requests; each request carries its own timeout. Made on first
    /// use: an instance on the new core sends through its own client and never makes it. A session
    /// the app sets gives the new core its configuration, not its delegate (see `Rees46Config.coreV2`).
    var urlSession: URLSession {
        get {
            sessionLock.lock(); defer { sessionLock.unlock() }
            if let session = legacySession {
                return session
            }
            let session = URLSession(configuration: LegacyCore.sessionConfiguration(waitsForConnectivity: true))
            legacySession = session
            return session
        }
        set {
            sessionLock.lock()
            legacySession = newValue
            sessionLock.unlock()
            guard usesCoreV2 else { return }
            if newValue.delegate != nil {
                logger.warning(
                    LogCode.invalidConfig,
                    "coreV2 sends with the configuration of the app's URLSession, not with its delegate: pinning set there does not apply",
                    ["reason": "url_session_delegate"]
                )
            }
            core.use(newValue.configuration)
        }
    }
    private var legacySession: URLSession?
    private let sessionLock = NSLock()
    var userInfo: InitResponse = InitResponse()
    
    /// This shop's requests: another shop's wait for its device id does not hold them.
    private let requestQueue: ShopSessionQueue
    var sessionQueue: SessionQueue { requestQueue }
    private var requestOperation: RequestOperation?
    let bodyMutableData = NSMutableData()
    
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
        logLevel: Rees46.LogLevel = .warning,
        autoSendPushToken: Bool = true,
        sendAdvertisingId: Bool = false,
        parentViewController: UIViewController? = nil,
        enableAutoPopupPresentation: Bool = true,
        needReInitialization: Bool = false,
        storageKey: String? = nil,
        coreV2: Bool = false,
        deviceId configuredDeviceId: String? = nil,
        environment: CoreEnvironment? = nil,
        userIdentity: UserIdentityRepository? = nil,
        keychainStore: KeychainInitStore? = nil,
        shopStorage: ShopStorage? = nil,
        sessionManager: SessionManager? = nil,
        localState: LocalStateRepository? = nil,
        connectivity: ConnectivityMonitor? = nil,
        completion: ((SdkError?) -> Void)? = nil
    ) {
        self.shopId = shopId
        self.storageKey = storageKey
        // Code that has only the shop at hand (stories, popups v3) opens the same partition.
        StoragePartition.remember(storageKey: storageKey, forShop: shopId)
        self.connectivity = connectivity ?? SystemConnectivityMonitor.shared
        // `enableLogs` is the old switch: on, it means everything (`debug`), as in `Rees46Config`.
        self.logger = SdkLogger(shopId: shopId, level: enableLogs && logLevel == .warning ? .debug : logLevel)
        self.usesCoreV2 = CoreFlag.resolve(requested: coreV2)
        CoreFlag.reportMismatch(requested: coreV2, active: usesCoreV2, logger: logger)
        self.config = Rees46Config(
            shopId: shopId,
            apiDomain: apiDomain,
            stream: stream,
            deviceId: configuredDeviceId,
            enableLogs: enableLogs,
            logLevel: logLevel,
            autoSendPushToken: autoSendPushToken,
            sendAdvertisingId: sendAdvertisingId,
            enableAutoPopupPresentation: enableAutoPopupPresentation,
            needReInitialization: needReInitialization,
            storageKey: storageKey,
            coreV2: coreV2
        )
        self.initCompletion = InitCompletion(onMain: usesCoreV2)
        self.environment = environment ?? CoreEnvironment()
        self.requestQueue = ShopSessionQueue(name: "com.personalization.sdk.requests.\(shopId)")

        // The shop's partition — `storageKey` is the app's prefix of it — and its files.
        let storage = shopStorage ?? ShopStorage(shopId: shopId, storageKey: storageKey, logger: logger)
        self.storage = storage

        // R2: identity/session live in this shop's partition. The default repository runs the identity
        // migrations once, before /init (existing installs keep their did); an injected repository
        // (tests) is used verbatim.
        let identity = userIdentity ?? UserIdentityRepositoryImpl(shopId: shopId, storageKey: storageKey)
        self.userIdentity = identity

        // R2: stories UI state (viewed/downloaded/cart/favourites) shares this shop's partition suite.
        self.localStateStore = localState ?? LocalStateRepositoryImpl(store: storage.partition)

        // R2: the attribution `tracking.setSource(_:)` stores is shop-scoped too — a source set for one
        // shop must not colour another shop's events. Reads still fall back to the legacy shared keys
        // so an install upgrading mid-window keeps its source.
        self.sourceStore = TrackingSourceStoreImpl(store: storage.partition)

        // The saved init answer leaves Documents for the SDK's folder, once.
        StorageMigrations.once(.savedInitFile, in: storage.partition) { storage.moveLegacySavedInitAnswer() }

        // R2: the keychain init-secret backup is keyed per shop, adopting the legacy item once so a
        // reinstall keeps this shop's did — also the one a CocoaPods build kept under the framework's
        // bundle id, for an app now linking the SDK through SwiftPM. The service is pinned
        // (`KeychainPartition.service`). Injected (tests) is used verbatim.
        self.keychainStore = keychainStore ?? KeychainInitStoreImpl(
            shopId: shopId,
            service: KeychainPartition.service,
            previousServices: KeychainPartition.previousServices,
            partition: storage.partition
        )

        // Session (aligned with Android/RN): a rolling 2h client session over the per-shop partition.
        self.sessionManager = sessionManager ?? SessionManagerImpl(identity: identity)

        self.autoSendPushToken = autoSendPushToken
        self.parentViewController = parentViewController
        self.enableAutoPopupPresentation = enableAutoPopupPresentation
        
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
        
        if needReInitialization {
            // The new core forgets the customer's device id, the saved answer and its keychain backup
            // once, before /init; the old one drops the device id on its /init, as it always has.
            if usesCoreV2 {
                identity.removeDeviceId()
                storage.removeSavedInitAnswer()
                self.keychainStore.clear()
                logger.info(LogCode.deviceIdReset, "the stored device id was removed to get a new one", ["reason": "re_initialization"])
            }
        } else {
            // The shop's own device id; the one the app brought when it has none; the one the keychain
            // kept through a reinstall.
            Self.adoptConfiguredDeviceId(configuredDeviceId, into: identity, logger: logger)
            Self.restoreDeviceId(into: identity, from: self.keychainStore)
        }
        // A forced re-initialization drops the stored device id: requests wait for the new one.
        deviceId = needReInitialization ? "" : (self.userIdentity.deviceId ?? "")
        // Code without the instance at hand (push routing, UI) logs at this instance's level while it lives.
        SdkLogger.register(logger, owner: self)
        _ = core
        _ = popupsV3

        initCompletion.add(completion)
        if let machine = initMachine {
            machine.delegate = self
            machine.start()
        } else {
            // The old core is ready with a device id, and initializing until /init brings one.
            instanceState.set(deviceId.isEmpty ? .initializing : .ready)
            // Requests made before the device id is known wait for /init and go out with its id.
            if deviceId.isEmpty {
                requestQueue.close()
            }
            startInit(generation: currentInitGeneration()) { [initCompletion] error in
                initCompletion.finish(error)
            }
        }
        
        initializeNotificationRegistrar()
    }

    /// The device id the app brought (`Rees46Config.deviceId`), taken only when the shop has none.
    static func adoptConfiguredDeviceId(_ configured: String?, into identity: UserIdentityRepository, logger: SdkLogger) {
        guard let configured = configured, !configured.isEmpty else { return }
        let stored = identity.deviceId ?? ""
        if stored.isEmpty {
            identity.deviceId = configured
        } else if stored != configured {
            logger.warning(LogCode.invalidConfig, "the shop keeps its own device id: the configured one was not taken", ["reason": "device_id_kept"])
        }
    }

    /// The new core's `/init`; `nil` on the old core.
    var initMachine: InitMachine? {
        (core as? CoreV2)?.machine
    }

    // MARK: - State

    var state: Rees46.SdkState {
        instanceState.current
    }

    @discardableResult
    func onStateChange(_ listener: @escaping (Rees46.SdkState) -> Void) -> Cancellable {
        instanceState.observe(listener)
    }

    var sessionId: String? {
        userSeance.isEmpty ? nil : userSeance
    }

    /// Calls `completion` once the first initialization settled, or now if it has.
    func whenInitialized(_ completion: ((SdkError?) -> Void)?) {
        initCompletion.add(completion)
    }

    // MARK: - /init

    /// Counts the instance's `/init`s: `deleteUserCredentials` starts another, and a late answer to an
    /// earlier one changes nothing. `initLock` guards the count and everything an `/init` answer writes
    /// — the device id in storage and here, the saved answer, the opening of the request queue — and
    /// `deleteUserCredentials` and `release()` hold it while they raise the count, so an earlier answer
    /// lands before the wipe or not at all.
    private var initGeneration = 0
    private let initLock = NSLock()
    /// Set by `release()`: every later call is `notInitialized`.
    private var released = false
    /// The new core: whether `/init` answered since the instance was made or its customer deleted.
    private var serverAnswered = false

    private func currentInitGeneration() -> Int {
        initLock.lock(); defer { initLock.unlock() }
        return initGeneration
    }

    /// Whether `release()` stopped the instance.
    var isReleased: Bool {
        initLock.lock(); defer { initLock.unlock() }
        return released
    }

    /// Runs `write` under `initLock` when `generation` is still the instance's `/init` and the instance
    /// was not released; `false`, and nothing written, otherwise.
    @discardableResult
    private func ifCurrentInit(_ generation: Int, _ write: () -> Void = {}) -> Bool {
        initLock.lock(); defer { initLock.unlock() }
        guard generation == initGeneration, !released else { return false }
        write()
        return true
    }

    /// Queues `/init` of `generation`. Requests made while the queue is closed wait for its answer and
    /// go out with the id it brings; once a device id is stored the push token goes to the shop.
    private func startInit(generation: Int, completion: ((SdkError?) -> Void)?) {
        let initOperation = BlockOperation {
            self.sendInitRequest(generation: generation) { initResult, isCurrent in
                // A later /init took over (`deleteUserCredentials`), or the instance was released:
                // this answer belonged to the customer that was deleted, and changes nothing. The app
                // still hears once.
                guard isCurrent else {
                    if case let .failure(error) = initResult {
                        completion?(error)
                    } else {
                        completion?(nil)
                    }
                    return
                }
                switch initResult {
                case .success(let response):
                    // The old core is ready once /init gave the shop a device id.
                    if !self.deviceId.isEmpty {
                        self.instanceState.set(.ready)
                    }
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

                    // The push token goes once the device has an id: with autoSendPushToken, or when one
                    // came while the device had none.
                    self.sendPushTokenIfDeviceIdIsKnown()

                    if self.sendAdvertisingId {
                        self.updateAdvertisingIdUseCase.execute { result in
                            switch result {
                            case .success:
                                self.logger.debug(LogCode.advertisingIdSent, "the advertising id was sent")
                            case .failure(let error):
                                self.logger.warning(LogCode.advertisingIdFailed, "the advertising id was not sent", ["error": SdkLogger.errorKind(error)])
                            }
                        }
                    }
                    
                    completion?(nil)
                    
                case .failure(let error):
                    completion?(error)
                }
            }
        }
        // The init operation itself is never held: it is what opens the queue.
        sessionQueue.addOperation(initOperation)
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
    /// Native do, and the same for every shop of the app (decision 4). Picked anew on every launch, it
    /// moved the device between A and B, and a block under an A/B test showed products on one launch
    /// and nothing on the next.
    static func abSegment(of identity: UserIdentityRepository) -> String {
        identity.resolveAbSegment()
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
                if error == nil {
                    self.logger.info(LogCode.pushPermission, "the notification permission was answered", ["granted": String(granted)])
                }
                
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    
                    // Attempt to send the push token if available
                    if let deviceToken = DeviceStore.shared.pushToken {
                        let notificationRegistrar = NotificationRegistrar(sdk: self)
                        notificationRegistrar.registerWithDeviceToken(deviceToken: deviceToken)
                    }
                } else if let error = error {
                    self.logger.warning(LogCode.pushPermissionFailed, "the notification permission request failed", ["error": SdkLogger.errorKind(error)])
                }
            }
        } else {
            logger.debug(LogCode.pushTokenSkipped, "the SDK does not send the push token by itself", ["reason": "auto_send_off"])
        }
    }
    
    private func handleAutoSendPushToken() {
        if let deviceToken = DeviceStore.shared.pushToken {
            let notificationRegistrar = NotificationRegistrar(sdk: self)
            notificationRegistrar.registerWithDeviceToken(deviceToken: deviceToken)
        }
    }

    // MARK: - The push token waits for the device id

    /// A push token given while the device had no id. It never goes out without one: it goes once
    /// `/init` stores one.
    enum DeferredPushToken: Equatable {
        /// The APNs token the registrar was handed.
        case device(Data)
        /// A token given to `setPushTokenNotification` — an FCM one, say.
        case direct(token: String, isFirebase: Bool)
    }

    private var deferredPushToken: DeferredPushToken?
    private let pushTokenLock = NSLock()

    /// Keeps `token` until the device has an id; a later one replaces it.
    func deferPushToken(_ token: DeferredPushToken) {
        pushTokenLock.lock()
        deferredPushToken = token
        pushTokenLock.unlock()
        logger.debug(LogCode.pushTokenSkipped, "the push token waits for the device id", ["reason": "no_device_id"])
    }

    /// The push token deferred for want of a device id; for tests.
    var pendingPushToken: DeferredPushToken? {
        pushTokenLock.lock(); defer { pushTokenLock.unlock() }
        return deferredPushToken
    }

    /// After `/init` stored a device id: the push token goes with `autoSendPushToken`, and so does one
    /// that came while the device had none.
    private func sendPushTokenIfDeviceIdIsKnown() {
        guard !deviceId.isEmpty, !isReleased else { return }
        pushTokenLock.lock()
        let deferred = deferredPushToken
        deferredPushToken = nil
        pushTokenLock.unlock()
        if autoSendPushToken {
            handleAutoSendPushToken()
        }
        switch deferred {
        case .device(let token)?:
            // With autoSendPushToken the device's token just went: the registrar's weekly claim holds a
            // second one back anyway.
            NotificationRegistrar(sdk: self).registerWithDeviceToken(deviceToken: token)
        case let .direct(token, isFirebase)?:
            setPushTokenNotification(token: token, isFirebaseNotification: isFirebase) { result in
                switch result {
                case .success:
                    self.logger.info(LogCode.pushTokenSent, "the push token was sent")
                case .failure(let error):
                    self.logger.warning(LogCode.pushTokenFailed, "the push token was not sent", ["error": error.logKind])
                }
            }
        case nil:
            break
        }
    }

    /// `release()`: a deferred token is not sent any more.
    private func failDeferredPushToken() {
        pushTokenLock.lock()
        deferredPushToken = nil
        pushTokenLock.unlock()
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
    
    /// The old core sends through a session of this configuration; the new core gives it to its own
    /// client.
    func configureURLSession(configuration: URLSessionConfiguration) {
        guard !usesCoreV2 else {
            core.use(configuration)
            return
        }
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
            switch SearchFilterParams.filtersJSON(filters, method: "getProductsList", shopId: self.shopId) {
            case let .success(json):
                params["filters"] = json
            case let .failure(error):
                completion(.failure(error))
                return
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
            let params: [String: String]
            switch self.categoryParams(limit: limit, page: page, brands: brands, locations: locations, filters: filters, priceMin: priceMin, priceMax: priceMax, sortBy: sortBy, sortDir: sortDir) {
            case let .success(built):
                params = built
            case let .failure(error):
                completion(.failure(error))
                return
            }

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
    ///
    /// What the answer brings — the device id, in storage and here — is taken under `initLock`, and
    /// only while `generation` is the instance's `/init`; the request queue opens with it. `completion`
    /// says whether it was.
    private func sendInitRequest(
        generation: Int,
        completion: @escaping (Result<InitResponse, SdkError>, _ isCurrent: Bool) -> Void
    ) {
        let params = prepareRequestParameters()
        // The operation waits for its own answer: two /init at once (one after deleteUserCredentials)
        // must not wake each other.
        let answered = DispatchSemaphore(value: 0)
        // With a saved answer to stand in, /init does not wait for the network: offline it fails at
        // once and the saved answer takes over. Without one, /init waits for the network, as before.
        let saved = needReInitialization ? nil : savedInitResponse()
        sendGet(
            path: "init",
            params: params,
            timeout: NetworkClient.initTimeout,
            waitsForNetwork: saved == nil
        ) { status, result in
            defer { answered.signal() }
            let outcome: Result<InitResponse, SdkError>
            switch result.flatMap(Self.jsonObject) {
            case let .success(json):
                outcome = .success(InitResponse(json: json))
            case let .failure(error):
                if status == nil, let saved = saved {
                    outcome = .success(saved)
                } else {
                    outcome = .failure(error)
                }
            }
            // The answer to an /init that a later one replaced stores nothing: its device id is the
            // deleted customer's. The queue opens with the current one, whatever it brought.
            let isCurrent = self.ifCurrentInit(generation) {
                if case let .success(response) = outcome {
                    if case .success = result {
                        self.storeSuccessInit(result: response)
                    }
                    self.userInfo = response
                    // Session is client-owned (see SessionManager) — the server-assigned seance is
                    // intentionally not adopted, matching Android/RN. An answer without a device id
                    // keeps the one the shop has: an empty one would go out with every request.
                    if !response.deviceId.isEmpty {
                        self.deviceId = response.deviceId
                    } else if self.deviceId.isEmpty {
                        self.deviceId = self.userIdentity.deviceId ?? ""
                    }
                }
                self.requestQueue.open()
            }
            guard isCurrent else {
                completion(outcome, false)
                return
            }
            switch outcome {
            case .success:
                if case .success = result {
                    self.logger.info(LogCode.initSucceeded, "initialization finished")
                } else {
                    self.logger.warning(LogCode.initSavedAnswer, "no answer to /init: the saved init answer stands in")
                }
            case .failure:
                // A shop that refused (`4xx`) is an error; no answer or a server error is a warning.
                let refused = status.map { (400..<500).contains($0) } ?? false
                self.logger.log(refused ? .error : .warning, LogCode.initFailed, "initialization failed", status.map { ["status": String($0)] } ?? [:])
            }
            completion(outcome, true)
        }
        answered.wait()
    }

    /// The session `/init` comes in. Without one the server starts its "new session" chain on every
    /// `/init`, that is on every launch.
    private static func addSession(_ sessionId: String, to params: inout [String: String]) {
        guard !sessionId.isEmpty else { return }
        params["sid"] = sessionId
        params["seance"] = sessionId
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
            logger.info(LogCode.deviceIdReset, "the stored device id was removed to get a new one", ["reason": "re_initialization"])
        }

        if let deviceId = userIdentity.deviceId, !deviceId.isEmpty {
            params[SdkConstants.did] = deviceId
        }
        Self.addSession(userSeance, to: &params)

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
        guard let data = storage.readSavedInitAnswer() ?? keychainStore.readInitData(),
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
        Self.addSession(userSeance, to: &params)

        let advId = idfa.uuidString
        if advId == "00000000-0000-0000-0000-000000000000" || advId == "" {
            return
        }
        params["ios_advertising_id"] = advId
        userIdentity.advertisingId = advId
        
        // Its answer is saved only while no deleteUserCredentials came after it: a late one would write
        // the deleted customer to the saved answer and the keychain.
        sendGet(path: path, params: params, savesAnswerOf: currentInitGeneration(), timeout: NetworkClient.initTimeout) { _, result in
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
    
    /// Forgets the customer (`sdk/core/storage.md`): the did, the session and its last activity — in
    /// storage and in this instance, and in the places an older SDK kept them (`.standard`, the suite
    /// `storageKey` named in full) — the saved init answer and its keychain backup, `refused`, the
    /// source the app set, the dates the push token last went to the shop, the shop's recent searches,
    /// and on the new core the queue of their events. The device's push token, A/B group and advertising
    /// id stay, and so do the stories state and the migration flags.
    ///
    /// The instance stays registered and sends `/init` again, without a device id: requests made
    /// meanwhile — and the ones already queued — wait for the new one instead of going out without it,
    /// the push token goes to the shop once the new id is stored, and a late answer to the earlier
    /// `/init` changes nothing. After `release()` nothing is wiped or sent.
    public func deleteUserCredentials() {
        guard !isReleased else {
            logger.warning(LogCode.invalidArgument, "deleteUserCredentials on a released instance: nothing was deleted", ["reason": "not_initialized"])
            return
        }
        // The new core's /init first: an answer it is taking lands before the wipe, a later one is
        // stale; calls wait for the new device id from here on.
        let machine = initMachine
        machine?.reset()
        initLock.lock()
        guard !released else {
            initLock.unlock()
            return
        }
        // Before the wipe: an answer to an earlier /init or sendIDFARequest finds itself stale from here
        // on and writes nothing back.
        initGeneration += 1
        let generation = initGeneration
        serverAnswered = false
        if machine == nil {
            // Before the device id is cleared: nothing leaves the queue without one until the new /init.
            requestQueue.close()
            instanceState.set(.initializing)
        }
        userIdentity.clearIdentity()
        deviceId = ""
        storage.removeSavedInitAnswer()
        // The keychain backup too: otherwise the next launch would restore the very did just deleted
        // from its reinstall-surviving copy.
        keychainStore.clear()
        storage.refused = false
        sourceStore.clear()
        NotificationRegistrar.forgetUpload(shopId: shopId)
        // Where an older SDK kept the customer, so neither a downgrade nor a pending shop's push finds it.
        StorageMigrations.forgetCustomer(storageKey: storageKey, partitionName: StoragePartition.suiteName(for: shopId, storageKey: storageKey))
        RecentSearches.forget(shopKey: shopId)
        if usesCoreV2 {
            storage.removeQueueDirectory()
        }
        // The contacts given at creation were the deleted customer's: the next /init does not send
        // them to the profile of the new device id.
        userEmail = nil
        userPhone = nil
        userLoyaltyId = nil
        // The new customer's session.
        userSeance = sessionManager.currentSessionId()
        initLock.unlock()
        logger.info(LogCode.deviceIdReset, "the device id and the saved init answer were deleted", ["reason": "delete_user_credentials"])
        if let machine = machine {
            machine.resume()
        } else {
            startInit(generation: generation, completion: nil)
        }
    }

    /// Stops this instance: it leaves the registry and push routing, its log level stops counting, and
    /// every later call is `notInitialized` — the old methods get `.initializationFailed` — on both
    /// cores; the new core also cancels the requests in flight. An `/init` on its way changes nothing
    /// when it answers, and requests waiting for it go on to fail.
    func release() {
        initLock.lock()
        guard !released else {
            initLock.unlock()
            return
        }
        released = true
        initGeneration += 1
        initLock.unlock()
        SdkRegistry.shared.unregister(self)
        SdkLogger.unregister(owner: self)
        core.release()
        // What waits for a device id runs now, and fails.
        requestQueue.open()
        failDeferredPushToken()
        instanceState.set(.notInitialized)
        // An initialize still waiting for its outcome hears it once.
        initCompletion.finish(.legacy(.notInitialized))
    }

    deinit {
        // Registered, an instance is held by the registry: one that deinits is no longer registered.
        SdkLogger.unregister(owner: self)
        core.release()
    }

    private func makeCore() -> Core {
        guard usesCoreV2 else {
            return LegacyCore(
                baseURL: baseURL,
                stream: stream,
                logger: logger,
                connectivity: connectivity,
                session: { [weak self] in self?.urlSession ?? URLSession.shared },
                // For stories reloaded by hand: without network a request fails at once.
                sessionWithoutWaiting: URLSession(configuration: LegacyCore.sessionConfiguration(waitsForConnectivity: false))
            )
        }
        let client = NetworkClient(baseURL: baseURL, connectivity: connectivity, logger: logger) { [weak self] in
            guard let self = self else {
                return CommonFields(shopId: "", deviceId: "", sessionId: "", stream: "", segment: "")
            }
            return CommonFields(shopId: self.shopId, deviceId: self.deviceId, sessionId: self.userSeance, stream: self.stream, segment: self.segment)
        }
        let machine = InitMachine(
            state: instanceState,
            storage: storage,
            identity: userIdentity,
            keychain: keychainStore,
            logger: logger,
            environment: environment
        ) { request in
            await client.send(request)
        }
        return CoreV2(client: client, machine: machine, label: shopId, logger: logger)
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
                waitsForNetwork: !manualReload
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
    
    func getRequest(path: String, params: [String: String], _ isInit: Bool = false, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        sendGet(path: path, params: params, savesAnswerOf: isInit ? currentInitGeneration() : nil, timeout: nil) { _, result in
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

    /// One GET of `path` with the call's own timeout, through the instance's core. Hands back the
    /// answer's HTTP status — nil when no answer came — and its decoded JSON. With `savesAnswerOf`, an
    /// `/init` that saves its answer: only while that init generation is the instance's, under the lock
    /// `deleteUserCredentials` takes.
    func sendGet(
        path: String,
        params: [String: String],
        savesAnswerOf initGeneration: Int? = nil,
        timeout: TimeInterval?,
        waitsForNetwork: Bool = true,
        forgetsSavedInit: Bool = true,
        completion: @escaping (_ status: Int?, _ result: Result<Any, SdkError>) -> Void
    ) {
        // The old core forgets the saved answer on every request of a forced re-initialization, as it
        // always has; the new one did once, before its /init, and keeps the answer that /init brings.
        if forgetsSavedInit && needReInitialization && !usesCoreV2 {
            removeSavedInitAnswer()
        }
        let request = CoreRequest(method: .get, path: path, query: params, timeout: timeout, waitsForNetwork: waitsForNetwork)
        core.send(request) { response in
            if let generation = initGeneration, case .success = response.result {
                self.ifCurrentInit(generation) {
                    self.saveInitAnswer(response.body)
                }
            }
            completion(response.status, response.result)
        }
    }

    /// A forced re-initialization forgets the saved init answer: it belongs to the device id being
    /// dropped.
    private func removeSavedInitAnswer() {
        storage.removeSavedInitAnswer()
    }

    /// Whether `data` may stand in for `/init` later: a JSON object with a device id. An empty or
    /// unparsable answer never replaces the saved one or its keychain backup.
    static func isSavableInitAnswer(_ data: Data) -> Bool {
        guard !data.isEmpty,
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let deviceId = json["did"] as? String else {
            return false
        }
        return !deviceId.isEmpty
    }

    /// Saves an init answer and its keychain backup, as the old core always has: the file keeps the
    /// first answer, the keychain the last. A file that cannot be written is `storage_failed`: the
    /// answer itself is good, and `/init` goes on with it.
    private func saveInitAnswer(_ data: Data) {
        guard Self.isSavableInitAnswer(data) else { return }
        storage.writeSavedInitAnswerIfAbsent(data)
        keychainStore.writeInitData(data)
    }

    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        postRequest(path: path, params: params, timeout: nil, completion: completion)
    }

    /// `postRequest` with the call's own timeout, through the instance's core.
    func postRequest(path: String, params: [String: Any], timeout: TimeInterval?, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        var requestParams = params
        // A request made before the device id was known waited for /init on the queue; when /init
        // failed, the stored id is the best there is. A did the caller has is kept.
        if self.deviceId == "" {
            let dId = self.userIdentity.deviceId ?? ""
            self.deviceId = dId
            if (requestParams["did"] as? String ?? "").isEmpty {
                requestParams["did"] = dId
            }
        }
        // App data (custom fields, profile properties) may hold values that are not JSON; writing
        // them would raise an exception Swift cannot catch.
        guard SafeJSON.isValid(requestParams) else {
            logger.warning(LogCode.invalidArgument, "the parameters of \(SdkLogger.requestLine("POST", path)) are not valid JSON", ["path": path, "reason": "invalid_json"])
            completion(.failure(.custom(error: "\(path): the request parameters are not valid JSON")))
            return
        }
        core.send(CoreRequest(method: .post, path: path, body: requestParams, timeout: timeout)) { response in
            completion(response.result.flatMap(Self.jsonObject))
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

// MARK: - The new core's /init

extension SimplePersonalizationSDK: InitMachineDelegate {

    /// `/init` of the new core: the time zone, the device id the shop has, the session, the
    /// advertising id only with `sendAdvertisingId`, the test mode of popups v3. `shop_id` and `stream`
    /// come from the client.
    func initQuery() -> [String: String] {
        let hours = TimeZone.current.secondsFromGMT() / 3600
        var params: [String: String] = [SdkConstants.tz: String(hours)]
        if let deviceId = userIdentity.deviceId, !deviceId.isEmpty {
            params[SdkConstants.did] = deviceId
        }
        Self.addSession(userSeance, to: &params)
        if sendAdvertisingId, let advertisingId = userIdentity.advertisingId, !advertisingId.isEmpty,
           advertisingId != "00000000-0000-0000-0000-000000000000" {
            params["ios_advertising_id"] = advertisingId
        }
        if popupsV3.testMode {
            params["testmode"] = "true"
        }
        return params
    }

    func initMachine(adopt response: InitResponse, fromServer: Bool) {
        userInfo = response
        if !response.deviceId.isEmpty {
            deviceId = response.deviceId
        }
    }

    func initMachine(didFinish response: InitResponse, fromServer: Bool) {
        guard fromServer else {
            // The saved answer stands in: its flags, not its popup, nor what goes to the shop.
            popupsV3.initFinished(flag: response.popupsV3)
            return
        }
        // The contacts given at creation and the advertising id go with the first answer for the
        // customer; a later /init (back from the background, a check of the shop) repeats neither.
        let first = takeFirstServerAnswer()
        if first, userEmail != nil || userPhone != nil || userLoyaltyId != nil {
            setProfileData(userEmail: userEmail, userPhone: userPhone, userLoyaltyId: userLoyaltyId) { _ in }
        }
        if let popup = response.popup {
            popupPresenter.presentPopup(popup)
        }
        popupsV3.initFinished(flag: response.popupsV3)
        sendPushTokenIfDeviceIdIsKnown()
        if first, sendAdvertisingId {
            updateAdvertisingIdUseCase.execute { result in
                switch result {
                case .success:
                    self.logger.debug(LogCode.advertisingIdSent, "the advertising id was sent")
                case .failure(let error):
                    self.logger.warning(LogCode.advertisingIdFailed, "the advertising id was not sent", ["error": SdkLogger.errorKind(error)])
                }
            }
        }
    }

    func initMachine(didSettle error: Rees46.SdkError?) {
        initCompletion.finish(error.map { SdkError.legacy($0) })
    }

    /// Whether this is the first server answer since the instance was made or its customer deleted.
    private func takeFirstServerAnswer() -> Bool {
        initLock.lock(); defer { initLock.unlock() }
        let first = !serverAnswered
        serverAnswered = true
        return first
    }
}
