//
//  UserIdentityRepository.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 The SDK's per-shop identity/session storage, behind a typed port.

 Owns exactly the state that is scoped to a `shop_id`: the device id (`did`), the persisted session
 (`seance`/`sid`), the advertising id (`IDFA`) and the A/B segment. Push tokens are device-global and deliberately not
 here. Mirrors the concept of the Android `UserSettingsRepository` (typed accessors over the store),
 without importing its use-case ceremony.

 The port exists so the ~dozen call sites in `SimplePersonalizationSDK` stop poking `UserDefaults`
 with raw string keys (which had already caused a stringly-typed bug), so the "partitioned per shop,
 token global" policy has a single owner, and so an in-memory implementation can be injected to test
 two-shop isolation without touching real storage or the network.
 */
protocol UserIdentityRepository: AnyObject {

    /// The permanent device id (`did`), or nil when none is stored yet.
    var deviceId: String? { get set }

    /// The persisted session id (`seance`/`sid`).
    var seance: String? { get set }

    /// When the session was last active — the anchor for the rolling session TTL. Nil when no session
    /// has been recorded yet.
    var seanceLastActTime: Date? { get set }

    /// The advertising id (`IDFA`).
    var advertisingId: String? { get set }

    /// The device's A/B segment, nil until one is assigned. Clearing the identity keeps it: the
    /// segment belongs to the device, not to the user.
    var abSegment: String? { get set }

    /// Removes only the device id — used by the forced re-initialization path.
    func removeDeviceId()

    /// Clears the user's identity (device id + session) — backs `deleteUserCredentials`.
    func clearIdentity()
}
