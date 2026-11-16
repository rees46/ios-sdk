//
//  PushTypes.swift
//  REES46
//
//  The push types of the contract (`sdk/contract/notifications.md`, decision 0004), nested in the
//  facade: the old top-level `PushEvent` stays as it is — new cases in it would break an app's
//  exhaustive `switch` —, and a type of another module with the same name does not clash.
//

import Foundation

extension Rees46 {

    /// What happened to a push. Each event is its own request: `track/delivered`, `track/opened`,
    /// `track/clicked`, `track/closed`. `track/received` is not sent by the new core (decision 0004).
    public enum PushEvent: String, Equatable, CaseIterable {
        /// The push reached the app.
        case delivered
        /// The notification was shown to the user: on iOS, a push that came while the app is active.
        case opened
        /// The user tapped the notification.
        case clicked
        /// The notification was dismissed without a tap (`UNNotificationDismissActionIdentifier`). The
        /// SDK owns no `UNUserNotificationCenter` delegate, so it never sees a dismissal itself: the app
        /// or the bridge that is the delegate calls `Rees46.handlePush(_:event: .closed)` from
        /// `userNotificationCenter(_:didReceive:withCompletionHandler:)`. The system reports a dismissal
        /// only for a notification whose category has `.customDismissAction`; the SDK's carousel
        /// category has none.
        case closed

        /// The address of the event.
        var path: String { "track/" + rawValue }
    }

    /// Whose token it is.
    public enum PushProvider: String, Equatable, CaseIterable {
        case apns
        case fcm
        case hms

        /// `platform` of `POST /mobile_push_tokens` on iOS; `nil` for a provider iOS does not have.
        var iosPlatform: String? {
            switch self {
            case .apns: return "ios"
            case .fcm: return "ios_firebase"
            case .hms: return nil
            }
        }
    }

    /// A push token and its provider.
    public struct PushToken: Equatable {
        public let token: String
        public let provider: PushProvider

        public init(token: String, provider: PushProvider) {
            self.token = token
            self.provider = provider
        }
    }

    /// A button of a notification.
    public struct PushAction: Equatable {
        /// `actions[i].action`.
        public let id: String
        /// `actions[i].title`.
        public let title: String
        /// `action_urls[i]`: the link with the same number, if any.
        public let url: String?
    }

    /// What a push opens (`event.type`): an open set of values — one the SDK does not know comes as it
    /// is.
    public struct PushTargetType: RawRepresentable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let web = PushTargetType(rawValue: "web")
        public static let product = PushTargetType(rawValue: "product")
        public static let category = PushTargetType(rawValue: "category")
        public static let carousel = PushTargetType(rawValue: "carousel")
        public static let custom = PushTargetType(rawValue: "custom")
    }

    /// The data of the mailing's "additional data for the app" field (`event`).
    public struct PushTarget {
        /// `event.type`.
        public let type: PushTargetType
        /// `event.uri`: a link, a product id, a category id or the app's own link.
        public let uri: String
        /// `event.payload`: free data.
        public let payload: [String: Any]
    }

    /// A push of the SDK, parsed. The app opens `target` in `onClicked`: the SDK opens no screen.
    public struct PushPayload {
        /// The shop the push went to.
        public let shopId: String
        /// The message: `id`, in APNs `src.id`.
        public let code: String
        /// The mailing: `bulk`, `chain`, `transactional`, `digest` — `type`, in APNs `src.type`.
        public let type: String
        public let title: String?
        public let body: String?
        /// A link.
        public let icon: String?
        /// A link: `image`, in APNs `image_url`.
        public let image: String?
        /// Empty when the push has no buttons; APNs pushes have none.
        public let actions: [PushAction]
        /// What to open on a tap.
        public let target: PushTarget?
        /// `utm_source` of the mailing.
        public let source: String?
        /// The name of the sound file (`ios_sound_file`).
        public let sound: String?
        /// The whole push as it came; a value that is not a string is written as JSON.
        public let data: [String: String]
    }

    /// The app's callbacks on pushes, on the main thread. Every field is optional. `Rees46.setPushCallbacks`
    /// sets them for every shop; an instance's own callbacks win over those, one by one.
    public struct PushCallbacks {
        /// A push came.
        public var onDelivered: ((PushPayload) -> Void)?
        /// The notification was shown.
        public var onOpened: ((PushPayload) -> Void)?
        /// The notification was tapped.
        public var onClicked: ((PushPayload) -> Void)?
        /// The notification was dismissed without a tap.
        public var onClosed: ((PushPayload) -> Void)?
        /// The SDK got a token from APNs or FCM.
        public var onToken: ((PushToken) -> Void)?

        public init(
            onDelivered: ((PushPayload) -> Void)? = nil,
            onOpened: ((PushPayload) -> Void)? = nil,
            onClicked: ((PushPayload) -> Void)? = nil,
            onClosed: ((PushPayload) -> Void)? = nil,
            onToken: ((PushToken) -> Void)? = nil
        ) {
            self.onDelivered = onDelivered
            self.onOpened = onOpened
            self.onClicked = onClicked
            self.onClosed = onClosed
            self.onToken = onToken
        }

        /// The callback of `event`.
        func callback(for event: PushEvent) -> ((PushPayload) -> Void)? {
            switch event {
            case .delivered: return onDelivered
            case .opened: return onOpened
            case .clicked: return onClicked
            case .closed: return onClosed
            }
        }
    }
}

