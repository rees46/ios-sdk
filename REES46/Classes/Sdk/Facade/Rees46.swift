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

    // MARK: - Initialization

    /**
     Initializes an SDK instance for `config` immediately and returns it. The instance is registered,
     so it is also reachable via `instance(for:)`. Any pending registration for the same shop is
     cleared.
     */
    @discardableResult
    public static func initialize(
        _ config: Rees46Config,
        completion: ((SdkError?) -> Void)? = nil
    ) -> PersonalizationSDK {
        let sdk = makeRegisteredSDK(
            shopId: config.shopId,
            apiDomain: config.apiDomain,
            stream: config.stream,
            enableLogs: config.enableLogs,
            autoSendPushToken: config.autoSendPushToken,
            sendAdvertisingId: config.sendAdvertisingId,
            enableAutoPopupPresentation: config.enableAutoPopupPresentation,
            needReInitialization: config.needReInitialization,
            storageKey: config.storageKey,
            completion: completion
        )
        lock.lock()
        pending[config.shopId] = nil
        lock.unlock()
        return sdk
    }

    /**
     Registers `shops` without initializing them. Initialization happens lazily on the first
     `instance(for:)` for a shop — the region case, where only the current region is needed. Pass
     `eagerInit: true` to initialize every shop up front — the super-shop case, where instances must
     stay consistent.
     */
    public static func register(shops: [Rees46Config], eagerInit: Bool = false) {
        for config in shops {
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
        switch InstanceResolver.resolve(
            requestedShopId: shopId,
            liveShopIds: SdkRegistry.shared.shopIds(),
            pendingShopIds: pendingShopIdsSnapshot()
        ) {
        case .existing(let resolved):
            if let sdk = SdkRegistry.shared.byShopId(resolved) {
                onReady(sdk)
            }
            return .noop
        case .pending(let resolved):
            if let sdk = try? materialize(shopId: resolved) {
                onReady(sdk)
            }
            return .noop
        case .ambiguous:
            return .noop
        case .notRegistered:
            return SdkRegistry.shared.onNextRegister(shopId: shopId, onReady: onReady)
        }
    }

    // MARK: - Internals

    /// Initializes a pending registration for `shopId`, tolerating a lost race with another caller.
    /// The config is claimed atomically so two concurrent materializations never double-initialize.
    private static func materialize(shopId: String) throws -> PersonalizationSDK {
        lock.lock()
        let config = pending.removeValue(forKey: shopId)
        lock.unlock()

        if let config = config {
            return initialize(config)
        }
        guard let sdk = SdkRegistry.shared.byShopId(shopId) else {
            throw Rees46Error.unknownShopId(shopId)
        }
        return sdk
    }

    private static func pendingShopIdsSnapshot() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(pending.keys)
    }

    private static func registeredShopIds() -> [String] {
        SdkRegistry.shared.shopIds().union(pendingShopIdsSnapshot()).sorted()
    }

    // MARK: - Test hooks

    /// Test-only: drops pending registrations. Live instances live in `SdkRegistry`.
    internal static func reset() {
        lock.lock()
        pending.removeAll()
        lock.unlock()
    }

    /// Test-only: shops registered lazily and not yet initialized.
    internal static func pendingShopIds() -> Set<String> {
        pendingShopIdsSnapshot()
    }
}
