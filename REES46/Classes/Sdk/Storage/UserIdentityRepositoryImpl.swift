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

 On the default partition it runs the one-time legacy adoption ([StorageMigration]) at construction,
 so an existing (pre-partition) install keeps its did with no silent re-registration. A host that
 supplies its own `storageKey` gets that suite verbatim and no migration — parity with Android's
 `preferencesKey`.
 */
final class UserIdentityRepositoryImpl: UserIdentityRepository {

    private let store: UserDefaults

    /// Builds the repository over [shopId]'s partition, migrating the legacy identity in on the
    /// default partition. Pass [storageKey] to use a custom suite verbatim (no migration).
    init(shopId: String, storageKey: String? = nil) {
        let store = StoragePartition.store(for: shopId, storageKey: storageKey)
        self.store = store
        if storageKey == nil {
            StorageMigration.migrateLegacyIfNeeded(into: store)
        }
    }

    /// Direct-store initializer for tests/DI — no migration, no shop-name derivation.
    init(store: UserDefaults) {
        self.store = store
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

    var advertisingId: String? {
        get { store.string(forKey: StoragePartition.idfaKey) }
        set { store.set(newValue, forKey: StoragePartition.idfaKey) }
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