extension Rees46.PushPayload {

    /// The payload of a push of the SDK for `shopId`; `nil` when the push is not one — no `type` or
    /// `code` — (`sdk/contract/notifications.md`). FCM sends every value as a string, `actions`,
    /// `action_urls` and `event` as JSON strings; APNs sends `src`, `event` and `aps` as objects.
    static func parse(_ payload: [AnyHashable: Any], shopId: String) -> Rees46.PushPayload? {
        guard let (type, code) = PushPayloadParser.typeAndCode(from: payload) else { return nil }
        let alert = PushPayloadParser.dictionary(for: "aps", in: payload).flatMap { aps -> [String: Any]? in
            if let object = aps["alert"] as? [String: Any] {
                return object
            }
            return (aps["alert"] as? String).map { ["body": $0] }
        }
        return Rees46.PushPayload(
            shopId: shopId,
            code: code,
            type: type,
            title: text(payload["title"]) ?? text(alert?["title"]),
            body: text(payload["body"]) ?? text(alert?["body"]),
            icon: text(payload["icon"]),
            image: text(payload["image"]) ?? text(payload["image_url"]),
            actions: actions(in: payload),
            target: target(in: payload),
            source: text(payload["source"]),
            sound: text(payload["ios_sound_file"]),
            data: strings(payload)
        )
    }

    private static func text(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string.isEmpty ? nil : string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    /// A list sent as a list or as a JSON string.
    private static func list(_ value: Any?) -> [Any] {
        if let array = value as? [Any] {
            return array
        }
        guard let string = value as? String, let data = string.data(using: .utf8),
              let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
            return []
        }
        return array
    }

    private static func actions(in payload: [AnyHashable: Any]) -> [Rees46.PushAction] {
        let urls = list(payload["action_urls"]).map { text($0) }
        return list(payload["actions"]).enumerated().compactMap { index, item in
            guard let action = item as? [String: Any], let id = text(action["action"]) else { return nil }
            return Rees46.PushAction(id: id, title: text(action["title"]) ?? "", url: index < urls.count ? urls[index] : nil)
        }
    }

    private static func target(in payload: [AnyHashable: Any]) -> Rees46.PushTarget? {
        guard let event = PushPayloadParser.event(from: payload), let type = text(event["type"]) else { return nil }
        return Rees46.PushTarget(
            type: Rees46.PushTargetType(rawValue: type),
            uri: text(event["uri"]) ?? "",
            payload: event["payload"] as? [String: Any] ?? [:]
        )
    }

    /// The push as strings: a value that is not one is written as JSON, or described when it is not JSON.
    private static func strings(_ payload: [AnyHashable: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in payload {
            let name = (key as? String) ?? String(describing: key)
            if let string = value as? String {
                result[name] = string
            } else if let number = value as? NSNumber {
                result[name] = number.stringValue
            } else if SafeJSON.isValid(value), let data = SafeJSON.data(value), let json = String(data: data, encoding: .utf8) {
                result[name] = json
            } else {
                result[name] = String(describing: value)
            }
        }
        return result
    }
}
