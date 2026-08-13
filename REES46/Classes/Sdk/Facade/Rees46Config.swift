//
//  Rees46Config.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Configuration for one SDK instance (one shop).

 The unified initialization input shared by `Rees46.initialize` and `Rees46.register(shops:)`. Mirrors
 the parameters of the (deprecated) `createPersonalizationSDK`, minus the per-call user identifiers
 (`userEmail`/`userPhone`/`userLoyaltyId`) and the `parentViewController` — those are set on the
 instance after init. Storage is partitioned per `shopId` automatically (see `StoragePartition`); pass
 `storageKey` only to pin a custom suite (parity with Android's `preferencesKey`), which also opts that
 shop out of the legacy identity migration.

 Mirror of the Android `Rees46Config`.
 */
public struct Rees46Config {

    /// The shop key — also the storage partition key and the id used by `Rees46.instance(for:)`.
    public let shopId: String
    /// API host the instance talks to (a region points here).
    public let apiDomain: String
    /// Traffic stream label sent with every request.
    public let stream: String
    /// Whether the SDK logs its network activity.
    public let enableLogs: Bool
    /// Whether the SDK registers push tokens with the backend on its own.
    public let autoSendPushToken: Bool
    /// Whether the SDK collects and sends the advertising id (IDFA).
    public let sendAdvertisingId: Bool
    /// Whether the SDK presents init-time popups itself.
    public let enableAutoPopupPresentation: Bool
    /// Forces a fresh `init` request instead of reusing stored session data.
    public let needReInitialization: Bool
    /// Custom `UserDefaults` suite name; `nil` uses the per-shop partition (the default).
    public let storageKey: String?

    public init(
        shopId: String,
        apiDomain: String = "api.rees46.ru",
        stream: String = "ios",
        enableLogs: Bool = false,
        autoSendPushToken: Bool = true,
        sendAdvertisingId: Bool = false,
        enableAutoPopupPresentation: Bool = true,
        needReInitialization: Bool = false,
        storageKey: String? = nil
    ) {
        self.shopId = shopId
        self.apiDomain = apiDomain
        self.stream = stream
        self.enableLogs = enableLogs
        self.autoSendPushToken = autoSendPushToken
        self.sendAdvertisingId = sendAdvertisingId
        self.enableAutoPopupPresentation = enableAutoPopupPresentation
        self.needReInitialization = needReInitialization
        self.storageKey = storageKey
    }
}
