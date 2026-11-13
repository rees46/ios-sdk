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

 `Rees46Config.storageKey` is the app's own prefix (decision 5): the partition is
 `<storageKey>_personalization_sdk_<shopId>`, the same name as on Android. Before, the suite named
 exactly `storageKey` was the shop's whole storage; `StorageMigrations` copies it into the partition
 once and leaves it as it is. A new `storageKey` on an existing install starts a fresh partition — it
 never falls back to the unprefixed one, so separate keys stay separate.

 A `storageKey` that names an app group (`group.…`) keeps its old meaning: that suite is the partition,
 shared with the app's extensions, as it always was. Shops on one group key share it, as before. The
 shop's files still get a folder of their own (`folderName`).

 What lives here is the shop's: the did, the session, the stories state, the source, and the shop's
 copies of the advertising id and the A/B group, which belong to the device (`DeviceStore`) and are
 still written here for `LegacyCore` and older SDK versions. The push token stays in `.standard`.
 */
enum StoragePartition {

    /// Prefix for a shop's suite name. Must match Android `PreferencesPartition.PREFIX`. Stable
    /// forever: changing it would orphan every existing install's partition.
    static let prefix = "personalization_sdk_"

    // Keys that are partitioned per shop (identity + session + advertising id + A/B segment).
    static let deviceIdKey = SdkConstants.deviceIdKey // "device_id"
    static let seanceKey = "seance_id"
    static let seanceLastActKey = "seance_last_act"
    static let idfaKey = "IDFA"
    /// The device's A/B segment. Same key as Android's.
    static let abSegmentKey = "segment_ab_testing"

    /// Global flag (kept in the legacy `.standard` domain) marking the one-time legacy adoption as
    /// consumed, so only the first shop to initialize inherits the pre-partition identity.
    static let legacyConsumedFlag = "personalization_sdk_legacy_consumed"

    /// The SDK's own keys in a partition, besides the ones that start with `shopKeyPrefixes`: what the
    /// migration of an old `storageKey` suite copies, and nothing else an app may keep in that suite.
    static let shopKeys: Set<String> = [
        deviceIdKey, seanceKey, seanceLastActKey, idfaKey, abSegmentKey,
        TrackingSourceStoreImpl.Keys.code, TrackingSourceStoreImpl.Keys.type, TrackingSourceStoreImpl.Keys.savedAt
    ]
    /// The stories state (`LocalStateRepositoryImpl`): one key per story, slide or product.
    static let shopKeyPrefixes = LocalStateRepositoryImpl.keyPrefixes

    static func isShopKey(_ key: String) -> Bool {
        shopKeys.contains(key) || shopKeyPrefixes.contains { key.hasPrefix($0) }
    }

    /// The app's prefix, when it set one: an empty `storageKey` is none.
    static func prefix(_ storageKey: String?) -> String? {
        guard let storageKey = storageKey, !storageKey.isEmpty else { return nil }
        return storageKey
    }

    private static let unsafeFilenameChars = "[^A-Za-z0-9_-]"

    /// Filename-safe form of [shopId] for use inside a suite name.
    static func sanitize(_ shopId: String) -> String {
        shopId.replacingOccurrences(
            of: unsafeFilenameChars,
            with: "_",
            options: .regularExpression
        )
    }

    /// The prefix of an app group's suite: a `storageKey` that starts with it is the suite itself.
    static let appGroupPrefix = "group."

    /// Whether `storageKey` names an app group's suite, which is the partition as it is.
    static func isAppGroup(_ storageKey: String?) -> Bool {
        prefix(storageKey)?.hasPrefix(appGroupPrefix) ?? false
    }

    /// Stable suite name for [shopId]'s partition: `personalization_sdk_<shopId>`, after the app's
    /// [storageKey] and `_` when it set one; an app group's [storageKey] as it is.
    static func suiteName(for shopId: String, storageKey: String? = nil) -> String {
        if isAppGroup(storageKey), let group = prefix(storageKey) {
            return group
        }
        return prefixedName(for: shopId, storageKey: storageKey)
    }

    /// The name of the shop's folder of files: the prefixed partition name, also for an app group's
    /// key, so two shops on one group never share their saved answer or queue.
    static func folderName(for shopId: String, storageKey: String? = nil) -> String {
        sanitize(prefixedName(for: shopId, storageKey: storageKey))
    }

    private static func prefixedName(for shopId: String, storageKey: String?) -> String {
        let name = Self.prefix + sanitize(shopId)
        guard let storageKey = prefix(storageKey) else { return name }
        return storageKey + "_" + name
    }

    // MARK: - The storageKey of a live shop

    private static let knownKeysLock = NSLock()
    private static var knownKeys: [String: String] = [:]

    /// Remembers the `storageKey` the shop's instance was made with, for code that has only the shop
    /// at hand (the stories' media state, the popups' frequency): it opens the same partition.
    static func remember(storageKey: String?, forShop shopId: String) {
        knownKeysLock.lock(); defer { knownKeysLock.unlock() }
        knownKeys[shopId] = prefix(storageKey)
    }

    /// The `storageKey` of the shop's instance; `nil` when it had none or none was made.
    static func storageKey(ofShop shopId: String) -> String? {
        knownKeysLock.lock(); defer { knownKeysLock.unlock() }
        return knownKeys[shopId]
    }

    /// The partition of a shop made in this process, with the `storageKey` it was made with.
    static func store(ofShop shopId: String) -> UserDefaults {
        store(for: shopId, storageKey: storageKey(ofShop: shopId))
    }

    /**
     The `UserDefaults` a shop should read/write: its partition. Falls back to `.standard` only if the
     suite can't be created — which happens solely for reserved names (the app's bundle id), never for
     a prefix and a shop id.
     */
    static func store(for shopId: String, storageKey: String? = nil) -> UserDefaults {
        UserDefaults(suiteName: suiteName(for: shopId, storageKey: storageKey)) ?? .standard
    }

    /// The device id a shop keeps, for code that has no instance of it (a pending shop's push): its
    /// partition, or the suite its `storageKey` named before it became a prefix, when the shop's
    /// instance has not been made since.
    static func deviceId(for shopId: String, storageKey: String? = nil) -> String {
        if let did = store(for: shopId, storageKey: storageKey).string(forKey: deviceIdKey), !did.isEmpty {
            return did
        }
        guard let storageKey = prefix(storageKey),
              storageKey != suiteName(for: shopId, storageKey: storageKey),
              let old = UserDefaults.standard.persistentDomain(forName: storageKey)?[deviceIdKey] as? String else {
            return ""
        }
        return old
    }
}
