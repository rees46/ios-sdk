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
/// The A/B group and the advertising id used to live in each shop's partition, and the shops' keys go
/// on being written (`UserIdentityRepositoryImpl`): `LegacyCore` and older SDK versions read them
/// there. The push token stays where it always was, in `UserDefaults.standard`.
final class DeviceStore {

    /// A suite of its own. The dot keeps it apart from every shop's partition: a partition's name is
    /// a prefix and a shop id with only letters, digits, `_` and `-`.
    static let suiteName = "personalization_sdk.device"

    static let abGroupKey = "ab_group"
    static let advertisingIdKey = "advertising_id"
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
    ///   - defaults: where the A/B group and the advertising id live;
    ///   - pushTokenDefaults: where the push token lives — `.standard`, as it always did.
    init(defaults: UserDefaults, pushTokenDefaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pushTokenDefaults = pushTokenDefaults
    }

    /// The APNs token the app was handed last, kept for the next launches.
    var pushToken: Data? {
        get { pushTokenDefaults.data(forKey: SdkConstants.deviceToken) }
        set { pushTokenDefaults.set(newValue, forKey: SdkConstants.deviceToken) }
    }

    /// The device's A/B group, `nil` until one is assigned.
    var abGroup: String? {
        lock.lock(); defer { lock.unlock() }
        return Self.validGroup(defaults.string(forKey: Self.abGroupKey))
    }

    /// The device's A/B group, assigned once: the stored one; otherwise `candidate` — the group of the
    /// first shop that has one (decision 4) — when it is valid; otherwise a new one. Under one lock, so
    /// two shops made at once end up with the same group.
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
