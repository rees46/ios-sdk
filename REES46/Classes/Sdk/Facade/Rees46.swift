//
//  Rees46.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Public entry point for the SDK — the unified, multi-instance API.

 A host no longer needs to hold its own SDK reference: initialize (or register) shops here and reach
 them by `shopId` through `instance(for:)`. One instance per shop, each with isolated storage and
 state (R2).

 Mirror of the Android `Rees46` facade, adapted to Swift: resolution failures surface as a thrown
 `Rees46Error` (not exceptions), and `awaitInstance` is a non-throwing callback API for UI.

 ```swift
 // Single shop:
 Rees46.initialize(Rees46Config(shopId: "SHOP_ID"))
 try Rees46.instance().track(event: .categoryView(id: "1"))

 // Several shops, initialized lazily on first use:
 Rees46.register(shops: [Rees46Config(shopId: "shop-a"), Rees46Config(shopId: "shop-b")])
 try Rees46.instance(for: "shop-a").track(event: .categoryView(id: "1"))
 ```
 */
public enum Rees46 {

    /// Shops registered lazily and not yet initialized. Materialized on the first `instance(for:)`.
    private static var pending: [String: Rees46Config] = [:]
    /// Guards `pending`. The live instances themselves live in the (thread-safe) `SdkRegistry`.
    private static let lock = NSLock()

    /// Held while an instance is looked up, made and registered: two `initialize` calls for one shop at
    /// once make one instance, and nobody sees a shop between its pending registration and its instance.
    /// Recursive: materializing a pending shop initializes it.
    private static let creationLock = NSRecursiveLock()
    private static var creationDepth = 0
    /// What to tell the shop's waiters (`awaitInstance`) once the outermost holder let go of the lock.
    private static var notifications: [() -> Void] = []

    /// Runs `body` under the creation lock; the closure it hands back runs once the lock is released,
    /// so an app's `onReady` never runs under it.
    static func withCreationLock<T>(_ body: () -> (T, () -> Void)) -> T {
        creationLock.lock()
        creationDepth += 1
        let (value, notify) = body()
        notifications.append(notify)
        creationDepth -= 1
        var ready: [() -> Void] = []
        if creationDepth == 0 {
            ready = notifications
            notifications.removeAll()
        }
        creationLock.unlock()
        ready.forEach { $0() }
        return value
    }

    /// Fires the tracking beacon for a *pending* shop's push without constructing it — see `handlePush`.
    /// Injectable so tests can assert the pending-track path offline; defaults to the real standalone
    /// tracker (`PushDeliveryTracker`).
    internal static var pendingPushTracker: (String, Rees46Config, PushEvent, String, String) -> Void
        = PushDeliveryTracker.track

    // MARK: - Initialization

    /**
     Initializes an SDK instance for `config` immediately and returns it. The instance is registered,
     so it is also reachable via `instance(for:)`. Any pending registration for the same shop is
     cleared.

     A shop that has an instance gets that instance back: no second one is made. A different `config`
     does not change it — the log says `invalid_config` with the reason `already_initialized` — and
     `completion` is still called once: with the outcome of the instance's initialization, or when it
     settles. `release()` lets the next call make a new instance.
     */
    @discardableResult
    public static func initialize(
        _ config: Rees46Config,
        completion: ((REES46.SdkError?) -> Void)? = nil
    ) -> PersonalizationSDK {
        withCreationLock {
            lock.lock()
            pending[config.shopId] = nil
            lock.unlock()
            if let existing = SdkRegistry.shared.byShopId(config.shopId) {
                return (existing, joinExisting(existing, config: config, completion: completion))
            }
            let sdk = SimplePersonalizationSDK(
                shopId: config.shopId,
                apiDomain: config.apiDomain,
                stream: config.stream,
                logLevel: config.logLevel,
                autoSendPushToken: config.autoSendPushToken,
                sendAdvertisingId: config.sendAdvertisingId,
                enableAutoPopupPresentation: config.enableAutoPopupPresentation,
                needReInitialization: config.needReInitialization,
                storageKey: config.storageKey,
                coreV2: config.coreV2,
                deviceId: config.deviceId,
                completion: completion
            )
            sdk.resetSdkCache()
            return (sdk, SdkRegistry.shared.registerDeferringAwaiters(shopId: config.shopId, sdk: sdk))
        }
    }

