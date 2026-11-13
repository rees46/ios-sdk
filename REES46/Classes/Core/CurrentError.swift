//
//  CurrentError.swift
//  REES46
//
//  The new core's error behind an old `SdkError`, while the SDK hands that error to a completion: what
//  `Rees46.BridgeErrors` gives the bridges.
//

import Foundation

/// The `Rees46.SdkError` behind the old error a completion is getting, on the thread that calls it.
enum CurrentError {

    private static let key = "com.rees46.sdk.current_error"

    private final class Box {
        let error: Rees46.SdkError
        init(_ error: Rees46.SdkError) { self.error = error }
    }

    /// The error of the completion running on this thread; `nil` outside one, or when the SDK has none.
    static var current: Rees46.SdkError? {
        (Thread.current.threadDictionary[key] as? Box)?.error
    }

    /// Runs `body` — which calls a completion — with `error` as the current error of this thread, and
    /// puts back what was there before.
    static func with<T>(_ error: Rees46.SdkError?, _ body: () -> T) -> T {
        let dictionary = Thread.current.threadDictionary
        let previous = dictionary[key]
        if let error = error {
            dictionary[key] = Box(error)
        } else {
            dictionary.removeObject(forKey: key)
        }
        defer {
            if let previous = previous {
                dictionary[key] = previous
            } else {
                dictionary.removeObject(forKey: key)
            }
        }
        return body()
    }
}
