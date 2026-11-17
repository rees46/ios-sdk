//
//  LenientDecoding.swift
//  REES46
//
//  How the answers of the namespaces' methods are read with `Codable` (`sdk/contract/README.md`,
//  "Ответы"): a field that is missing, `null` or of a type that does not fit is empty, not a failure; a
//  number may come as a string and a string as a number; an unknown value of an enumeration is empty;
//  an element of a list that does not read is left out; fields the SDK does not know are ignored.
//  `decoding` is only for an answer that does not read into the method's model at all.
//
//  The answers are read into internal types (`Decodable` here), and the method's public model is made
//  from them: a public model that is `Decodable` would hand its decoding to the app as API.
//

import Foundation

/// One JSON scalar, whatever its type.
private enum LenientScalar: Decodable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // A JSON boolean reads only as `Bool`, a number never does: the order keeps `1` a number.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.typeMismatch(
                LenientScalar.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "not a scalar")
            )
        }
    }

    /// A string: a number as its digits — an integral one without a fraction —; an empty string is none.
    var string: String? {
        switch self {
        case .string(let value):
            return value.isEmpty ? nil : value
        case .int(let value):
            return String(value)
        case .double(let value):
            guard value.isFinite else { return nil }
            return Self.integral(value).map(String.init) ?? String(value)
        case .bool:
            return nil
        }
    }

    /// An integer: a number without a fraction, or a string of one.
    var int: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return Self.integral(value)
        case .string(let value):
            let text = value.trimmingCharacters(in: .whitespaces)
            return Int(text) ?? Double(text).flatMap(Self.integral)
        case .bool:
            return nil
        }
    }

    /// A finite number, or a string of one.
    var double: Double? {
        let value: Double?
        switch self {
        case .int(let int):
            value = Double(int)
        case .double(let double):
            value = double
        case .string(let text):
            value = Double(text.trimmingCharacters(in: .whitespaces))
        case .bool:
            value = nil
        }
        return value.flatMap { $0.isFinite ? $0 : nil }
    }

    /// A boolean: `true`/`false`, `1`/`0`, or a string of one of them.
    var bool: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .int(let value):
            return value == 1 ? true : value == 0 ? false : nil
        case .double(let value):
            return value == 1 ? true : value == 0 ? false : nil
        case .string(let value):
            switch value.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return nil
            }
        }
    }

    /// `value` as an `Int` when it has no fraction and fits one.
    private static func integral(_ value: Double) -> Int? {
        guard value.isFinite, value.rounded() == value, abs(value) < 9.0e15 else { return nil }
        return Int(value)
    }
}

/// Whatever an element of a list is: it reads, or the list leaves it out.
private struct Lossy<Element: Decodable>: Decodable {
    let value: Element?

    init(from decoder: Decoder) throws {
        value = try? Element(from: decoder)
    }
}

extension KeyedDecodingContainer {

    /// The string at `key`; a number is its digits. Missing, `null`, empty or not a scalar: `nil`.
    func lenientString(_ key: Key) -> String? {
        scalar(key)?.string
    }

    /// The integer at `key`, from a number without a fraction or a string of one; otherwise `nil`.
    func lenientInt(_ key: Key) -> Int? {
        scalar(key)?.int
    }

    /// The number at `key`, from a number or a string of one; otherwise `nil`.
    func lenientDouble(_ key: Key) -> Double? {
        scalar(key)?.double
    }

    /// The boolean at `key`, from `true`/`false`, `1`/`0` or a string of them; otherwise `nil`.
    func lenientBool(_ key: Key) -> Bool? {
        scalar(key)?.bool
    }

    /// The value of an enumeration at `key`; a value the SDK does not know — the server added one — is
    /// `nil`, not a failure.
    func lenientEnum<Value: RawRepresentable>(_ type: Value.Type, _ key: Key) -> Value? where Value.RawValue == String {
        lenientString(key).flatMap(Value.init(rawValue:))
    }

    /// The object at `key`; `nil` when it is missing, `null` or does not read as `Value`.
    func lenient<Value: Decodable>(_ type: Value.Type, _ key: Key) -> Value? {
        (try? decodeIfPresent(Lossy<Value>.self, forKey: key))?.value
    }

    /// The list at `key` without the elements that do not read; `nil` when it is missing, `null` or not
    /// a list.
    func lenientList<Element: Decodable>(_ type: Element.Type, _ key: Key) -> [Element]? {
        guard let list = try? decodeIfPresent([Lossy<Element>].self, forKey: key) else { return nil }
        return list.compactMap(\.value)
    }

    private func scalar(_ key: Key) -> LenientScalar? {
        try? decodeIfPresent(LenientScalar.self, forKey: key)
    }
}

/// A coding key of any name: what an answer's own keys are read with.
struct AnswerKey: CodingKey, ExpressibleByStringLiteral {
    let stringValue: String
    let intValue: Int? = nil

    init(_ name: String) {
        stringValue = name
    }

    init(stringLiteral name: String) {
        stringValue = name
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