    /// A repeated `initialize` for a shop that has an instance: what to call once the lock is released.
    private static func joinExisting(
        _ existing: PersonalizationSDK,
        config: Rees46Config,
        completion: ((REES46.SdkError?) -> Void)?
    ) -> () -> Void {
        guard let instance = existing as? SimplePersonalizationSDK else {
            // Another conformer the app registered: it has no outcome to tell.
            return { completion.map { done in DispatchQueue.main.async { done(nil) } } }
        }
        if !instance.config.hasSameSettings(as: config) {
            instance.logger.warning(
                LogCode.invalidConfig,
                "the shop is already initialized: its instance keeps the configuration it was made with",
                ["reason": "already_initialized"]
            )
        }
        return { instance.whenInitialized(completion) }
    }

    /**
     Registers `shops` without initializing them. Initialization happens lazily on the first
     `instance(for:)` for a shop — the region case, where only the current region is needed. Pass
     `eagerInit: true` to initialize every shop up front — the super-shop case, where instances must
     stay consistent.
     */
    public static func register(shops: [Rees46Config], eagerInit: Bool = false) {
        for config in shops {
            // The first registration decides the core of the process, as the first initialization does;
            // a shop that asks for the other one says so when its instance is made, at its log level.
            _ = CoreFlag.resolve(requested: config.coreV2)
            if eagerInit {
                _ = initialize(config)
            } else {
                lock.lock()
                pending[config.shopId] = config
                lock.unlock()
            }
        }
    }

    // MARK: - Resolution

    /**
     Returns the SDK instance for `shopId`, initializing a pending registration on first use. With no
     `shopId`, returns the single instance when exactly one shop is registered.

     - Throws: `Rees46Error.ambiguousShop` when `shopId` is `nil` and more than one shop is registered;
       `Rees46Error.unknownShopId` when the shop is unknown (nothing registered, or no such shop).
     */
    public static func instance(for shopId: String? = nil) throws -> PersonalizationSDK {
        // A live instance is found without the creation lock: another thread building an instance —
        // disk and keychain work — does not hold up a lookup on the main thread.
        if let live = liveInstance(shopId) {
            return live
        }
        let resolved: Result<PersonalizationSDK, Error> = withCreationLock {
            (Result { try resolveLocked(shopId) }, {})
        }
        return try resolved.get()
    }

    /// The registered instance `shopId` resolves to, without the creation lock; `nil` when the shop is
    /// pending, unknown or ambiguous — the creation lock decides those.
    private static func liveInstance(_ shopId: String?) -> PersonalizationSDK? {
        guard case .existing(let resolved) = InstanceResolver.resolve(
            requestedShopId: shopId,
            liveShopIds: SdkRegistry.shared.shopIds(),
            pendingShopIds: pendingShopIdsSnapshot()
        ) else {
            return nil
        }
        return SdkRegistry.shared.byShopId(resolved)
    }

    /// `instance(for:)` under the creation lock: a shop being made is either pending or live.
    private static func resolveLocked(_ shopId: String?) throws -> PersonalizationSDK {
        switch InstanceResolver.resolve(
            requestedShopId: shopId,
            liveShopIds: SdkRegistry.shared.shopIds(),
            pendingShopIds: pendingShopIdsSnapshot()
        ) {
        case .existing(let resolved):
            guard let sdk = SdkRegistry.shared.byShopId(resolved) else {
                throw Rees46Error.unknownShopId(resolved)
            }
            return sdk
        case .pending(let resolved):
            return try materialize(shopId: resolved)
        case .notRegistered:
            throw Rees46Error.unknownShopId(shopId ?? "")
        case .ambiguous:
            throw Rees46Error.ambiguousShop(registeredShopIds())
        }
    }

    /**
     True when an instance is available for `shopId` — or, with no `shopId`, when exactly one shop is
     initialized so the default is unambiguous. A pending (registered-but-not-initialized) shop is not
     counted as initialized.
     */
    public static func isInitialized(shopId: String? = nil) -> Bool {
        if let shopId = shopId {
            return SdkRegistry.shared.byShopId(shopId) != nil
        }
        return SdkRegistry.shared.shopIds().count == 1
    }

