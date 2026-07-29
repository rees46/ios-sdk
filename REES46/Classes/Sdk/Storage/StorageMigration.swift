//
//  StorageMigration.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 One-time migration of the pre-partition identity into a shop's partition (R2).

 Before per-shop partitioning, `device_id` / `seance_id` / `IDFA` lived in `UserDefaults.standard`.
 On upgrade the first shop to initialize must inherit that identity so an existing install keeps its
 did (no silent re-registration). This copies the legacy values from `.standard` into the shop's
 partition once, then marks the legacy source consumed.

 iOS difference from Android: the legacy `.standard` carries no `shop_id` marker next to the did, so
 "does this legacy identity belong to this shop?" can't be answered directly. Instead the adoption is
 **consume-once**: the first shop to initialize inherits it and sets [StoragePartition.legacyConsumedFlag];
 a second shop then finds it consumed and gets its own fresh id from the server — so two shops never
 clone one identity. Pre-partition installs were single-shop and a binary's primary `shop_id` is fixed
 across versions, so the shop that adopts is the one that owned the did.
 */
enum StorageMigration {

    /**
     Copies the legacy identity from [legacy] into [store] exactly once across the app, guarded so it
     runs only when the partition has no did yet, the legacy source has one, and no shop has consumed
     it before. Non-destructive to the legacy values (only the consumed flag is written), and a no-op
     on fresh installs (nothing to copy) and on already-partitioned installs (partition non-empty).
     */
    static func migrateLegacyIfNeeded(
        into store: UserDefaults,
        legacy: UserDefaults = .standard
    ) {
        // Already partitioned for this shop — nothing to migrate.
        let existing = store.string(forKey: StoragePartition.deviceIdKey) ?? ""
        guard existing.isEmpty else { return }

        // Another shop already inherited the legacy identity — this one starts fresh.
        guard !legacy.bool(forKey: StoragePartition.legacyConsumedFlag) else { return }

        // Fresh install with no pre-partition identity — nothing to migrate.
        guard let legacyDeviceId = legacy.string(forKey: StoragePartition.deviceIdKey),
              !legacyDeviceId.isEmpty else { return }

        store.set(legacyDeviceId, forKey: StoragePartition.deviceIdKey)
        if let seance = legacy.string(forKey: StoragePartition.seanceKey) {
            store.set(seance, forKey: StoragePartition.seanceKey)
        }
        if let idfa = legacy.string(forKey: StoragePartition.idfaKey) {
            store.set(idfa, forKey: StoragePartition.idfaKey)
        }

        // The first shop to initialize inherits the pre-partition identity; later shops get their own.
        legacy.set(true, forKey: StoragePartition.legacyConsumedFlag)
    }
}
