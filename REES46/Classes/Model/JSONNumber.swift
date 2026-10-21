import Foundation

/// Numbers in product payloads. Most endpoints send JSON numbers, but `products/get` sends the
/// price as a string (`"14990.0"`) and `"discount": false` for a product without a discount.
/// Strings are parsed; booleans, empty strings and anything non-finite read as missing.
enum JSONNumber {

    static func double(_ value: Any?) -> Double? {
        let number: Double?
        switch value {
        case let boxed as NSNumber:
            number = CFGetTypeID(boxed) == CFBooleanGetTypeID() ? nil : boxed.doubleValue
        case let text as String:
            number = Double(text.trimmingCharacters(in: .whitespaces))
        default:
            number = nil
        }
        guard let number, number.isFinite else { return nil }
        return number
    }

    /// Whole part of the number; `nil` when it does not fit `Int`.
    static func int(_ value: Any?) -> Int? {
        double(value).flatMap { Int(exactly: $0.rounded(.towardZero)) }
    }
}
