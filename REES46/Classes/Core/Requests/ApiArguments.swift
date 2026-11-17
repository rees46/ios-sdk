//
//  ApiArguments.swift
//  REES46
//
//  The text arguments of the namespaces' methods (`sdk.<namespace>.<method>`) as the contract reads them
//  (`sdk/contract/README.md`): a required one may not be blank, an optional blank one is not sent.
//

import Foundation

enum ApiArguments {

    /// Empty or only whitespace: a required text the contract refuses as `invalidArgument`.
    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// An optional text as it is sent: `nil`, empty and blank are none.
    static func given(_ text: String?) -> String? {
        text.flatMap { isBlank($0) ? nil : $0 }
    }

    /// An existing day of the calendar as `YYYY-MM-DD`, of ASCII digits: `2026-02-30` is none. A birthday
    /// `loyalty/members/join` cannot read erases the date it has.
    static func isCalendarDate(_ text: String) -> Bool {
        calendarYear(text) != nil
    }

    /// A birthday `profile/set` takes: an existing day `YYYY-MM-DD` of the years 1000 to 2999. The server
    /// ignores any other in silence.
    static func isBirthday(_ text: String) -> Bool {
        calendarYear(text).map { (1000...2999).contains($0) } ?? false
    }

    /// The year of `text` when it is an existing day of the calendar as `YYYY-MM-DD`; `nil` otherwise.
    private static func calendarYear(_ text: String) -> Int? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let days: Int
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: days = 31
        case 4, 6, 9, 11: days = 30
        case 2: days = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28
        default: days = 0
        }
        guard days > 0, (1...days).contains(day) else { return nil }
        return year
    }
}
