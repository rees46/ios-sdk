//
//  ClientBody.swift
//  REES46
//
//  The JSON body of a request of the client's namespaces — `profile`, `subscriptions`, `segments` —,
//  built and checked before anything is sent: a refused argument throws
//  `Rees46.SdkError.invalidArgument`.
//

import Foundation

/// The fields of one body: what is `nil` is not sent.
struct ClientBody {

    private(set) var fields: [String: Any] = [:]

    init(_ fields: [String: Any] = [:]) {
        self.fields = fields
    }

    mutating func set(_ name: String, _ value: Any?) {
        guard let value = value else { return }
        fields[name] = value
    }

    /// A contact or an identifier of the customer: none is not sent, an empty or blank one is refused.
    mutating func identifier(_ name: String, _ value: String?, _ argument: String) throws {
        guard let value = value else { return }
        guard !ApiArguments.isBlank(value) else {
            throw Rees46.SdkError.invalidArgument("\(argument) is empty")
        }
        fields[name] = value
    }

    /// The shop's own properties of a profile, each at the top level of the body. A key is of
    /// `[a-z0-9_]` and none of the request's own fields or the SDK's; a value is a string, a number, a
    /// boolean, `NSNull` or `nil`, or a list or map of them.
    mutating func customProperties(_ properties: [String: Any]?) throws {
        guard let properties = properties else { return }
        for key in properties.keys.sorted() {
            guard !key.isEmpty, key.unicodeScalars.allSatisfy(Self.keyCharacters.contains) else {
                throw Rees46.SdkError.invalidArgument("the custom property \(key) is not of [a-z0-9_]")
            }
            guard !Self.reservedKeys.contains(key) else {
                throw Rees46.SdkError.invalidArgument("the custom property \(key) is a field of the request")
            }
            guard let value = properties[key].flatMap(Self.json) else {
                throw Rees46.SdkError.invalidArgument("the custom property \(key) is not a JSON value")
            }
            fields[key] = value
        }
    }

    // MARK: - Values

    /// `value` as `YYYY-MM-DD` of a day of the calendar, or `invalidArgument`.
    static func date(_ value: String, _ name: String) throws -> String {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        let digits = parts.allSatisfy { $0.allSatisfy { $0.isASCII && $0.isNumber } }
        guard parts.count == 3, digits, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              DateComponents(year: year, month: month, day: day).isValidDate(in: Calendar(identifier: .gregorian))
        else {
            throw Rees46.SdkError.invalidArgument("\(name) is not a date YYYY-MM-DD")
        }
        return value
    }

    /// `value` as JSON — `nil` and an empty optional become `NSNull` —; `nil` when it is not JSON: a
    /// `Date`, an object, a number that is not finite.
    static func json(_ value: Any) -> Any? {
        switch value {
        case let text as String:
            return text
        case is NSNull:
            return NSNull()
        case let list as [Any]:
            let items = list.map(json)
            return items.contains { $0 == nil } ? nil : items.compactMap { $0 }
        case let map as [String: Any]:
            var object: [String: Any] = [:]
            for (key, item) in map {
                guard let converted = json(item) else { return nil }
                object[key] = converted
            }
            return object
        case let number as NSNumber:
            return number.doubleValue.isFinite ? number : nil
        default:
            let mirror = Mirror(reflecting: value)
            guard mirror.displayStyle == .optional else { return nil }
            return mirror.children.first.map { json($0.value) } ?? NSNull()
        }
    }

    /// The fields as one text, the same for the same fields: what popups v3 tell a change by.
    static func signature(_ fields: [String: Any]) -> String {
        SafeJSON.data(fields, options: [.sortedKeys]).flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: fields)
    }

    private static let keyCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")

    /// The fields of `ProfileUpdateRequest` and the ones the SDK adds to every request.
    private static let reservedKeys: Set<String> = [
        "email", "phone", "id", "external_id", "loyalty_id", "telegram_id", "fb_id", "vk_id", "first_name", "last_name",
        "gender", "birthday", "age", "location", "kids", "auto",
        "shop_id", "did", "sid", "seance", "segment", "stream"
    ]
}
