//
//  Rees46+Bridge.swift
//  REES46
//
//  What the Flutter and React Native bridges need from the native SDK and apps should not use
//  (`sdk/core/README.md`, "Мосты"): behind `@_spi(Bridge)`, out of the API an app sees. A bridge
//  imports it with `@_spi(Bridge) import REES46`. The names follow Android's `@BridgeApi`.
//
//  The rest of what a bridge needs is public: `state` and `onStateChange` (the current state at once,
//  then each change, on the main thread), `sessionId`, `flush`, `release`, `Rees46.handlePush` with
//  `Rees46.PushEvent` and `Rees46.setPushCallbacks`.
//

import Foundation

@_spi(Bridge)
extension Rees46 {

    /// `listener` hears every push event the SDK handles, of every shop, on the main thread, beside the
    /// app's `PushCallbacks` and whatever they are: once per event of a message, like them, with the
    /// shop the push went to in `PushPayload.shopId`. Until the handle is cancelled.
    @discardableResult
    public static func onPushEvent(_ listener: @escaping (Rees46.PushEvent, Rees46.PushPayload) -> Void) -> Cancellable {
        PushCenter.addEventListener(listener)
    }

    /// `listener` hears every new push token the SDK gets from APNs or FCM, once per token and provider
    /// in the process, on the main thread, beside the app's `onToken` — and first, at once, the
    /// device's tokens the SDK already has, one per provider. A token it heard first is not heard again
    /// when APNs or FCM hands it over later, and one that comes while it subscribes is heard once.
    /// Until the handle is cancelled.
    @discardableResult
    public static func onPushToken(_ listener: @escaping (Rees46.PushToken) -> Void) -> Cancellable {
        PushCenter.addTokenListener(listener) { DeviceStore.shared.deviceTokens }
    }

    /**
     The whole `Rees46.SdkError` — its type, HTTP code and `serverCode` — behind the old `SdkError` an
     existing method gives its completion, so a bridge hands Dart and JavaScript the error the core had:
     a shop that refused is `shopBlocked`, an answer outside `2xx` `http(code:serverCode:)`, a request
     `release()` cut off `cancelled`, and only an argument the SDK refuses `invalidArgument`.

     Every old method keeps calling its completion with the old `SdkError`; while the SDK calls it,
     `currentError()` is the error behind it, on that thread — the completion of `Rees46.initialize`
     too. A completion that reaches the app later, on another thread, loses it: `error(of:)` then makes
     one from the old error.

     ```swift
     sdk.recommend(blockId: id, completion: Rees46.BridgeErrors.completion { result in … })
     Rees46.initialize(config, completion: Rees46.BridgeErrors.completion { error in … })
     ```
     */
    public enum BridgeErrors {

        /// The error behind the old one the SDK is handing to a completion on this thread; `nil` outside
        /// one.
        public static func currentError() -> Rees46.SdkError? {
            CurrentError.current
        }

        /// The error of an old `SdkError` the SDK is handing over: `currentError()` when it is known,
        /// otherwise one made from `legacy` — `network` offline, `decoding` for an answer the SDK could
        /// not take, `notInitialized`, `shopBlocked` for a refused shop, `invalidArgument` with the
        /// message of another `.custom`, `timeout` otherwise.
        public static func error(of legacy: REES46.SdkError) -> Rees46.SdkError {
            currentError() ?? SimplePersonalizationSDK.newCoreError(legacy)
        }

        /// A completion for any old method that reports the whole result to `onResult`, once, on the
        /// thread the SDK answers on.
        public static func completion<T>(_ onResult: @escaping (Result<T, Rees46.SdkError>) -> Void) -> (Result<T, REES46.SdkError>) -> Void {
            { result in
                onResult(result.mapError { error(of: $0) })
            }
        }

        /// A completion for an old method that reports only an error — `Rees46.initialize` — that hands
        /// `onError` the whole error, or `nil` for none, once, on the thread the SDK answers on.
        public static func completion(_ onError: @escaping (Rees46.SdkError?) -> Void) -> (REES46.SdkError?) -> Void {
            { legacy in
                onError(legacy.map { error(of: $0) })
            }
        }
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// Calls `listener` on the main thread with every new session id (`sid`) until the handle is
    /// cancelled, so a bridge tells its app instead of asking for `sessionId` on a timer. With
    /// `Rees46Config.coreV2` each `sid` an `/init` brings; on the old core the one
    /// `deleteUserCredentials()` makes. Another conformer of the protocol tells nothing.
    @discardableResult
    public func onSessionChange(_ listener: @escaping (String) -> Void) -> Cancellable {
        guard let instance = self as? SimplePersonalizationSDK else { return .noop }
        return instance.onSessionChange(listener)
    }

    /// The instance's own push callbacks (`notifications.setCallbacks` of the contract): they win over
    /// `Rees46.setPushCallbacks`, one by one, for the pushes of this shop and the tokens its
    /// `NotificationService` gets; on the main thread. A new call replaces them, `nil` removes them.
    public func setPushCallbacks(_ callbacks: Rees46.PushCallbacks?) {
        (self as? SimplePersonalizationSDK)?.setPushCallbacks(callbacks)
    }

