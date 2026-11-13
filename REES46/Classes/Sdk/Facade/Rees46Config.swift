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
    /// The old switch of the SDK's logs; `true` meant everything.
    @available(*, deprecated, message: "Set logLevel; enableLogs = true is logLevel = .debug.")
    public var enableLogs: Bool { logLevel == .debug }
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
    /// Custom `UserDefaults` suite name; `nil` uses the per-shop partition (the default).
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
    /// without network and keeps its own timeout.
    public let coreV2: Bool

    public init(
        shopId: String,
        apiDomain: String = "api.rees46.ru",
        stream: String = "ios",
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
        // `enableLogs = true` is the old way to ask for everything.
        self.logLevel = enableLogs && logLevel == .warning ? .debug : logLevel
        self.autoSendPushToken = autoSendPushToken
        self.sendAdvertisingId = sendAdvertisingId
        self.enableAutoPopupPresentation = enableAutoPopupPresentation
        self.needReInitialization = needReInitialization
        self.storageKey = storageKey
        self.coreV2 = coreV2
    }
}
