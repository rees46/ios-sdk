//
//  SdkRegistry.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Process-wide registry of `PersonalizationSDK` instances: an ordered fan-out set of live instances
 (push-token targets) plus a "current" default pointer, with resolution by `shop_id` for the `Rees46`
 facade and push routing (`InstanceResolver` looks at live and pending shops).

 Mirror of the Android `SdkRegistry`. **References are strong** (`sdk/core/README.md`, "Экземпляр"):
 an instance lives while the app holds it or the facade has it registered, so `Rees46.initialize`'s
 instance stays reachable through `Rees46.instance(for:)` even when the app drops what it returned.
 It leaves the registry on `release()`, or when a later `createPersonalizationSDK` for its shop
 replaces it. The current default is weak: it points at a registered instance, and does not keep one
 that a later registration replaced alive.

 Thread-safe: state is read from the messaging threads and written from whatever thread made the
 instance. All mutations run as barriers on a concurrent queue, so a registration and a concurrent
 `onNextRegister` cannot interleave and lose a notification. Callback invocation is deliberately kept
 outside the barrier — a host's `onReady` may run arbitrary code and re-enter the registry.
 */
internal final class SdkRegistry {

    static let shared = SdkRegistry()

    private init() {}

    /// Holds one registered instance.
    private final class Box {
        let value: AnyObject
        let sdk: PersonalizationSDK
        init(_ sdk: PersonalizationSDK) {
            self.sdk = sdk
            value = sdk as AnyObject
        }
    }

    private final class Awaiter {
        let shopId: String?
        let onReady: (PersonalizationSDK) -> Void
        init(shopId: String?, onReady: @escaping (PersonalizationSDK) -> Void) {
            self.shopId = shopId
            self.onReady = onReady
        }
    }

    private var instances: [Box] = []              // ordered fan-out set (push-token targets)
    private var byShop: [String: Box] = [:]         // shopId -> live instance
    private var awaiting: [Awaiter] = []
    private weak var currentDefault: AnyObject?     // the current default (last registered)

    /// Serialises the compound routing-state updates; reads run concurrently, writes as barriers.
    private let queue = DispatchQueue(label: "com.rees46.sdkRegistry", attributes: .concurrent)

    // MARK: - Mutations

    /**
     Records an initialized `sdk` for `shopId`: it joins the push fan-out set and becomes the current
     default. Re-registering the same instance keeps a single entry; a new instance for an
     already-known `shopId` replaces the mapping (last writer wins) and evicts the superseded instance
     from the fan-out set, so a re-init does not leave the old object receiving push tokens.
     */
    func register(shopId: String, sdk: PersonalizationSDK) {
        registerDeferringAwaiters(shopId: shopId, sdk: sdk)()
    }

    /// `register`, with the waiters of the shop handed back instead of called: the facade registers
    /// under its lock and calls them once it let go of it, so an app's `onReady` never runs under it.
    func registerDeferringAwaiters(shopId: String, sdk: PersonalizationSDK) -> () -> Void {
        var toNotify: [Awaiter] = []
        // What the registry lets go of is released after the barrier: an instance's deinit may come back.
        var dropped: [Box] = []
        let object = sdk as AnyObject
        queue.sync(flags: .barrier) {
            // Dedup by identity, then append so the newest registration is last in the fan-out order.
            dropped += instances.filter { $0.value === object }
            instances.removeAll { $0.value === object }
            instances.append(Box(sdk))
            // A re-init builds a new SDK for the same shop: drop the one it supersedes, or it lingers
            // in the fan-out set forever — still fed push tokens and inflating all()/count().
            if let previous = byShop[shopId]?.value, previous !== object {
                dropped += instances.filter { $0.value === previous }
                instances.removeAll { $0.value === previous }
            }
            if let replaced = byShop[shopId] {
                dropped.append(replaced)
            }
            byShop[shopId] = Box(sdk)
            currentDefault = object
            toNotify = takeMatchingAwaitersLocked(shopId: shopId)
        }
        withExtendedLifetime(dropped) {}
        return { toNotify.forEach { $0.onReady(sdk) } }
    }

