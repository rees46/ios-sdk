//
//  PushCenter.swift
//  REES46
//
//  What the process keeps about pushes (`sdk/core/push.md`, `sdk/contract/notifications.md`): the
//  facade's callbacks, the events already sent, and the week of each shop's push token.
//

import Foundation

/// What `Rees46.handlePush` routes: the contract's events, and the old `received`, which only the old
/// core sends — the new one sends `delivered` for it (decision 0004).
enum PushRoute: Equatable {
    case event(Rees46.PushEvent)
    case received

    init(_ old: PushEvent) {
        switch old {
        case .delivered: self = .event(.delivered)
        case .received: self = .received
        case .clicked: self = .event(.clicked)
        }
    }

    /// The event the new core sends for it.
    var newCoreEvent: Rees46.PushEvent {
        switch self {
        case .event(let event): return event
        case .received: return .delivered
        }
    }

    /// The name in the log.
    var name: String {
        switch self {
        case .event(let event): return event.rawValue
        case .received: return "received"
        }
    }
}

/// The facade's push callbacks, the bridges' listeners and the events of the process.
enum PushCenter {

    private static let lock = NSLock()
    private static var facadeCallbacks: Rees46.PushCallbacks?
    /// The events of this process a queue accepted: shop, event and message.
    private static var sent: Set<String> = []
    /// The events being handed to a queue now: a second one waits for nothing and sends nothing.
    private static var reserved: Set<String> = []
    /// The tokens told in this process: provider and token.
    private static var tokens: Set<String> = []
    private static var eventListeners: [UUID: (Rees46.PushEvent, Rees46.PushPayload) -> Void] = [:]
    private static var tokenListeners: [UUID: (Rees46.PushToken) -> Void] = [:]

    /// `Rees46.setPushCallbacks`: the callbacks of every shop, pending ones included.
    static var callbacks: Rees46.PushCallbacks? {
        get { lock.lock(); defer { lock.unlock() }; return facadeCallbacks }
        set { lock.lock(); facadeCallbacks = newValue; lock.unlock() }
    }

    /// Whether `event` of the message `code` may go to `shopId` now: once per process
    /// (`sdk/contract/notifications.md`). `false` for a repeat — a tap seen twice, a `delivered` after
    /// the old `received` — of an event a queue accepted, or one being handed to a queue right now. The
    /// event counts as sent only once its queue accepted it (`confirm`); one the queue did not take is
    /// `release`d and may go when it comes again.
    static func reserve(_ event: Rees46.PushEvent, code: String, shopId: String) -> Bool {
        let key = self.key(event, code: code, shopId: shopId)
        lock.lock(); defer { lock.unlock() }
        guard !sent.contains(key) else { return false }
        return reserved.insert(key).inserted
    }

    /// The queue accepted the event of `reserve`: a repeat sends nothing from now on.
    static func confirm(_ event: Rees46.PushEvent, code: String, shopId: String) {
        let key = self.key(event, code: code, shopId: shopId)
        lock.lock(); defer { lock.unlock() }
        reserved.remove(key)
        sent.insert(key)
    }

    /// The queue did not take the event of `reserve` — a released instance, a refused shop, a disk
    /// that failed: it may go when it comes again.
    static func release(_ event: Rees46.PushEvent, code: String, shopId: String) {
        let key = self.key(event, code: code, shopId: shopId)
        lock.lock(); defer { lock.unlock() }
        reserved.remove(key)
    }

    /// Whether `event` of the message is sent or being handed to a queue; for tests.
    static func isTaken(_ event: Rees46.PushEvent, code: String, shopId: String) -> Bool {
        let key = self.key(event, code: code, shopId: shopId)
        lock.lock(); defer { lock.unlock() }
        return sent.contains(key) || reserved.contains(key)
    }

    private static func key(_ event: Rees46.PushEvent, code: String, shopId: String) -> String {
        "\(shopId)\u{1F}\(event.rawValue)\u{1F}\(code)"
    }

    /// Calls the app's callback of `event` on the main thread — the instance's own when it set one, the
    /// facade's otherwise — and the bridges' listeners.
    static func notify(_ event: Rees46.PushEvent, payload: Rees46.PushPayload, instance: Rees46.PushCallbacks?) {
        let callback = instance?.callback(for: event) ?? callbacks?.callback(for: event)
        lock.lock()
        let listeners = Array(eventListeners.values)
        lock.unlock()
        guard callback != nil || !listeners.isEmpty else { return }
        DispatchQueue.main.async {
            callback?(payload)
            listeners.forEach { $0(event, payload) }
        }
    }

