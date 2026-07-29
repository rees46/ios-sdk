//
//  Clock.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/// A source of the current time, injectable so time-dependent logic (the session TTL) is testable
/// without waiting real seconds.
protocol Clock {
    func now() -> Date
}

/// The production clock — wall-clock time.
struct SystemClock: Clock {
    func now() -> Date { Date() }
}
