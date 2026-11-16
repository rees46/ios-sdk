//
//  DeviceStore.swift
//  REES46
//
//  What the SDK keeps for the device rather than for a shop (`sdk/core/storage.md`).
//

import Foundation

/// The device's data, shared by every shop of the app: the push token, the A/B group and the
/// advertising id. `deleteUserCredentials()` keeps them: they are about the device, not about the
/// customer.
///
/// The A/B group and the advertising id used to live in each shop's partition, the push token in
/// `UserDefaults.standard`; those keys go on being written (`UserIdentityRepositoryImpl`, `pushToken`),
/// so `LegacyCore` and older SDK versions read exactly what they read before.
final class DeviceStore {

    /// A suite of its own. The dot keeps it apart from every shop's partition: a partition's name is
    /// a prefix and a shop id with only letters, digits, `_` and `-`.
    static let suiteName = "personalization_sdk.device"

    static let abGroupKey = "ab_group"
    static let advertisingIdKey = "advertising_id"
    static let pushTokenKey = "push_token"
    /// The new core's token of the device: the last one of any provider, as a string, and its
    /// provider; each provider's own under the key with its name after a dot.
    static let deviceTokenKey = "push_token_value"
    static let deviceTokenProviderKey = "push_token_provider"
    /// The A/B groups the server knows.
    static let abGroups = ["A", "B"]

    static let shared = DeviceStore(
        defaults: UserDefaults(suiteName: suiteName) ?? .standard,
        pushTokenDefaults: .standard
    )

    private let defaults: UserDefaults
    private let pushTokenDefaults: UserDefaults
    private let lock = NSLock()

    /// - Parameters:
    ///   - defaults: the device's suite;
    ///   - pushTokenDefaults: where the push token has always been — `.standard`, still written.
    init(defaults: UserDefaults, pushTokenDefaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pushTokenDefaults = pushTokenDefaults
    }

    /// The APNs token the app was handed last, kept for the next launches: in the device's suite,
    /// and where it has always been, for the old core and older SDK versions. One an older version
    /// stored is read from there.
    var pushToken: Data? {
        get {
            defaults.data(forKey: Self.pushTokenKey) ?? pushTokenDefaults.data(forKey: SdkConstants.deviceToken)
        }
        set {
            defaults.set(newValue, forKey: Self.pushTokenKey)
            pushTokenDefaults.set(newValue, forKey: SdkConstants.deviceToken)
        }
    }

    /// The APNs token as the old core has always read it: from `.standard`, where every version writes
    /// it — an older one that the app went back to included —, then the device's suite.
    var legacyPushToken: Data? {
        pushTokenDefaults.data(forKey: SdkConstants.deviceToken) ?? defaults.data(forKey: Self.pushTokenKey)
    }

    /// The device's push token (`sdk/core/push.md`): the last one the SDK got or was given, with its
    /// provider, whichever shop it came through. Each provider's token is kept apart as well
    /// (`deviceToken(_:)`): an app that hands the SDK both an APNs and an FCM token keeps both. Without
    /// one of its own, the APNs token an older version kept is the device's.
    var deviceToken: Rees46.PushToken? {
        get {
            lock.lock(); defer { lock.unlock() }
            if let value = defaults.string(forKey: Self.deviceTokenKey), !value.isEmpty,
               let provider = defaults.string(forKey: Self.deviceTokenProviderKey).flatMap(Rees46.PushProvider.init(rawValue:)) {
                return Rees46.PushToken(token: value, provider: provider)
            }
            return legacyApnsTokenLocked()
        }
        set {
            lock.lock(); defer { lock.unlock() }
            defaults.set(newValue?.token, forKey: Self.deviceTokenKey)
            defaults.set(newValue?.provider.rawValue, forKey: Self.deviceTokenProviderKey)
            if let token = newValue {
                defaults.set(token.token, forKey: Self.deviceTokenKey + "." + token.provider.rawValue)
            } else {
                Rees46.PushProvider.allCases.forEach { defaults.removeObject(forKey: Self.deviceTokenKey + "." + $0.rawValue) }
            }
        }
    }

    /// The device's last token of `provider`; for APNs without one of its own, the one an older
    /// version kept.
    func deviceToken(_ provider: Rees46.PushProvider) -> Rees46.PushToken? {
        lock.lock(); defer { lock.unlock() }
        if let value = defaults.string(forKey: Self.deviceTokenKey + "." + provider.rawValue), !value.isEmpty {
            return Rees46.PushToken(token: value, provider: provider)
        }
        if let value = defaults.string(forKey: Self.deviceTokenKey), !value.isEmpty,
           defaults.string(forKey: Self.deviceTokenProviderKey) == provider.rawValue {
            return Rees46.PushToken(token: value, provider: provider)
        }
        return provider == .apns ? legacyApnsTokenLocked() : nil
    }

    /// The device's tokens, one per provider it has: APNs, then FCM.
    var deviceTokens: [Rees46.PushToken] {
        Rees46.PushProvider.allCases.compactMap(deviceToken)
    }

    private func legacyApnsTokenLocked() -> Rees46.PushToken? {
        let data = defaults.data(forKey: Self.pushTokenKey) ?? pushTokenDefaults.data(forKey: SdkConstants.deviceToken)
        return data.flatMap { $0.isEmpty ? nil : Rees46.PushToken(token: Self.hex($0), provider: .apns) }
    }

    /// An APNs token as the API takes it: lowercase hex.
    static func hex(_ token: Data) -> String {
        token.map { String(format: "%02.2hhx", $0) }.joined()
    }

    /// The device's A/B group, `nil` until one is assigned.
    var abGroup: String? {
        lock.lock(); defer { lock.unlock() }
        return Self.validGroup(defaults.string(forKey: Self.abGroupKey))
    }

    /// The device's A/B group, assigned once: the stored one; otherwise `candidate` — the group of the
    /// first shop that has one (decision 4) — when it is valid; otherwise a new one. Under one lock, so
    /// two shops made at once without a group of their own get the same one.
    func resolveAbGroup(candidate: String?) -> String {
        lock.lock(); defer { lock.unlock() }
        if let stored = Self.validGroup(defaults.string(forKey: Self.abGroupKey)) {
            return stored
        }
        let group = Self.validGroup(candidate) ?? Self.abGroups.randomElement() ?? "A"
        defaults.set(group, forKey: Self.abGroupKey)
        return group
    }

    /// The advertising id the app gave the SDK last, through any shop.
    var advertisingId: String? {
        get {
            lock.lock(); defer { lock.unlock() }
            return defaults.string(forKey: Self.advertisingIdKey)
        }
        set {
            lock.lock(); defer { lock.unlock() }
            defaults.set(newValue, forKey: Self.advertisingIdKey)
        }
    }

    /// Takes `value` as the device's advertising id when it has none yet.
    func adoptAdvertisingId(_ value: String?) {
        guard let value = value, !value.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if (defaults.string(forKey: Self.advertisingIdKey) ?? "").isEmpty {
            defaults.set(value, forKey: Self.advertisingIdKey)
        }
    }

    private static func validGroup(_ value: String?) -> String? {
        guard let value = value, abGroups.contains(value) else { return nil }
        return value
    }
}
