//
//  StoragePartition.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Naming and construction of the SDK's per-shop `UserDefaults` partitions.

 Multi-instance storage (R2): identity and session state are partitioned per `shop_id` so two shops
 in one app do not share one domain. Each shop gets its own `UserDefaults(suiteName:)` — a separate
 `personalization_sdk_<shopId>.plist` — keeping the keys themselves unchanged. Mirror of the Android
 `PreferencesPartition` (same `personalization_sdk_` prefix and filename-safe sanitising), so the two
 platforms share one mental model and one migration story.

 Only per-device state that is genuinely shop-scoped lives here: `device_id` (the did), the persisted
 `seance_id`, and the advertising id. The APNs/FCM **push token stays global** (`.standard`): one token
 per app install, fanned out to every shop's backend — see the push-token path.
 */
enum StoragePartition {

    /// Prefix for a shop's suite name. Must match Android `PreferencesPartition.PREFIX`. Stable
    /// forever: changing it would orphan every existing install's partition.
    static let prefix = "personalization_sdk_"

    // Keys that are partitioned per shop (identity + session + advertising id).
    static let deviceIdKey = SdkConstants.deviceIdKey // "device_id"
    static let seanceKey = "seance_id"
    static let idfaKey = "IDFA"

    /// Global flag (kept in the legacy `.standard` domain) marking the one-time legacy adoption as
    /// consumed, so only the first shop to initialize inherits the pre-partition identity.
    static let legacyConsumedFlag = "personalization_sdk_legacy_consumed"

    private static let unsafeFilenameChars = "[^A-Za-z0-9_-]"

    /// Filename-safe form of [shopId] for use inside a suite name.
    static func sanitize(_ shopId: String) -> String {
        shopId.replacingOccurrences(
            of: unsafeFilenameChars,
            with: "_",
            options: .regularExpression
        )
    }

    /// Stable suite name for [shopId]'s partition.
    static func suiteName(for shopId: String) -> String {
        prefix + sanitize(shopId)
    }

    /**
     The `UserDefaults` a shop should read/write. Defaults to the per-shop suite; a host that passes
     its own [storageKey] gets that suite verbatim (parity with Android's `preferencesKey`, and the
     opt-out from migration). Falls back to `.standard` only if the suite can't be created — which
     happens solely for reserved names (the app's bundle id), never for our prefixed names.
     */
    static func store(for shopId: String, storageKey: String? = nil) -> UserDefaults {
        let name = storageKey ?? suiteName(for: shopId)
        return UserDefaults(suiteName: name) ?? .standard
    }
}
