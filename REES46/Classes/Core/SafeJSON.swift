//
//  SafeJSON.swift
//  REES46
//
//  JSON writing that cannot crash the app.
//

import Foundation

/// `JSONSerialization.data(withJSONObject:)` raises an Objective-C exception — which Swift cannot
/// catch, not even with `try?` — for anything that is not JSON: a `Date`, a custom class, NaN or
/// infinity. Apps hand the SDK such values in `customFields`, `customProperties` and search
/// filters, so every body the SDK writes from app data goes through here.
enum SafeJSON {

    /// The JSON of `object`, or `nil` when it is not a valid JSON object.
    static func data(_ object: Any, options: JSONSerialization.WritingOptions = []) -> Data? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: options)
    }

    /// Whether `object` can be written as JSON.
    static func isValid(_ object: Any) -> Bool {
        JSONSerialization.isValidJSONObject(object)
    }
}
