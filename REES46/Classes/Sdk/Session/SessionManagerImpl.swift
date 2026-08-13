//
//  SessionManagerImpl.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Default [SessionManager]: reads/writes the session through the per-shop [UserIdentityRepository], so
 the session is partitioned per shop for free. The TTL matches Android/RN (2 hours), and the id is a
 10-character alphanumeric like React Native's `generateSid`.

 The clock and the id generator are injected so the TTL and regeneration are deterministic in tests.
 */
final class SessionManagerImpl: SessionManager {

    /// Rolling session window. Matches Android `SESSION_CODE_EXPIRE` (2 * 3600 * 1000 ms) and RN
    /// `SESSION_CODE_EXPIRE` (120 minutes).
    static let sessionTTL: TimeInterval = 2 * 60 * 60

    private let identity: UserIdentityRepository
    private let clock: Clock
    private let generate: () -> String

    init(
        identity: UserIdentityRepository,
        clock: Clock = SystemClock(),
        generate: @escaping () -> String = SessionManagerImpl.generateSessionId
    ) {
        self.identity = identity
        self.clock = clock
        self.generate = generate
    }

    func currentSessionId() -> String {
        let now = clock.now()

        if let sid = identity.seance, !sid.isEmpty,
           let lastAct = identity.seanceLastActTime,
           now.timeIntervalSince(lastAct) < Self.sessionTTL {
            identity.seanceLastActTime = now // rolling: activity extends the window
            return sid
        }

        let sid = generate()
        identity.seance = sid
        identity.seanceLastActTime = now
        return sid
    }

    /// A 10-character alphanumeric session id (mirror of RN `generateSid`).
    static func generateSessionId() -> String {
        let source = Array("1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var generator = SystemRandomNumberGenerator()
        return String((0..<10).map { _ in source[Int.random(in: 0..<source.count, using: &generator)] })
    }
}
