//
//  SessionManager.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Owns the shop's session id (`seance`/`sid`) with a rolling time-to-live.

 Aligns iOS with Android and React Native: the session is client-generated, persisted per shop, and
 reused across cold starts while it is still fresh (last activity within the TTL). After the window
 lapses a new session begins. This replaces the old iOS behaviour of a fresh `UUID` per process /
 adopting the server-assigned seance, so session-scoped analytics are consistent across platforms.
 */
protocol SessionManager: AnyObject {

    /// The session id to use now: the persisted one when still inside the TTL window (its activity
    /// timestamp is refreshed), otherwise a freshly generated one that is persisted. Idempotent within
    /// a window — repeated calls return the same id.
    func currentSessionId() -> String
}
