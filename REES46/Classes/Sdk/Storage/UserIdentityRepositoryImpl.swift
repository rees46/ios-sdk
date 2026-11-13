//
//  UserIdentityRepositoryImpl.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 `UserDefaults`-backed [UserIdentityRepository]: reads and writes the shop's identity in a per-shop
 partition ([StoragePartition]) instead of the shared `.standard` domain, so two shops in one app do
 not clone one identity.

 Built for a shop, it runs the identity migrations once ([StorageMigrations]): the pre-partition
 identity, or the suite an app's `storageKey` named before it became a prefix; then the advertising id
 into the device's store. The A/B segment and the advertising id belong to the device ([DeviceStore]);
 the shop's keys go on being written, because `LegacyCore` and older SDK versions read them.
 */
final class UserIdentityRepositoryImpl: UserIdentityRepository {

    private let store: UserDefaults
    private let device: DeviceStore?

    /// Builds the repository over [shopId]'s partition — [storageKey] is the app's prefix of it — and
    /// migrates what older versions left into it.
    init(shopId: String, storageKey: String? = nil, device: DeviceStore? = .shared, legacy: UserDefaults = .standard) {
        let store = StoragePartition.store(for: shopId, storageKey: storageKey)
        self.store = store
        self.device = device
        StorageMigrations.migrateIdentity(
            into: store,
            partitionName: StoragePartition.suiteName(for: shopId, storageKey: storageKey),
            storageKey: storageKey,
            legacy: legacy,
            device: device
        )
    }

    /// Direct-store initializer for tests/DI — no migration, no shop-name derivation; without [device]
    /// the A/B segment is the shop's own.
    init(store: UserDefaults, device: DeviceStore? = nil) {
        self.store = store
        self.device = device
    }

    var deviceId: String? {
        get { store.string(forKey: StoragePartition.deviceIdKey) }
        set { store.set(newValue, forKey: StoragePartition.deviceIdKey) }
    }

    var seance: String? {
        get { store.string(forKey: StoragePartition.seanceKey) }
        set { store.set(newValue, forKey: StoragePartition.seanceKey) }
    }

    var seanceLastActTime: Date? {
        get {
            guard let seconds = store.object(forKey: StoragePartition.seanceLastActKey) as? Double else {
                return nil
            }
            return Date(timeIntervalSince1970: seconds)
        }
        set {
            if let newValue = newValue {
                store.set(newValue.timeIntervalSince1970, forKey: StoragePartition.seanceLastActKey)
            } else {
                store.removeObject(forKey: StoragePartition.seanceLastActKey)
            }
        }
    }

    /// The shop's own: an id the app gave one shop does not go out with another's `/init`.
    var advertisingId: String? {
        get { store.string(forKey: StoragePartition.idfaKey) }
        set {
            store.set(newValue, forKey: StoragePartition.idfaKey)
            if let newValue = newValue, !newValue.isEmpty {
                device?.advertisingId = newValue
            }
        }
    }

    var abSegment: String? {
        get { store.string(forKey: StoragePartition.abSegmentKey) }
        set { store.set(newValue, forKey: StoragePartition.abSegmentKey) }
    }

    /// The device's group: the one the device has, or this shop's when it is the first to have one,
    /// or a new one (decision 4). The shop's key gets it too: `LegacyCore` sends what it reads there.
    func resolveAbSegment() -> String {
        guard let device = device else { return resolveOwnAbSegment() }
        let group = device.resolveAbGroup(candidate: abSegment)
        if abSegment != group {
            abSegment = group
        }
        return group
    }

    func removeDeviceId() {
        store.removeObject(forKey: StoragePartition.deviceIdKey)
    }

    func clearIdentity() {
        store.set(nil, forKey: StoragePartition.deviceIdKey)
        store.set(nil, forKey: StoragePartition.seanceKey)
        store.removeObject(forKey: StoragePartition.seanceLastActKey)
    }
}