    /**
     Subscribes to the next `register` matching `shopId` (`nil` matches the first registration of any
     shop). Re-checks the live state under the barrier first: if the instance already arrived it fires
     `onReady` immediately instead of waiting for a signal that has already passed. Returns a handle
     that removes the subscription; call it when the waiter goes away (e.g. a view detaches) so the
     callback is not leaked.
     */
    @discardableResult
    func onNextRegister(shopId: String?, onReady: @escaping (PersonalizationSDK) -> Void) -> Cancellable {
        var alreadyLive: PersonalizationSDK?
        var added: Awaiter?
        queue.sync(flags: .barrier) {
            if let shopId = shopId {
                alreadyLive = byShop[shopId]?.sdk
            } else {
                alreadyLive = currentDefault as? PersonalizationSDK
            }
            if alreadyLive == nil {
                let awaiter = Awaiter(shopId: shopId, onReady: onReady)
                awaiting.append(awaiter)
                added = awaiter
            }
        }

        if let live = alreadyLive {
            onReady(live)
            return Cancellable.noop
        }

        guard let awaiter = added else { return Cancellable.noop }
        return Cancellable { [weak self] in
            self?.queue.sync(flags: .barrier) {
                self?.awaiting.removeAll { $0 === awaiter }
            }
        }
    }

    /**
     Drops `sdk` from the fan-out set and the shop mapping (`release()`). When it was the current
     default, the default becomes the last instance registered before it, if any: a released instance is
     never handed out again.
     */
    func unregister(_ sdk: PersonalizationSDK) {
        let object = sdk as AnyObject
        var dropped: [Box] = []
        queue.sync(flags: .barrier) {
            dropped = instances.filter { $0.value === object } + byShop.values.filter { $0.value === object }
            instances.removeAll { $0.value === object }
            byShop = byShop.filter { $0.value.value !== object }
            if currentDefault === object {
                currentDefault = instances.last?.value
            }
        }
        // Released here, after the barrier: the instance's deinit may come back to the registry.
        withExtendedLifetime(dropped) {}
    }

    /// Clears all state. Test-only: the registry is a process singleton.
    func reset() {
        var dropped: ([Box], [String: Box]) = ([], [:])
        queue.sync(flags: .barrier) {
            dropped = (instances, byShop)
            instances.removeAll()
            byShop.removeAll()
            awaiting.removeAll()
            currentDefault = nil
        }
        // Released here, after the barrier: an instance's deinit may come back to the registry.
        withExtendedLifetime(dropped) {}
    }

    // MARK: - Reads

    /// Snapshot of every live instance — the push-token fan-out set, in registration order.
    func all() -> [PersonalizationSDK] {
        queue.sync { instances.map(\.sdk) }
    }

    /// The current default instance, or `nil` when nothing has been registered (or it was released
    /// and deallocated).
    func current() -> PersonalizationSDK? {
        queue.sync { currentDefault as? PersonalizationSDK }
    }

    /// Resolves the live instance registered for `shopId`, or `nil` if none — the multi-instance hook.
    func byShopId(_ shopId: String) -> PersonalizationSDK? {
        queue.sync { byShop[shopId]?.sdk }
    }

    /// Shop ids with a live, initialized instance.
    func shopIds() -> Set<String> {
        queue.sync { Set(byShop.keys) }
    }

    /// Number of live instances currently registered.
    func count() -> Int {
        queue.sync { instances.count }
    }

    // MARK: - Locked helpers (must run inside the barrier)

    /// Removes and returns the awaiters matching `shopId` (`nil`-shop awaiters match any). Barrier-only.
    private func takeMatchingAwaitersLocked(shopId: String) -> [Awaiter] {
        guard !awaiting.isEmpty else { return [] }
        let matched = awaiting.filter { $0.shopId == nil || $0.shopId == shopId }
        if !matched.isEmpty {
            awaiting.removeAll { candidate in matched.contains { $0 === candidate } }
        }
        return matched
    }
}
