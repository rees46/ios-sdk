//
//  StorageMigrations.swift
//  REES46
//
//  The one-shot migrations of a shop's storage (`sdk/core/storage.md`).
//

import Foundation

/// Each migration runs once per shop, when the shop's instance is made — before its `/init` — and
/// marks itself with a flag in the shop's partition. One whose source did not answer (a disk error, a
/// locked keychain) leaves its flag unset and runs again on the next launch.
///
/// No migration deletes what `LegacyCore` or an older SDK reads: sources are copied, never cleared.
/// Two sources move rather than copy, on purpose:
/// - the keychain backup of the init answer under the pre-partition account is consumed by the first
///   shop (`KeychainInitStoreImpl`): left in place, a second shop would adopt the same device id;
/// - `Documents/<shopId>.json` moves to the SDK's folder in Application Support (`ShopStorage`): an
///   older SDK only reads it offline, and `/init` gives it the device id anyway.
enum StorageMigrations {

    enum Step: String, CaseIterable {
        /// The suite an app's `storageKey` named in full, before `storageKey` became a prefix.
        case storageKeySuite = "storage_key_suite"
        /// The identity in `UserDefaults.standard` from before the partitions per shop.
        case standardIdentity = "standard_identity"
        /// The shop's advertising id into the device's store. The A/B group needs no step: the first
        /// shop to resolve it gives the device its group (`DeviceStore.resolveAbGroup`).
        case deviceAdvertisingId = "device_advertising_id"
        /// The keychain backup of the init answer under the pre-partition account or another service.
        /// Its flag holds the service it ran under: another link mode looks again.
        case keychainItem = "keychain_item"
        /// `Documents/<shopId>.json` into the SDK's folder in Application Support.
        case savedInitFile = "saved_init_file"
    }

    /// Held while a shop takes what has no shop and only one shop may take: the pre-partition identity
    /// and the legacy keychain item.
    static let adoptionLock = NSLock()

    static func flagKey(_ step: Step) -> String {
        "personalization_sdk.migrated.\(step.rawValue)"
    }

    static func isDone(_ step: Step, in partition: UserDefaults) -> Bool {
        if step == .keychainItem {
            return partition.string(forKey: flagKey(step)) == KeychainPartition.service
        }
        return partition.bool(forKey: flagKey(step))
    }

    /// Runs `migrate` unless the shop's flag says it ran. `migrate` returns whether it is done; `false`
    /// leaves the flag unset, so the next launch tries again.
    static func once(_ step: Step, in partition: UserDefaults, _ migrate: () -> Bool) {
        guard !isDone(step, in: partition) else { return }
        if migrate() {
            partition.set(true, forKey: flagKey(step))
        }
    }

    // MARK: - Identity

    /// The migrations of a shop's identity: the old `storageKey` suite or the pre-partition identity,
    /// then the advertising id into the device's store.
    static func migrateIdentity(
        into partition: UserDefaults,
        partitionName: String,
        storageKey: String?,
        legacy: UserDefaults = .standard,
        device: DeviceStore?
    ) {
        if let storageKey = StoragePartition.prefix(storageKey) {
            once(.storageKeySuite, in: partition) {
                copyStorageKeySuite(named: storageKey, into: partition, partitionName: partitionName)
            }
        } else {
            once(.standardIdentity, in: partition) {
                // Consume-once across shops: two shops made on two threads must not both take it.
                adoptionLock.lock(); defer { adoptionLock.unlock() }
                StorageMigration.migrateLegacyIfNeeded(into: partition, legacy: legacy)
                return true
            }
        }
        if let device = device {
            once(.deviceAdvertisingId, in: partition) {
                device.adoptAdvertisingId(partition.string(forKey: StoragePartition.idfaKey))
                return true
            }
        }
    }

    /// Copies the SDK's keys from the suite named exactly `suiteName` — the shop's whole storage while
    /// `storageKey` was the suite's name — where the partition has no value of its own. The old suite
    /// stays as it is: an older SDK still reads it.
    static func copyStorageKeySuite(named suiteName: String, into partition: UserDefaults, partitionName: String) -> Bool {
        guard suiteName != partitionName else { return true }
        // The suite's own values only: a suite's `dictionaryRepresentation` mixes in the global domain.
        let old = UserDefaults.standard.persistentDomain(forName: suiteName) ?? [:]
        for (key, value) in old where StoragePartition.isShopKey(key) && partition.object(forKey: key) == nil {
            partition.set(value, forKey: key)
        }
        return true
    }
}
