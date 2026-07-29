//
//  SessionManagerTests.swift
//  REES46Tests
//
//  Covers the rolling session TTL (decision №3 — parity with Android/RN). The clock and id generator
//  are injected, so reuse / expiry / refresh are pinned deterministically with no real waiting.
//

import XCTest
@testable import REES46

private final class FakeClock: Clock {
    var current: Date
    init(_ current: Date) { self.current = current }
    func now() -> Date { current }
}

final class SessionManagerTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_000_000)
    private let ttl = SessionManagerImpl.sessionTTL

    private func make(
        identity: UserIdentityRepository,
        clock: Clock,
        generate: @escaping () -> String = { "GENERATED" }
    ) -> SessionManagerImpl {
        SessionManagerImpl(identity: identity, clock: clock, generate: generate)
    }

    func test_generates_and_persists_a_session_when_none_exists() {
        let identity = InMemoryUserIdentityRepository()
        let clock = FakeClock(base)
        let manager = make(identity: identity, clock: clock, generate: { "NEW" })

        let sid = manager.currentSessionId()

        XCTAssertEqual(sid, "NEW")
        XCTAssertEqual(identity.seance, "NEW")
        XCTAssertEqual(identity.seanceLastActTime, base)
    }

    func test_reuses_the_session_within_the_ttl_window() {
        let identity = InMemoryUserIdentityRepository()
        identity.seance = "S1"
        identity.seanceLastActTime = base.addingTimeInterval(-ttl + 1) // still fresh
        let manager = make(identity: identity, clock: FakeClock(base), generate: { "NEW" })

        XCTAssertEqual(manager.currentSessionId(), "S1")
    }

    func test_reuse_refreshes_the_activity_timestamp() {
        let identity = InMemoryUserIdentityRepository()
        identity.seance = "S1"
        identity.seanceLastActTime = base.addingTimeInterval(-3600) // 1h ago
        let manager = make(identity: identity, clock: FakeClock(base), generate: { "NEW" })

        _ = manager.currentSessionId()

        XCTAssertEqual(identity.seanceLastActTime, base, "activity must roll the window forward")
    }

    func test_regenerates_after_the_ttl_expires() {
        let identity = InMemoryUserIdentityRepository()
        identity.seance = "S1"
        identity.seanceLastActTime = base.addingTimeInterval(-ttl - 1) // just lapsed
        let manager = make(identity: identity, clock: FakeClock(base), generate: { "NEW" })

        let sid = manager.currentSessionId()

        XCTAssertEqual(sid, "NEW")
        XCTAssertEqual(identity.seance, "NEW")
        XCTAssertEqual(identity.seanceLastActTime, base)
    }

    func test_regenerates_exactly_at_the_ttl_boundary() {
        let identity = InMemoryUserIdentityRepository()
        identity.seance = "S1"
        identity.seanceLastActTime = base.addingTimeInterval(-ttl) // exactly TTL → not fresh
        let manager = make(identity: identity, clock: FakeClock(base), generate: { "NEW" })

        XCTAssertEqual(manager.currentSessionId(), "NEW")
    }

    func test_regenerates_when_there_is_no_timestamp() {
        let identity = InMemoryUserIdentityRepository()
        identity.seance = "S1"
        identity.seanceLastActTime = nil
        let manager = make(identity: identity, clock: FakeClock(base), generate: { "NEW" })

        XCTAssertEqual(manager.currentSessionId(), "NEW")
    }

    func test_regenerates_when_the_stored_session_is_empty() {
        let identity = InMemoryUserIdentityRepository()
        identity.seance = ""
        identity.seanceLastActTime = base
        let manager = make(identity: identity, clock: FakeClock(base), generate: { "NEW" })

        XCTAssertEqual(manager.currentSessionId(), "NEW")
    }

    func test_two_shops_keep_independent_sessions() {
        let a = InMemoryUserIdentityRepository()
        let b = InMemoryUserIdentityRepository()
        let clock = FakeClock(base)
        let managerA = make(identity: a, clock: clock, generate: { "A-SID" })
        let managerB = make(identity: b, clock: clock, generate: { "B-SID" })

        XCTAssertEqual(managerA.currentSessionId(), "A-SID")
        XCTAssertEqual(managerB.currentSessionId(), "B-SID")
        XCTAssertEqual(a.seance, "A-SID")
        XCTAssertEqual(b.seance, "B-SID")
    }

    func test_generated_id_is_ten_alphanumeric_characters() {
        let allowed = CharacterSet(charactersIn: "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        for _ in 0..<50 {
            let sid = SessionManagerImpl.generateSessionId()
            XCTAssertEqual(sid.count, 10)
            XCTAssertTrue(sid.unicodeScalars.allSatisfy { allowed.contains($0) }, "unexpected char in \(sid)")
        }
    }
}
