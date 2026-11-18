//
//  SecretRequest.swift
//  REES46
//
//  The requests of the server methods of the namespaces — the ones that take the shop's secret key
//  (`profile.getOrders`, `cart.clear`, `notifications.getHistory`; the decision on them is DEV-4723).
//

import Foundation

/// The query of a server method: `shop_secret` and the method's own fields. Sent with
/// `ApiRequest.secret`, it goes with `shop_id` and none of the device's fields — no `did`, `sid`,
/// `seance`, `segment`, `stream` —: the server finds the customer by the ids the caller gives. The
/// secret is never in a message or the log: the log has the method and the path only.
struct SecretQuery {

    private(set) var fields: [String: String]

    /// Blank, the secret is refused as `invalidArgument`.
    init(shopSecret: String) throws {
        guard !ApiArguments.isBlank(shopSecret) else {
            throw Rees46.SdkError.invalidArgument("shopSecret is empty")
        }
        fields = ["shop_secret": shopSecret]
    }

    /// The customer's ids the method was given, each its argument's name, its field and its value: an
    /// id given must not be blank, and one at least is needed.
    mutating func customer(_ ids: [(argument: String, field: String, value: String?)]) throws {
        for id in ids {
            try set(id.field, id.value, id.argument)
        }
        guard ids.contains(where: { $0.value != nil }) else {
            throw Rees46.SdkError.invalidArgument("one of \(ids.map(\.argument).joined(separator: ", ")) is needed")
        }
    }

    /// `value` under `field` when it is given; given blank, it is refused.
    mutating func set(_ field: String, _ value: String?, _ argument: String) throws {
        guard let value = value else { return }
        guard !ApiArguments.isBlank(value) else {
            throw Rees46.SdkError.invalidArgument("\(argument) is empty")
        }
        fields[field] = value
    }

    /// A day `YYYY-MM-DD` under `field` when it is given.
    mutating func date(_ field: String, _ value: String?, _ argument: String) throws {
        guard let value = value else { return }
        guard ApiArguments.isCalendarDate(value) else {
            throw Rees46.SdkError.invalidArgument("\(argument) must be a date YYYY-MM-DD")
        }
        fields[field] = value
    }

    /// A number of at least 1 under `field` when it is given.
    mutating func positive(_ field: String, _ value: Int?, _ argument: String) throws {
        guard let value = value else { return }
        guard value >= 1 else {
            throw Rees46.SdkError.invalidArgument("\(argument) is below 1")
        }
        fields[field] = String(value)
    }
}

/// The namespaces' requests of an instance, for a server method of an extension of a namespace's
/// protocol: the SDK's own namespace has them; for another conformer the call ends as `notInitialized`
/// and the log says `not_implemented`.
enum SecretMethods {

    static func notImplemented(_ name: String, owner: String) {
        SdkLogger.process.error(LogCode.notImplemented, "\(name) is not implemented by this \(owner)", ["call": name])
    }

    static func notImplemented<Value>(_ name: String, owner: String, _ completion: @escaping (Result<Value, Rees46.SdkError>) -> Void) {
        notImplemented(name, owner: owner)
        DispatchQueue.main.async { completion(.failure(.notInitialized)) }
    }

    /// The JSON object of an answer; `decoding` for another body.
    static func object(_ body: Data) throws -> [String: Any] {
        guard let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            throw Rees46.SdkError.decoding
        }
        return object
    }
}