    /**
     Delivers the instance for `shopId` to `onReady` as soon as it is available — immediately if it is
     already initialized, otherwise once it registers. A pending registration is initialized on the
     spot. With no `shopId` the single default is used, waiting for the first registration when nothing
     is registered yet.

     Returns a `Cancellable`; call it when the waiter goes away (e.g. a view detaches) so `onReady` is
     not held. Lets a UI element resolve its SDK reactively instead of the host wiring it in.

     iOS divergence from Android (which throws on ambiguity): this is a non-throwing UI callback API,
     so an ambiguous request — no `shopId` while several shops are registered — is **dropped**
     (`onReady` never fires) rather than delivering the wrong shop. Pass an explicit `shopId` to
     disambiguate.
     */
    @discardableResult
    public static func awaitInstance(
        for shopId: String? = nil,
        _ onReady: @escaping (PersonalizationSDK) -> Void
    ) -> Cancellable {
        // A live instance comes at once, without the creation lock.
        if let live = liveInstance(shopId) {
            onReady(live)
            return .noop
        }
        // Otherwise resolved under the creation lock; `onReady` runs once it is released.
        enum Found {
            case instance(PersonalizationSDK)
            case nothing
            case later
        }
        let found: Found = withCreationLock {
            switch InstanceResolver.resolve(
                requestedShopId: shopId,
                liveShopIds: SdkRegistry.shared.shopIds(),
                pendingShopIds: pendingShopIdsSnapshot()
            ) {
            case .existing(let resolved):
                return (SdkRegistry.shared.byShopId(resolved).map(Found.instance) ?? .nothing, {})
            case .pending(let resolved):
                return ((try? materialize(shopId: resolved)).map(Found.instance) ?? .nothing, {})
            case .ambiguous:
                return (.nothing, {})
            case .notRegistered:
                return (.later, {})
            }
        }
        switch found {
        case .instance(let sdk):
            onReady(sdk)
            return .noop
        case .nothing:
            return .noop
        case .later:
            return SdkRegistry.shared.onNextRegister(shopId: shopId, onReady: onReady)
        }
    }

    // MARK: - Logs

    /**
     Hands the app every message the SDK logs at or above each instance's `Rees46Config.logLevel` —
     to forward to Crashlytics or Sentry, say. Messages of all shops come here, on a background
     queue and in order. `nil` removes the handler.

     Messages never carry request data, response bodies, contacts, the push token, push content or
     the `/init` answer.
     */
    public static func setLogHandler(_ handler: ((SdkLogMessage) -> Void)?) {
        SdkLogger.setHandler(handler)
    }

    // MARK: - Push

    /**
     Routes a push to the shop it belongs to and tracks `event` for it. The target is the payload's
     `shop_id`; with no `shop_id` a single-shop app still resolves, but an unknown shop — or an absent
     `shop_id` while several shops are registered — **drops** the push instead of tracking it against the
     wrong one. A payload that is not an SDK push (no resolvable `type`/`code`) is ignored. Call this from
     a host that owns its messaging service.

     Resolution matches `instance(for:)` — it considers LIVE and PENDING shops. A push addressed to a
     registered-but-not-initialized (pending) shop is tracked **without** initializing it: the shop's
     persisted did in its storage partition is all `track/<event>` needs, so a lazily-registered shop's
     push is tracked — not dropped — even when the process was launched cold by that push and only eager
     shops are live (parity with Android's `materializeForPush` and RN's standalone `trackPush`).

     `delivered`/`received`/`clicked` track `track/delivered`/`track/received`/`track/clicked`.
     Navigation stays with the host: unlike the Android singleton, iOS routes click actions through the
     host's own deep-link handling (or the legacy `NotificationService`'s action delegate), so this
     method tracks but does not open the target screen.
     */
    public static func handlePush(_ payload: [AnyHashable: Any], event: PushEvent) {
        let resolution = InstanceResolver.resolve(
            requestedShopId: PushPayloadParser.shopId(from: payload),
            liveShopIds: SdkRegistry.shared.shopIds(),
            pendingShopIds: pendingShopIdsSnapshot()
        )
        // Not an SDK push (no resolvable type/code) — ignore regardless of the target.
        guard let (type, code) = PushPayloadParser.typeAndCode(from: payload) else {
            // Most apps get pushes of other senders too: that is not a problem, so it is `debug`.
            SdkLogger.process.debug(LogCode.pushDropped, "the push is not an SDK push", ["reason": "not_sdk_push"])
            return
        }
        switch resolution {
        case .existing(let shopId):
            guard let sdk = SdkRegistry.shared.byShopId(shopId) else {
                SdkLogger.process.warning(LogCode.pushDropped, "the shop of the push is not registered", ["reason": "unknown_shop"])
                return
            }
            SdkLogger.forShop(shopId).debug(LogCode.pushReceived, "the push went to its shop", ["event": "\(event)"])
            switch event {
            case .delivered:
                sdk.notificationDelivered(type: type, code: code) { _ in }
            case .received:
                sdk.notificationReceived(type: type, code: code) { _ in }
            case .clicked:
                sdk.notificationClicked(type: type, code: code) { _ in }
            }
        case .pending(let shopId):
            // Registered but not initialized: track on its persisted identity, no construction/init —
            // so a lazily-registered shop's push is tracked, not dropped.
            guard let config = pendingConfig(for: shopId) else {
                SdkLogger.process.warning(LogCode.pushDropped, "the shop of the push is not registered", ["reason": "unknown_shop"])
                return
            }
            SdkLogger.forShop(shopId).debug(LogCode.pushReceived, "the push went to its shop", ["event": "\(event)"])
            pendingPushTracker(shopId, config, event, type, code)
        case .notRegistered:
            SdkLogger.process.warning(LogCode.pushDropped, "the shop of the push is not registered", ["reason": "unknown_shop"])
        case .ambiguous:
            // No shop_id while several shops are registered: tracking it would guess the shop.
            SdkLogger.process.warning(LogCode.pushDropped, "the push names no shop and several are registered", ["reason": "ambiguous_shop"])
        }
    }