    /**
     The push token the bridge's messaging got (`notifications.setPushToken` of the contract): `apns` or
     `fcm` — `hms` is not a provider of iOS. It goes to the shop by the rules of the SDK's own token
     (`sdk/core/push.md`). `completion` hears once, on the main thread: success once the token went —
     also when it went within the week, so nothing goes, and when it waited for the device id and went
     once `/init` brought one: waiting is no failure —, or the whole error: `invalidArgument` for an
     empty token or a provider of another platform, `notInitialized`, `http(code:serverCode:)`,
     `network`, `timeout`. A token that waits for the device id and is replaced by a newer one before it
     goes — the device's token changed — hears the answer of the newer one.

     The old `setPushTokenNotification` keeps telling the app at once that the token waits for the
     device id, as it always has; on `Rees46Config.coreV2` it, too, hears the answer once it went.
     */
    public func setPushToken(_ token: Rees46.PushToken, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        let finish: (Result<Void, REES46.SdkError>) -> Void = { result in
            let mapped = result.mapError { Rees46.BridgeErrors.error(of: $0) }
            DispatchQueue.main.async { completion(mapped) }
        }
        guard let instance = self as? SimplePersonalizationSDK else {
            setPushTokenNotification(token: token.token, isFirebaseNotification: token.provider == .fcm, completion: finish)
            return
        }
        guard instance.usesCoreV2 else {
            guard !token.token.isEmpty, token.provider.iosPlatform != nil else {
                let what = token.token.isEmpty ? "the push token must not be empty" : "\(token.provider.rawValue) is not a provider of iOS"
                CurrentError.with(.invalidArgument(what)) { finish(.failure(.custom(error: what))) }
                return
            }
            instance.pushTokenService.setPushToken(token: token.token, isFirebaseNotification: token.provider == .fcm, whenSent: finish)
            return
        }
        instance.submitPushToken(token, completion: finish)
    }

    /**
     An event through the instance's queue (`sdk/core/queue.md`), as the tracking methods send theirs:
     `push`, `push/custom`, `track/stories`, `track/slider` and `popup/showed`. The events of pushes —
     `track/delivered`, `track/opened`, `track/clicked`, `track/closed` — are not taken here: a bridge
     hands its pushes to `Rees46.handlePush`, which finds their shop, sends each event once per message
     and calls the callbacks. `body` holds the event's own fields; the queue adds the device id, the
     session, the source of a `/push` and the time of a `push/custom` when the event goes. The session's
     window moves as for any event.

     `completion` hears once, on the main thread: success once the event is accepted — on disk, the way
     the contract's tracking methods complete —, or `invalidArgument` for an event of a push, another
     path or a body that is not JSON, `notInitialized`, `shopBlocked`. With `Rees46Config.coreV2 =
     false`, which keeps no queue, the event goes at once and `completion` hears the server's answer.
     */
    public func queueEvent(path: String, body: [String: Any], completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        let finish: (Rees46.SdkError?) -> Void = { error in
            DispatchQueue.main.async { completion(error.map { .failure($0) } ?? .success(())) }
        }
        guard !EventQueue.sessionlessPaths.contains(path) else {
            finish(.invalidArgument("\(path) is an event of a push: hand the push to Rees46.handlePush"))
            return
        }
        guard EventQueue.paths.contains(path) else {
            finish(.invalidArgument("\(path) is not an event of the queue"))
            return
        }
        guard let instance = self as? SimplePersonalizationSDK else {
            finish(.notInitialized)
            return
        }
        instance.queueEvent(path: path, body: body, completion: finish)
    }
}

extension SimplePersonalizationSDK {

    /// `queueEvent(path:body:completion:)`: the new core's queue says when it accepted the event; the
    /// old core sends it through its funnel and tells the answer.
    func queueEvent(path: String, body: [String: Any], completion: @escaping (Rees46.SdkError?) -> Void) {
        guard usesCoreV2 else {
            guard !isReleased else {
                completion(.notInitialized)
                return
            }
            var params = body
            params["shop_id"] = params["shop_id"] ?? shopId
            params["did"] = params["did"] ?? deviceId
            params["sid"] = params["sid"] ?? userSeance
            params["seance"] = params["seance"] ?? userSeance
            params["segment"] = params["segment"] ?? segment
            sessionQueue.addOperation {
                self.postRequest(path: path, params: params) { result in
                    switch result {
                    case .success:
                        completion(nil)
                    case .failure(let legacy):
                        completion(Rees46.BridgeErrors.error(of: legacy))
                    }
                }
            }
            return
        }
        _ = enqueueEvent(path: path, body: body, accepted: completion) { _ in }
    }

    /// The new core's name for an old error whose whole error is not known on this thread: the SDK's
    /// own refusals by their text — a refused shop, an instance that is not there —, any other text an
    /// argument the SDK refused.
    static func newCoreError(_ legacy: SdkError) -> Rees46.SdkError {
        switch legacy {
        case .networkOfflineError, .airplaneModeError:
            return .network
        case .decodeError, .invalidResponse, .responseError:
            // An answer the SDK could not take: one it did not read, or one that did not say success.
            return .decoding
        case .initializationFailed:
            return .notInitialized
        case .custom(let message) where message == shopBlockedMessage:
            return .shopBlocked
        case .custom(let message) where message.hasSuffix("SDK is not initialized"):
            return .notInitialized
        case .custom(let message):
            return .invalidArgument(message)
        default:
            return .timeout
        }
    }

    /// The text of the old error of a refused shop (`SdkError.legacy`).
    private static let shopBlockedMessage: String = {
        if case .custom(let message) = SdkError.legacy(.shopBlocked) {
            return message
        }
        return ""
    }()
}
