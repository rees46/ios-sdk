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

    /// Sends the event of a *pending* shop's push on the old core without constructing it — see
    /// `handlePush`. Injectable so tests can assert the pending path offline; defaults to the real
    /// standalone tracker (`PushDeliveryTracker`). The new core goes through the shop's queue on disk
    /// (`PendingPushEvents`).
    internal static var pendingPushTracker: (PendingPush) -> Void = PushDeliveryTracker.track

    // MARK: - Initialization

    /**
     Initializes an SDK instance for `config` immediately and returns it. The instance is registered,
     so it is also reachable via `instance(for:)`. Any pending registration for the same shop is
     cleared.

     A shop that has an instance gets that instance back: no second one is made. A different `config`
     does not change it — the log says `invalid_config` with the reason `already_initialized` — and
     `completion` is still called once: with the outcome of the instance's initialization, or when it
     settles. `release()` lets the next call make a new instance. Without `Rees46Config.coreV2`, as it
     always has, a call after the instance's `/init` failed, or with `needReInitialization`, makes a new
     instance of the shop with a new `/init`.
     */
    @discardableResult
    public static func initialize(
        _ config: Rees46Config,
        completion: ((LegacySdkError?) -> Void)? = nil
    ) -> PersonalizationSDK {
        withCreationLock {
            lock.lock()
            pending[config.shopId] = nil
            lock.unlock()
            if let existing = SdkRegistry.shared.byShopId(config.shopId), !makesNewLegacyInstance(over: existing, config: config) {
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

    /// Whether a repeated `initialize` makes a new instance of the shop on the old core, as it always
    /// has there: the old core does not repeat a failed `/init` itself, so the app's next `initialize`
    /// sends a new one; and `needReInitialization` asks for a new device id. The new instance replaces
    /// the shop's registration; the old one goes on for whoever holds it, as before.
    private static func makesNewLegacyInstance(over existing: PersonalizationSDK, config: Rees46Config) -> Bool {
        guard let instance = existing as? SimplePersonalizationSDK, !instance.usesCoreV2 else { return false }
        return config.needReInitialization || instance.initCompletion.failed
    }

    /// A repeated `initialize` for a shop that has an instance: what to call once the lock is released.
    private static func joinExisting(
        _ existing: PersonalizationSDK,
        config: Rees46Config,
        completion: ((LegacySdkError?) -> Void)?
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
     Routes a push to the shop it belongs to and sends `event` for it (`sdk/contract/notifications.md`).
     Returns the shop the push went to, or `nil` when it is not a push of the SDK — no `type` and `code`
     — or no shop takes it: an app with its own messaging service handles such a push itself. Never
     throws.

     The shop is the payload's `shop_id`; with no `shop_id` a single registered shop takes it, while an
     unknown shop — or no `shop_id` with several shops — **drops** the push (`push_dropped`) instead of
     counting it to another shop. `type` and `code` are the top-level `type` and `id` of FCM, or
     `src.type` and `src.id` of APNs.

     - With `Rees46Config.coreV2`, each event goes once per message in the process — a repeat sends
       nothing and calls no callback —, through the shop's queue: `track/delivered`, `track/opened`,
       `track/clicked`, `track/closed`. A click stores the push as the source of the shop's `/push`
       events for 48 hours.
     - Without it the events go at once, as they always have — `delivered` and `clicked`; `opened` and
       `closed`, which that core never had, send nothing there and only call the callbacks.

     A shop that is registered but not created (`register` without `eagerInit`, the app launched by the
     push) is not created: the event goes with the device id the shop has stored, without `/init` — and
     on the new core not at all without one. The app's callback of the event is called on the main
     thread: the shop instance's own (`setPushCallbacks` of the bridges' API), else the one of
     `setPushCallbacks(_:)`.

     What the SDK sees itself on iOS comes through `NotificationService.didReceiveRemoteNotifications`:
     a push that arrives (`delivered`), one that arrives in the active app (`opened`), one whose tap
     brings the app back (`clicked`). The SDK owns no `UNUserNotificationCenter` delegate: the app or the
     bridge that is the delegate calls this method itself — `clicked` for the taps it handles in
     `userNotificationCenter(_:didReceive:withCompletionHandler:)`, and `closed` for
     `UNNotificationDismissActionIdentifier`, which the system reports only for a category with
     `.customDismissAction`; the SDK's carousel category has none.

     Navigation stays with the app: open `PushPayload.target` in `onClicked`.
     */
    @discardableResult
    public static func handlePush(_ payload: [AnyHashable: Any], event: Rees46.PushEvent) -> String? {
        route(payload, .event(event))
    }

    /**
     The push events of earlier versions; `handlePush(_:event:)` with `Rees46.PushEvent` replaces it.
     `delivered` and `clicked` are the same events there. `received` — a push that came while the app
     was in the background, which the server counts as one more open — is `delivered` with
     `Rees46Config.coreV2`, sent once with the `delivered` of the same push; without it,
     `track/received` as before.
     */
    @_disfavoredOverload
    public static func handlePush(_ payload: [AnyHashable: Any], event: LegacyPushEvent) {
        route(payload, PushRoute(event))
    }

    /**
     Sets the app's callbacks on pushes for every shop — also one registered but not created yet, whose
     push may come before the app could set the callbacks of its instance. A callback gets the parsed
     push (`PushPayload`, with the shop it went to) on the main thread; `onToken` gets each token the
     SDK gets from APNs or FCM. An instance's own callbacks win over these, one by one. `nil` removes
     them.
     */
    public static func setPushCallbacks(_ callbacks: Rees46.PushCallbacks?) {
        PushCenter.callbacks = callbacks
    }

    /// The new core got the device's token from APNs or FCM through `sdk`'s `NotificationService`: it
    /// becomes the device's token, and every instance of the process sends it to its shop by that shop's
    /// week (`sdk/core/push.md`).
    static func deviceTokenReceived(_ token: Rees46.PushToken, apnsData: Data?, through sdk: PersonalizationSDK) {
        var instances = SdkRegistry.shared.shopIds().compactMap { SdkRegistry.shared.byShopId($0) as? SimplePersonalizationSDK }
        if let own = sdk as? SimplePersonalizationSDK, !instances.contains(where: { $0 === own }) {
            instances.append(own)
        }
        for instance in instances where instance.usesCoreV2 {
            instance.submitPushToken(token, apnsData: apnsData, completion: nil)
        }
    }

    /// Sends `route` of `payload` to its shop; the shop, or `nil` when the push was not taken.
    @discardableResult
    static func route(_ payload: [AnyHashable: Any], _ route: PushRoute) -> String? {
        // Not an SDK push (no resolvable type/code) — ignore regardless of the target.
        guard let (type, code) = PushPayloadParser.typeAndCode(from: payload) else {
            // Most apps get pushes of other senders too: that is not a problem, so it is `debug`.
            SdkLogger.process.debug(LogCode.pushDropped, "the push is not an SDK push", ["reason": "not_sdk_push"])
            return nil
        }
        let requested = PushPayloadParser.shopId(from: payload)
        // The shop is looked up again when it changed between the lookups — made from its pending
        // registration meanwhile —: a push never drops for a shop that has an instance or a registration.
        for _ in 0..<maxLookups {
            // The live instances are read once: one the resolution names is in hand, and a `release()`
            // after this reroutes the push (`rerouteReleased`) instead of losing it.
            let live = SdkRegistry.shared.liveByShop()
            let resolution = InstanceResolver.resolve(
                requestedShopId: requested,
                liveShopIds: Set(live.keys),
                pendingShopIds: pendingShopIdsSnapshot()
            )
            resolutionObserver?(resolution)
            switch resolution {
            case .existing(let shopId):
                guard let sdk = live[shopId] else { continue }
                SdkLogger.forShop(shopId).debug(LogCode.pushReceived, "the push went to its shop", ["event": route.name])
                deliver(route, type: type, code: code, payload: payload, to: sdk, shopId: shopId)
                return shopId
            case .pending(let shopId):
                // Registered but not initialized: sent on its stored identity, without making it.
                guard let config = pendingConfig(for: shopId) else { continue }
                routeToPending(shopId: shopId, config: config, route: route, type: type, code: code, payload: payload)
                return shopId
            case .notRegistered:
                SdkLogger.process.warning(LogCode.pushDropped, "the shop of the push is not registered", ["reason": "unknown_shop"])
                return nil
            case .ambiguous:
                // No shop_id while several shops are registered: tracking it would guess the shop.
                SdkLogger.process.warning(LogCode.pushDropped, "the push names no shop and several are registered", ["reason": "ambiguous_shop"])
                return nil
            }
        }
        SdkLogger.process.warning(LogCode.pushDropped, "the shop of the push is not registered", ["reason": "unknown_shop"])
        return nil
    }

    /// How many times `route` looks the shop up while it changes between the lookups.
    static let maxLookups = 3

    private static let observerLock = NSLock()
    private static var resolutionObserverValue: ((InstanceResolution) -> Void)?

    /// Test-only seam: hears each resolution of a push's shop before the shop is looked up, so a test
    /// can release or make the shop's instance in between. The SDK sets none.
    static var resolutionObserver: ((InstanceResolution) -> Void)? {
        get { observerLock.lock(); defer { observerLock.unlock() }; return resolutionObserverValue }
        set { observerLock.lock(); resolutionObserverValue = newValue; observerLock.unlock() }
    }

    /// How many times a push follows a shop's instances released one after another before it goes on
    /// the shop's stored identity instead.
    static let maxReroutes = 3

    /// Hands `route` to `sdk`, the live instance of `shopId`. One the app made itself gets the events
    /// its protocol has; an instance of the SDK that was released meanwhile takes nothing, and the push
    /// goes on (`rerouteReleased`).
    static func deliver(
        _ route: PushRoute,
        type: String,
        code: String,
        payload: [AnyHashable: Any],
        to sdk: PersonalizationSDK,
        shopId: String,
        hops: Int = 0
    ) {
        if let instance = sdk as? SimplePersonalizationSDK {
            instance.receivePush(route, type: type, code: code, payload: payload) {
                rerouteReleased(from: instance, route: route, type: type, code: code, payload: payload, hops: hops + 1)
            }
            return
        }
        // An instance of the app's own: the events its protocol has.
        switch route {
        case .event(.delivered):
            sdk.notificationDelivered(type: type, code: code) { _ in }
        case .event(.clicked):
            sdk.notificationClicked(type: type, code: code) { _ in }
        case .received:
            sdk.notificationReceived(type: type, code: code) { _ in }
        case .event(.opened), .event(.closed):
            // Events the old protocol never had: nothing goes.
            break
        }
        if case .event(let event) = route, let parsed = Rees46.PushPayload.parse(payload, shopId: shopId) {
            PushCenter.notify(event, payload: parsed, instance: nil)
        }
    }

    /// A push the instance it was routed to did not take: `release()` came first — the app replaces the
    /// instance, say. It goes to the shop's live instance now, or, with none, on the device id the shop
    /// has stored, as a pending shop's push does — no instance is made for it. The released instance
    /// sent and counted nothing, so the event goes once.
    private static func rerouteReleased(
        from released: SimplePersonalizationSDK,
        route: PushRoute,
        type: String,
        code: String,
        payload: [AnyHashable: Any],
        hops: Int
    ) {
        let shopId = released.shopId
        let logger = SdkLogger.forShop(shopId)
        if hops <= maxReroutes, let live = SdkRegistry.shared.byShopId(shopId), (live as AnyObject) !== released {
            logger.debug(LogCode.pushReceived, "the push went to the shop's new instance", ["event": route.name, "rerouted": "true"])
            deliver(route, type: type, code: code, payload: payload, to: live, shopId: shopId, hops: hops)
            return
        }
        routeToPending(shopId: shopId, config: pendingConfig(for: shopId) ?? released.config, route: route, type: type, code: code, payload: payload)
    }

    /// A push of a shop that is registered and not created: the event goes with the device id the shop
    /// has stored, without `/init`, a token, a profile or a popup, and the facade's callback is called.
    /// Initialized later, the shop gets an instance with a full start.
    ///
    /// - The new core writes the event into the shop's queue on disk and sends it at once under a
    ///   background task (`PendingPushEvents`); one that cannot go now — offline at a cold start — stays
    ///   there for the shop's instance. The device id is the shop's from wherever its instance would take
    ///   it without `/init` (`PendingPushEvents.deviceId`); nothing goes without one (`push_dropped`,
    ///   `no_did`) — the server sent this device no push of the shop — or for a shop that refused the
    ///   SDK (`queue_dropped`, `refused`). Each event goes once per message, counted and heard by the
    ///   callback once it is on disk; `received` goes as `delivered`, a click stores the source in the
    ///   shop's partition.
    /// - The old core sends exactly what it always has: the event at once, with the stored device id or
    ///   an empty one; `opened` and `closed`, which it never had, send nothing.
    private static func routeToPending(
        shopId: String,
        config: Rees46Config,
        route: PushRoute,
        type: String,
        code: String,
        payload: [AnyHashable: Any]
    ) {
        let logger = SdkLogger.forShop(shopId)
        let newCore = CoreFlag.current ?? config.coreV2
        let sent = newCore ? PushRoute.event(route.newCoreEvent) : route
        guard newCore else {
            let deviceId = StoragePartition.deviceId(for: shopId, storageKey: config.storageKey)
            logger.debug(LogCode.pushReceived, "the push went to its shop", ["event": sent.name])
            if sent != .event(.opened), sent != .event(.closed) {
                pendingPushTracker(PendingPush(shopId: shopId, config: config, route: sent, type: type, code: code, deviceId: deviceId))
            }
            if case .event(let event) = sent, let parsed = Rees46.PushPayload.parse(payload, shopId: shopId) {
                PushCenter.notify(event, payload: parsed, instance: nil)
            }
            return
        }
        let storage = ShopStorage(shopId: shopId, storageKey: config.storageKey, logger: logger)
        let event = route.newCoreEvent
        guard !storage.refused else {
            logger.warning(
                LogCode.queueDropped,
                "an event of \(SdkLogger.requestLine("POST", event.path)) was dropped: the shop refused the SDK",
                ["reason": "refused", "path": event.path]
            )
            return
        }
        guard PushCenter.reserve(event, code: code, shopId: shopId) else {
            logger.debug(LogCode.pushReceived, "the push event was handled already in this launch", ["event": sent.name, "repeat": "true"])
            return
        }
        logger.debug(LogCode.pushReceived, "the push went to its shop", ["event": sent.name])
        let parsed = Rees46.PushPayload.parse(payload, shopId: shopId)
        let push = PendingPush(shopId: shopId, config: config, route: sent, type: type, code: code, deviceId: "")
        PendingPushEvents.take(push, event: event, storage: storage, logger: logger) { accepted in
            guard accepted else {
                PushCenter.release(event, code: code, shopId: shopId)
                return
            }
            PushCenter.confirm(event, code: code, shopId: shopId)
            if let parsed = parsed {
                PushCenter.notify(event, payload: parsed, instance: nil)
            }
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

    /// Test-only: drops pending registrations, the push callbacks and the events sent, and restores the
    /// real push tracker. Live instances live in `SdkRegistry`.
    internal static func reset() {
        lock.lock()
        pending.removeAll()
        lock.unlock()
        pendingPushTracker = PushDeliveryTracker.track
        resolutionObserver = nil
        PendingPushEvents.reset()
        PushCenter.reset()
        PushTokenWeek.reset()
    }

    /// Test-only: shops registered lazily and not yet initialized.
    internal static func pendingShopIds() -> Set<String> {
        pendingShopIdsSnapshot()
    }
}

/// The event of a pending shop's push, as `handlePush` hands it on.
struct PendingPush {
    let shopId: String
    let config: Rees46Config
    /// What is sent: with the new core, one of its events — never `received`.
    let route: PushRoute
    let type: String
    let code: String
    /// The device id the shop has stored; on the old core empty when the shop has none, as it has
    /// always gone. The new core finds the shop's when it sends (`PendingPushEvents.deviceId`).
    let deviceId: String
}

/**
 Sends the event of a push for a shop WITHOUT constructing its SDK, on the old core. A
 registered-but-pending shop already has its did persisted in its storage partition — all
 `track/<event>` needs — so a push for a lazily-registered shop is tracked even when the process was
 launched cold by that push and only eager shops are live. Standalone counterpart of an instance's push
 events; mirror of RN's `trackPush`. iOS keeps the shop pending: the request needs no live instance.
 */
internal enum PushDeliveryTracker {

    static func track(_ push: PendingPush) {
        let path: String
        switch push.route {
        case .event(let event): path = event.path
        case .received: path = "track/received"
        }

        guard let url = URL(string: "https://" + push.config.apiDomain + "/" + path) else { return }

        // Same wire shape as SimplePersonalizationSDK.postRequest: a JSON body of stream + params.
        let body: [String: Any] = [
            "stream": push.config.stream,
            "shop_id": push.shopId,
            "did": push.deviceId,
            "code": push.code,
            "type": push.type,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpShouldHandleCookies = false
        request.httpBody = SafeJSON.data(body)

        SdkURLSession.shared.dataTask(with: request).resume()
    }
}