    // MARK: - Internals

    /// Initializes a pending registration for `shopId`, under the creation lock its caller holds: the
    /// config is claimed and the instance registered before anybody else looks, so two concurrent
    /// materializations never double-initialize and no lookup finds the shop in between.
    private static func materialize(shopId: String) throws -> PersonalizationSDK {
        if let sdk = SdkRegistry.shared.byShopId(shopId) {
            return sdk
        }
        lock.lock()
        let config = pending[shopId]
        lock.unlock()
        guard let config = config else {
            throw Rees46Error.unknownShopId(shopId)
        }
        return initialize(config)
    }

    private static func pendingShopIdsSnapshot() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(pending.keys)
    }

    /// The stored config for a pending shop (its apiDomain/stream/storageKey), needed to track its push
    /// standalone. `nil` if the shop was materialized (or dropped) in the meantime — then the push drops.
    private static func pendingConfig(for shopId: String) -> Rees46Config? {
        lock.lock()
        defer { lock.unlock() }
        return pending[shopId]
    }

    private static func registeredShopIds() -> [String] {
        SdkRegistry.shared.shopIds().union(pendingShopIdsSnapshot()).sorted()
    }

    // MARK: - Test hooks

    /// Test-only: drops pending registrations and restores the real push tracker. Live instances live
    /// in `SdkRegistry`.
    internal static func reset() {
        lock.lock()
        pending.removeAll()
        lock.unlock()
        pendingPushTracker = PushDeliveryTracker.track
    }

    /// Test-only: shops registered lazily and not yet initialized.
    internal static func pendingShopIds() -> Set<String> {
        pendingShopIdsSnapshot()
    }
}

/**
 Fires a push tracking beacon for a shop WITHOUT constructing its SDK. A registered-but-pending shop
 already has its did persisted in its storage partition — all `track/<event>` needs — so a push for a
 lazily-registered shop is tracked even when the process was launched cold by that push and only eager
 shops are live. Standalone counterpart of an instance's `notification{Delivered,Received,Clicked}`;
 mirror of RN's `trackPush`. iOS keeps the shop pending: the beacon needs no live instance.
 */
internal enum PushDeliveryTracker {

    static func track(
        shopId: String,
        config: Rees46Config,
        event: PushEvent,
        type: String,
        code: String
    ) {
        let did = StoragePartition.deviceId(for: shopId, storageKey: config.storageKey)

        let path: String
        switch event {
        case .delivered: path = "track/delivered"
        case .received: path = "track/received"
        case .clicked: path = "track/clicked"
        }

        guard let url = URL(string: "https://" + config.apiDomain + "/" + path) else { return }

        // Same wire shape as SimplePersonalizationSDK.postRequest: a JSON body of stream + params.
        let body: [String: Any] = [
            "stream": config.stream,
            "shop_id": shopId,
            "did": did,
            "code": code,
            "type": type,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = SafeJSON.data(body)

        URLSession.shared.dataTask(with: request).resume()
    }
}
