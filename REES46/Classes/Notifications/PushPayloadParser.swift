//
//  PushPayloadParser.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Foundation

/**
 Pure extraction of the fields the SDK needs from a raw APNs/FCM push payload — the target `shop_id`
 and the `(type, code)` a track call carries.

 Side-effect-free and instance-free, so both `Rees46.handlePush` (multi-instance routing) and the
 legacy `NotificationService` share one parsing story.

 The server sends two shapes:
 - FCM (and HMS): every value is a string; `type` and `id` are top-level, `event` is a JSON string.
 - APNs (a token with `platform=ios`): `src` and `event` are objects; `type` and `id` are inside `src`.

 `type` is the mailing type (`bulk`, `chain`, `transactional`, `digest`). `event.type` is what the
 push opens (`web`, `product`, …), not the mailing type, so it never becomes the tracked type.
 */
enum PushPayloadParser {

    private enum Keys {
        static let shopId = "shop_id"
        static let type = "type"
        static let id = "id"
        static let event = "event"
        static let src = "src"
    }

    /// The shop a push is addressed to, or `nil` when the payload carries no `shop_id`.
    static func shopId(from payload: [AnyHashable: Any]) -> String? {
        string(payload[Keys.shopId])
    }

    /// The `(type, code)` a track call needs, or `nil` when the payload is not an SDK push.
    static func typeAndCode(from payload: [AnyHashable: Any]) -> (type: String, code: String)? {
        let src = dictionary(for: Keys.src, in: payload)
        guard
            let type = string(payload[Keys.type]) ?? string(src?[Keys.type]),
            let code = string(payload[Keys.id]) ?? string(src?[Keys.id]) ?? legacyNestedId(in: payload)
        else { return nil }
        return (type, code)
    }

    /// The `event` of the push: what it opens. A JSON string in FCM, an object in APNs.
    static func event(from payload: [AnyHashable: Any]) -> [String: Any]? {
        dictionary(for: Keys.event, in: payload)
    }

    /// A field that is a JSON object, sent either as an object (APNs) or as a JSON string (FCM).
    static func dictionary(for key: String, in payload: [AnyHashable: Any]) -> [String: Any]? {
        if let object = payload[key] as? [String: Any] {
            return object
        }
        if let object = payload[key] as? [AnyHashable: Any] {
            return Dictionary(uniqueKeysWithValues: object.compactMap { key, value in
                (key as? String).map { ($0, value) }
            })
        }
        guard let jsonString = payload[key] as? String,
              let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any]
        else { return nil }
        return dict
    }

    /// An `id` sent as an object `{"id": "…"}`, a shape older payloads used.
    private static func legacyNestedId(in payload: [AnyHashable: Any]) -> String? {
        (payload[Keys.id] as? [String: Any]).flatMap { string($0[Keys.id]) }
    }

    /// A non-empty string, or a number written as one: APNs carries the JSON types the server sent.
    private static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String:
            return text.isEmpty ? nil : text
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }
}
