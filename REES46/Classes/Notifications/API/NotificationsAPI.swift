//
//  NotificationsAPI.swift
//  REES46
//
//  The `notifications` namespace of the contract (`sdk/contract/notifications.md`): the push token and
//  the events of pushes, over the push machinery of the new core (`sdk/core/push.md`).
//

import Foundation

/**
 Mobile pushes of one shop: the events of a push the app or the bridge parses itself, the device's push
 token, and the shop's push callbacks. A push the SDK should parse goes to `Rees46.handlePush`, which
 finds its shop and sends the event for it.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized`, sends nothing and sets nothing; `getPushToken` gives `nil`.
 */
@_spi(Bridge)
public protocol NotificationsAPI {

    /**
     The push came to the app (`POST track/delivered`), for an app that parses its pushes itself.
     `code` is the push's `id`, `type` its `type` — `bulk`, `chain`, `transactional` or `digest` —, both
     required and not blank.

     The event goes through the shop's queue, as `tracking` events go, with the shop and the device id;
     an event of one message goes once per process — a repeat, or one `Rees46.handlePush` sent before,
     sends nothing and succeeds. No push callback is called: the app knows of the event.

     `completion` is called once, on the main thread: success once the queue took the event — it does
     not wait for the network, and no network error comes —, or `invalidArgument` for a blank `code` or
     `type`, `notInitialized` on the old core or after `release()`, `shopBlocked`.
     */
    func trackDelivered(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    /// The notification was shown to the user (`POST track/opened`), as `trackDelivered(code:type:completion:)`.
    func trackOpened(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    /// The user tapped the notification (`POST track/clicked`), as `trackDelivered(code:type:completion:)`.
    /// The push also becomes the source of the shop's `/push` events for 48 hours, as
    /// `tracking.setSource` would make it, when its `type` is a `TrackingSourceType`.
    func trackClicked(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    /// The notification was dismissed without a tap (`POST track/closed`), as
    /// `trackDelivered(code:type:completion:)`.
    func trackClosed(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    /// `trackDelivered(code:type:completion:)` for `async` code: throws the `Rees46.SdkError`; a task
    /// cancelled before the call sends nothing and throws `cancelled`.
    func trackDelivered(code: String, type: String) async throws

    /// `trackOpened(code:type:completion:)` for `async` code, as `trackDelivered(code:type:)`.
    func trackOpened(code: String, type: String) async throws

    /// `trackClicked(code:type:completion:)` for `async` code, as `trackDelivered(code:type:)`.
    func trackClicked(code: String, type: String) async throws

    /// `trackClosed(code:type:completion:)` for `async` code, as `trackDelivered(code:type:)`.
    func trackClosed(code: String, type: String) async throws

    /**
     The push token the SDK keeps, from its storage, without the network: the device's token of
     `provider`, or — `nil` — the one of the provider whose token this shop sent last, and while it sent
     none, the last token the SDK got from APNs or FCM or was given. `nil` when there is none: on iOS
     `hms` never has one. The token is the device's: every shop of the app sends the same one.
     */
    func getPushToken(provider: Rees46.PushProvider?) -> Rees46.PushToken?

    /**
     The push token the app or the bridge got itself (`POST mobile_push_tokens`): `apns` goes as
     `platform=ios`, `fcm` as `platform=ios_firebase`. It becomes the device's token and goes to this
     shop by the rules of the token the SDK gets itself (`sdk/core/push.md`): a new token at once, the
     same one at most once a week, never without a device id — until `/init` brings one it waits.

     `completion` is called once, on the main thread: success once the server took the token — also
     when it went within the week, and nothing goes —, or `invalidArgument` for an empty token or `hms`,
     which iOS does not have, `notInitialized` on the old core or after `release()`, `shopBlocked`,
     `network`, `timeout`, `http(code:serverCode:)` — `400` for a token the server refuses, `403` or `404`
     with an empty body for a shop it does not serve —, `decoding` for a `2xx` whose body says
     `{"status": "error"}`.
     */
    func setPushToken(_ token: String, provider: Rees46.PushProvider, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    /// `setPushToken(_:provider:completion:)` for `async` code: throws the `Rees46.SdkError`. Cancelling
    /// the task ends the wait as `cancelled`; the SDK keeps the token and sends it as it would.
    func setPushToken(_ token: String, provider: Rees46.PushProvider) async throws

    /**
     The shop's own push callbacks: they win over `Rees46.setPushCallbacks`, one by one, for the pushes
     of this shop the SDK sees — its `NotificationService` and `Rees46.handlePush` — and the tokens it
     gets; on the main thread. A new call replaces them; `PushCallbacks()` without fields removes them.
     The `track…` methods call none of them.
     */
    func setCallbacks(_ callbacks: Rees46.PushCallbacks)
}

@_spi(Bridge)
extension NotificationsAPI {

    /// `trackDelivered(code:type:completion:)` without a completion.
    public func trackDelivered(code: String, type: String) {
        trackDelivered(code: code, type: type, completion: { _ in })
    }

    /// `trackOpened(code:type:completion:)` without a completion.
    public func trackOpened(code: String, type: String) {
        trackOpened(code: code, type: type, completion: { _ in })
    }

    /// `trackClicked(code:type:completion:)` without a completion.
    public func trackClicked(code: String, type: String) {
        trackClicked(code: code, type: type, completion: { _ in })
    }

    /// `trackClosed(code:type:completion:)` without a completion.
    public func trackClosed(code: String, type: String) {
        trackClosed(code: code, type: type, completion: { _ in })
    }

    /// `getPushToken(provider:)` of the last token the SDK got or was given.
    public func getPushToken() -> Rees46.PushToken? {
        getPushToken(provider: nil)
    }

    /// `setPushToken(_:provider:completion:)` without a completion.
    public func setPushToken(_ token: String, provider: Rees46.PushProvider) {
        setPushToken(token, provider: provider, completion: { _ in })
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The shop's push token, events of pushes and push callbacks (`NotificationsAPI`): on the new core
    /// only.
    public var notifications: NotificationsAPI {
        NotificationsAPIImpl(self)
    }
}
