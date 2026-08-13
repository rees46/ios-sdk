//
//  SdkRegistry.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Process-wide registry of `PersonalizationSDK` instances.

 Groundwork for multi-instance (one SDK per `shop_id`). In R1 it is `internal` and carries no public
 surface: it owns the routing state — an ordered fan-out set of live instances plus a "current"
 default pointer — so the single-instance behaviour is unchanged while the plumbing for resolving an
 instance by `shop_id` is in place and tested. The public `Rees46.initialize/instance(for:)/register`
 API is layered on top later (R3), and push routing (R4) resolves the target via `InstanceResolver`
 (live + pending) and fans a refreshed token out over `all()`.

 Mirror of the Android `SdkRegistry`, with one deliberate iOS difference: **references are weak.** On
 Android the SDK is a long-lived process singleton held by the JVM; on iOS the host owns the SDK's
 lifetime (e.g. `AppDelegate` retains it), so the registry must not keep instances alive — otherwise
 they leak and `deinit`-driven unregister (iOS-4) could never fire. An instance the host stops
 retaining deallocs and drops out of the registry automatically; the projections below skip any weak
 slot whose object is already gone.

 Thread-safe: state is read from the messaging threads and written from whatever thread called
 `createPersonalizationSDK`. All mutations run as barriers on a concurrent queue, so a registration
 and a concurrent `onNextRegister` cannot interleave and lose a notification. Callback invocation is
 deliberately kept outside the barrier — a host's `onReady` may run arbitrary code and re-enter the
 registry.
 */
internal final class SdkRegistry {

    static let shared = SdkRegistry()

    private init() {}

    /// Weakly holds one instance so a host-released SDK deallocs and leaves the registry on its own.
    private final class WeakBox {
        weak var value: AnyObject?
        init(_ sdk: PersonalizationSDK) { value = sdk as AnyObject }
        var sdk: PersonalizationSDK? { value as? PersonalizationSDK }
    }

    private final class Awaiter {
        let shopId: String?
        let onReady: (PersonalizationSDK) -> Void
        init(shopId: String?, onReady: @escaping (PersonalizationSDK) -> Void) {
            self.shopId = shopId
            self.onReady = onReady
        }
    }

    private var instances: [WeakBox] = []          // ordered fan-out set (push-token targets)
    private var byShop: [String: WeakBox] = [:]     // shopId -> live instance
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
        var toNotify: [Awaiter] = []
        let object = sdk as AnyObject
        queue.sync(flags: .barrier) {
            compactLocked()
            // Dedup by identity, then append so the newest registration is last in the fan-out order.
            instances.removeAll { $0.value === object }
            instances.append(WeakBox(sdk))
            // A re-init builds a new SDK for the same shop: drop the one it supersedes, or it lingers
            // in the fan-out set forever — still fed push tokens and inflating all()/count().
            if let previous = byShop[shopId]?.value, previous !== object {
                instances.removeAll { $0.value === previous }
            }
            byShop[shopId] = WeakBox(sdk)
            currentDefault = object
            toNotify = takeMatchingAwaitersLocked(shopId: shopId)
        }
        toNotify.forEach { $0.onReady(sdk) }
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
            compactLocked()
            alreadyLive = (shopId != nil) ? byShop[shopId!]?.sdk : (currentDefault as? PersonalizationSDK)
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

        let awaiter = added!
        return Cancellable { [weak self] in
            self?.queue.sync(flags: .barrier) {
                self?.awaiting.removeAll { $0 === awaiter }
            }
        }
    }

    /**
     Drops `sdk` from the fan-out set and the shop mapping. `current` is intentionally left as-is,
     matching the legacy release semantics (it only removed the instance from the fan-out set);
     multi-instance revisits how the default is chosen after a release. Belt-and-suspenders for the
     `deinit` path: a deallocated instance nils its weak slots anyway, this purges them eagerly.
     */
    func unregister(_ sdk: PersonalizationSDK) {
        let object = sdk as AnyObject
        queue.sync(flags: .barrier) {
            instances.removeAll { $0.value == nil || $0.value === object }
            byShop = byShop.filter { $0.value.value != nil && $0.value.value !== object }
        }
    }

    /// Clears all state. Test-only: the registry is a process singleton.
    func reset() {
        queue.sync(flags: .barrier) {
            instances.removeAll()
            byShop.removeAll()
            awaiting.removeAll()
            currentDefault = nil
        }
    }

    // MARK: - Reads (skip weak slots whose object is gone; compaction happens on writes)

    /// Snapshot of every live instance — the push-token fan-out set, in registration order.
    func all() -> [PersonalizationSDK] {
        queue.sync { instances.compactMap { $0.sdk } }
    }

    /// The current default instance, or `nil` when nothing has been registered (or it deallocated).
    func current() -> PersonalizationSDK? {
        queue.sync { currentDefault as? PersonalizationSDK }
    }

    /// Resolves the live instance registered for `shopId`, or `nil` if none — the multi-instance hook.
    func byShopId(_ shopId: String) -> PersonalizationSDK? {
        queue.sync { byShop[shopId]?.sdk }
    }

    /// Shop ids with a live, initialized instance.
    func shopIds() -> Set<String> {
        queue.sync { Set(byShop.compactMap { $0.value.value != nil ? $0.key : nil }) }
    }

    /// Number of live instances currently registered.
    func count() -> Int {
        queue.sync { instances.reduce(0) { $0 + ($1.value != nil ? 1 : 0) } }
    }

    // MARK: - Locked helpers (must run inside the barrier)

    /// Removes weak slots whose object has deallocated. Mutating — barrier-only.
    private func compactLocked() {
        instances.removeAll { $0.value == nil }
        byShop = byShop.filter { $0.value.value != nil }
    }

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
