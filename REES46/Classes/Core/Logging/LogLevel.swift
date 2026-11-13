//
//  LogLevel.swift
//  REES46
//

import Foundation

extension Rees46 {

    /// How much the SDK writes to the log. The default is `warning`: warnings and errors.
    ///
    /// Nested in the facade: a top-level `LogLevel` clashes with other modules an app imports, and
    /// `.none` of a top-level type reads as `Optional.none`.
    public enum LogLevel: Int, Comparable, CaseIterable {
        /// Requests (method and path), state changes, queue decisions.
        case debug
        /// Initialization finished, the session changed, the push token was sent.
        case info
        /// A retried `/init`, an event the queue dropped, an answer that did not parse.
        case warning
        /// The shop refused, a `4xx` to an SDK request, an exception caught inside the SDK.
        case error
        /// Nothing: the SDK does not log at all.
        case none

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
