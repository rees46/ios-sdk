//
//  RetryPolicy.swift
//  REES46
//
//  Decision 0002 as one rule for `/init` and the event queue: which answers are repeated, which
//  refuse, and how long to wait before the next try.
//

import Foundation

enum RetryPolicy {

    /// The longest pause between two tries, its spread included; `Retry-After` is held to it too.
    static let maxPause: TimeInterval = 5 * 60
    /// The spread of a pause: ±20 %.
    static let spread = 0.2
    /// The shortest wait a `Retry-After` gets: `0` would try again at once, for ever.
    static let minRetryAfter: TimeInterval = 1

    /// `5xx`, `408`, `410`, `417`, `426`, `429`: the server will answer later.
    static func isRetryable(_ code: Int) -> Bool {
        (500..<600).contains(code) || [408, 410, 417, 426, 429].contains(code)
    }

    /// The pause after `failures` failed tries in a row: 1 s, 2 s, 4 s … 5 min, spread by ±20 % with
    /// `random` in `0..<1`. The spread comes before the cap, as on Android: no pause is longer than five
    /// minutes, and the long ones spread below it.
    static func pause(afterFailures failures: Int, random: Double) -> TimeInterval {
        let exponent = Double(min(max(failures - 1, 0), 16))
        let base = min(pow(2, exponent), maxPause)
        let unit = min(max(random, 0), 1)
        return min(base * (1 + spread * (2 * unit - 1)), maxPause)
    }

    /// The pause an answer's `Retry-After` asks for, held between one second and five minutes: as long
    /// as the server says, but never at once and never longer than any other pause.
    static func pause(retryAfter: TimeInterval) -> TimeInterval {
        min(max(retryAfter, minRetryAfter), maxPause)
    }

    /// The pause after an answer: its `Retry-After`, otherwise the growing one.
    static func pause(retryAfter: TimeInterval?, afterFailures failures: Int, random: Double) -> TimeInterval {
        retryAfter.map { pause(retryAfter: $0) } ?? pause(afterFailures: failures, random: random)
    }
}
