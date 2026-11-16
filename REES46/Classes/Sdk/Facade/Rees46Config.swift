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
 `storageKey` only when the app needs its own prefix of the partitions.

 Mirror of the Android `Rees46Config`.
 */
public struct Rees46Config {

    /// The shop key — also the storage partition key and the id used by `Rees46.instance(for:)`.
    public let shopId: String
    /// API host the instance talks to (a region points here).
    public let apiDomain: String
    /// Traffic stream label sent with every request.
    public let stream: String
    /// The device id (`did`) the app already keeps — say from another version of the SDK — for a shop
    /// that has none yet: the shop takes it instead of getting a new one from `/init`. A shop that has
    /// its own keeps it; `nil` or empty is none.
    public let deviceId: String?
    /// The old switch of the SDK's logs, as it was given; `true` meant everything.
    @available(*, deprecated, message: "Set logLevel; enableLogs = true is logLevel = .debug.")
    public var enableLogs: Bool { givenEnableLogs }
    private let givenEnableLogs: Bool
    /// How much the SDK writes to the log, `warning` by default; see `Rees46.setLogHandler`.
    public let logLevel: Rees46.LogLevel
    /// Whether the SDK registers push tokens with the backend on its own.
    public let autoSendPushToken: Bool
    /// Whether the SDK collects and sends the advertising id (IDFA).
    public let sendAdvertisingId: Bool
    /// Whether the SDK presents init-time popups itself.
    public let enableAutoPopupPresentation: Bool
    /// Forces a fresh `init` request instead of reusing stored session data.
    public let needReInitialization: Bool
    /// The app's prefix of the shop's storage: the shop's `UserDefaults` suite is
    /// `<storageKey>_personalization_sdk_<shopId>`, as on Android, and its files have a folder of that
    /// name; `nil` (the default) is `personalization_sdk_<shopId>`. Earlier versions named the suite
    /// `storageKey` itself, so two shops on one key shared it; the SDK copies the shop's values from
    /// that suite once and leaves it as it is. A key set on an install that had none starts a fresh
    /// partition.
    ///
    /// A key that starts with `group.` names an app group's suite and keeps that meaning: the suite
    /// itself is the shop's storage, shared with the app's extensions as before (shops on one group key
    /// share it); the shop's files still get a folder of their own.
    public let storageKey: String?
    /// Runs the shop on the new core of the SDK (`false` by default): its network client first,
    /// with init, session, queue and pushes to follow. The first `Rees46.initialize` or
    /// `Rees46.register` of the process decides for every shop until the app restarts; a shop that
    /// asks otherwise gets the process's core, and the log says `core_flag_mismatch`.
    ///
    /// The new core sends through a session of its own. `configureURLSession(configuration:)` and a
    /// `urlSession` the app sets give it their configuration — proxy, headers, protocols, TLS settings
    /// — but not a session's delegate: certificate pinning done in a delegate does not apply, and the
    /// log says `invalid_config` with the reason `url_session_delegate`. A request still fails at once
    /// without network and keeps its own timeout. On either core the SDK sends and keeps no cookies.
    public let coreV2: Bool

    public init(
        shopId: String,
        apiDomain: String = "api.rees46.ru",
        stream: String = "ios",
        deviceId: String? = nil,
        enableLogs: Bool = false,
        logLevel: Rees46.LogLevel = .warning,
        autoSendPushToken: Bool = true,
        sendAdvertisingId: Bool = false,
        enableAutoPopupPresentation: Bool = true,
        needReInitialization: Bool = false,
        storageKey: String? = nil,
        coreV2: Bool = false
    ) {
        self.shopId = shopId
        self.apiDomain = apiDomain
        self.stream = stream
        self.deviceId = deviceId
        self.givenEnableLogs = enableLogs
        // `enableLogs = true` is the old way to ask for everything.
        self.logLevel = enableLogs && logLevel == .warning ? .debug : logLevel
        self.autoSendPushToken = autoSendPushToken
        self.sendAdvertisingId = sendAdvertisingId
        self.enableAutoPopupPresentation = enableAutoPopupPresentation
        self.needReInitialization = needReInitialization
        self.storageKey = storageKey
        self.coreV2 = coreV2
    }

    /// Whether an instance made with `other` behaves as one made with this configuration.
    func hasSameSettings(as other: Rees46Config) -> Bool {
        shopId == other.shopId
            && apiDomain == other.apiDomain
            && stream == other.stream
            && (deviceId ?? "") == (other.deviceId ?? "")
            && logLevel == other.logLevel
            && autoSendPushToken == other.autoSendPushToken
            && sendAdvertisingId == other.sendAdvertisingId
            && enableAutoPopupPresentation == other.enableAutoPopupPresentation
            && needReInitialization == other.needReInitialization
            && storageKey == other.storageKey
            && coreV2 == other.coreV2
    }
}