    /// The SDK got `token` from APNs or FCM: the app's `onToken` — the instance's own when it set one,
    /// the facade's otherwise — and the bridges' listeners hear it on the main thread, once per token
    /// and provider in the process.
    static func notify(_ token: Rees46.PushToken, instance: Rees46.PushCallbacks?) {
        lock.lock()
        let new = tokens.insert(token.provider.rawValue + ":" + token.token).inserted
        let listeners = Array(tokenListeners.values)
        lock.unlock()
        guard new else { return }
        let callback = instance?.onToken ?? callbacks?.onToken
        guard callback != nil || !listeners.isEmpty else { return }
        DispatchQueue.main.async {
            callback?(token)
            listeners.forEach { $0(token) }
        }
    }

    /// `Rees46.onPushEvent`.
    static func addEventListener(_ listener: @escaping (Rees46.PushEvent, Rees46.PushPayload) -> Void) -> Cancellable {
        let id = UUID()
        lock.lock()
        eventListeners[id] = listener
        lock.unlock()
        return Cancellable {
            lock.lock()
            eventListeners[id] = nil
            lock.unlock()
        }
    }

    /// `Rees46.onPushToken`: the device's token the SDK has already goes to the new listener at once.
    static func addTokenListener(_ listener: @escaping (Rees46.PushToken) -> Void, current: Rees46.PushToken?) -> Cancellable {
        let id = UUID()
        lock.lock()
        tokenListeners[id] = listener
        lock.unlock()
        if let current = current {
            DispatchQueue.main.async { listener(current) }
        }
        return Cancellable {
            lock.lock()
            tokenListeners[id] = nil
            lock.unlock()
        }
    }

    /// Test-only: no callbacks, no listeners, no events or tokens told.
    static func reset() {
        lock.lock()
        facadeCallbacks = nil
        sent.removeAll()
        reserved.removeAll()
        tokens.removeAll()
        eventListeners.removeAll()
        tokenListeners.removeAll()
        lock.unlock()
    }
}

/// An instance's own push callbacks, under a lock.
final class PushCallbackBox {
    private let lock = NSLock()
    private var value: Rees46.PushCallbacks?

    var callbacks: Rees46.PushCallbacks? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

/// The week of a shop's push token in the new core (`sdk/core/push.md`): the same token goes to a shop
/// at most once a week, a new one at once. The week is claimed before the request — two sends at once
/// go as one — and given back when the request fails.
enum PushTokenWeek {

    static let length: TimeInterval = 7 * 24 * 60 * 60

    /// A week claimed for a token on its way, and what was there before it.
    struct Claim {
        let storage: ShopStorage
        let sent: ShopStorage.PushTokenSent
        let previous: ShopStorage.PushTokenSent?
    }

    private static let lock = NSLock()

    /// What identifies a token for a shop: the server keeps the platform with it.
    static func key(_ token: String, platform: String) -> String {
        platform + ":" + token
    }

    /// Claims the week of `token` for the shop of `storage`; `nil` when it went there within the week.
    static func claim(_ token: String, platform: String, storage: ShopStorage, now: Date) -> Claim? {
        lock.lock(); defer { lock.unlock() }
        let tokenKey = key(token, platform: platform)
        let previous = storage.pushTokenSent
        if let previous = previous, previous.key == tokenKey {
            let age = now.timeIntervalSince(previous.at)
            // A date ahead of the clock — the clock moved back — does not hold the token for good.
            if age >= 0, age < length {
                return nil
            }
        }
        let sent = ShopStorage.PushTokenSent(key: tokenKey, at: now)
        storage.pushTokenSent = sent
        return Claim(storage: storage, sent: sent, previous: previous)
    }

    /// The request of `claim` failed: the shop's record goes back, unless something replaced it since.
    static func release(_ claim: Claim) {
        lock.lock(); defer { lock.unlock() }
        guard claim.storage.pushTokenSent == claim.sent else { return }
        claim.storage.pushTokenSent = claim.previous
    }
}
