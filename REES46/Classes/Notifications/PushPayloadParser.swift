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
 legacy `NotificationService` share one parsing story. Mirrors what `NotificationService` extracted
 inline before; the accepted payload shapes are unchanged (a top-level `type`/`id`, an `event` JSON
 string carrying `type`, or a nested `src`/`id` dictionary).
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
        payload[Keys.shopId] as? String
    }

    /// The `(type, code)` a track call needs, or `nil` when the payload is not an SDK push.
    static func typeAndCode(from payload: [AnyHashable: Any]) -> (type: String, code: String)? {
        let id = value(for: Keys.id, in: payload)

        if let eventJSON = dictionary(for: Keys.event, in: payload),
           let eventType = eventJSON[Keys.type] as? String {
            if let id = id {
                return (eventType, id)
            }
            if let srcID = payload[Keys.id] as? [String: Any],
               let value = srcID[Keys.id] as? String {
                return (eventType, value)
            }
        }

        if let type = value(for: Keys.type, in: payload), let id = id {
            return (type, id)
        }
        return nil
    }

    /// A string value under `key`, looked up at the top level and then inside a `src` JSON string.
    private static func value(for key: String, in payload: [AnyHashable: Any]) -> String? {
        if let value = payload[key] as? String {
            return value
        }
        if let src = dictionary(for: Keys.src, in: payload),
           let value = src[key] as? String {
            return value
        }
        return nil
    }

    /// Parses a JSON-string field into a dictionary; `nil` on a missing field or malformed JSON.
    private static func dictionary(for key: String, in payload: [AnyHashable: Any]) -> [String: Any]? {
        guard let jsonString = payload[key] as? String,
              let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any]
        else { return nil }
        return dict
    }
}
