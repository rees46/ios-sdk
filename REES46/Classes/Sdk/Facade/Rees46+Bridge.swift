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
    /// device's token the SDK already has. Until the handle is cancelled.
    @discardableResult
    public static func onPushToken(_ listener: @escaping (Rees46.PushToken) -> Void) -> Cancellable {
        PushCenter.addTokenListener(listener, current: DeviceStore.shared.deviceToken)
    }

    /**
     The whole `Rees46.SdkError` — its type, HTTP code and `serverCode` — behind the old `SdkError` an
     existing method gives its completion, so a bridge hands Dart and JavaScript the error the core had.

     Every old method keeps calling its completion with the old `SdkError`; while the SDK calls it,
     `currentError()` is the error behind it, on that thread. A completion that reaches the app later,
     on another thread, loses it: `error(of:)` then makes one from the old error.

     ```swift
     sdk.recommend(blockId: id, completion: Rees46.BridgeErrors.completion { result in … })
     ```
     */
    public enum BridgeErrors {

        /// The error behind the old one the SDK is handing to a completion on this thread; `nil` outside
        /// one.
        public static func currentError() -> Rees46.SdkError? {
            CurrentError.current
        }

        /// The error of an old `SdkError` the SDK is handing over: `currentError()` when it is known,
        /// otherwise one made from `legacy` — `network` offline, `decoding`, `notInitialized`,
        /// `invalidArgument` with the message of `.custom`, `timeout` for an answer that did not come.
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
     An event through the instance's queue (`sdk/core/queue.md`), as the tracking methods send theirs:
     `push`, `push/custom`, `track/stories`, `track/slider`, `popup/showed` and the push events
     `track/delivered`, `track/opened`, `track/clicked`, `track/closed`. `body` holds the event's own
     fields; the queue adds the device id, the session, the source of a `/push` and the time of a
     `push/custom` when the event goes. The session's window moves as for any event.

     `completion` hears once, on the main thread: success once the event is accepted — on disk, the way
     the contract's tracking methods complete —, or `invalidArgument` for another path or a body that is
     not JSON, `notInitialized`, `shopBlocked`. With `Rees46Config.coreV2 = false`, which keeps no
     queue, the event goes at once and `completion` hears the server's answer.
     */
    public func queueEvent(path: String, body: [String: Any], completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        let finish: (Rees46.SdkError?) -> Void = { error in
            DispatchQueue.main.async { completion(error.map { .failure($0) } ?? .success(())) }
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

    /// The new core's name for an old error the core did not classify.
    static func newCoreError(_ legacy: SdkError) -> Rees46.SdkError {
        switch legacy {
        case .networkOfflineError, .airplaneModeError:
            return .network
        case .decodeError:
            return .decoding
        case .initializationFailed:
            return .notInitialized
        case .custom(let message):
            return .invalidArgument(message)
        default:
            return .timeout
        }
    }
}
