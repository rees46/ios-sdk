//
//  SimplePersonalizationSDK+Push.swift
//  REES46
//
//  An instance's pushes (`sdk/core/push.md`, `sdk/contract/notifications.md`): the events `handlePush`
//  routes to it, the old tracking methods of pushes, and the new core's push token.
//

import Foundation

extension SimplePersonalizationSDK {

    // MARK: - Events

    /// A push `Rees46.handlePush` routed to this shop.
    ///
    /// - The new core sends each event once per message in the process, through the queue —
    ///   `track/delivered`, `track/opened`, `track/clicked`, `track/closed`; never `track/received`,
    ///   which becomes `delivered` — and a click stores the push as the source of the next `/push`
    ///   events for 48 hours. A repeat sends nothing and calls no callback. The app's callback and the
    ///   bridges' listeners hear the event once the queue accepted it — on disk —, and not at all when
    ///   it did not: a released instance, a refused shop.
    /// - The old core sends exactly what it always has: `delivered`, `received` and `clicked`, at once;
    ///   `opened` and `closed`, which it never had, send nothing. The callback is called at once.
    ///
    /// On both cores the callback is the instance's own, else the facade's. A released instance takes
    /// nothing — `release()` came while the push was routed to it —: `notTaken` runs, and the facade
    /// hands the push on (`Rees46.rerouteReleased`).
    func receivePush(_ route: PushRoute, type: String, code: String, payload: [AnyHashable: Any], notTaken: @escaping () -> Void = {}) {
        guard !isReleased else {
            notTaken()
            return
        }
        let parsed = Rees46.PushPayload.parse(payload, shopId: shopId)
        guard usesCoreV2 else {
            switch route {
            case .event(.delivered):
                notificationDelivered(type: type, code: code) { _ in }
            case .event(.clicked):
                notificationClicked(type: type, code: code) { _ in }
            case .received:
                notificationReceived(type: type, code: code) { _ in }
            case .event(.opened), .event(.closed):
                break
            }
            // The old `received` is a `delivered` the old core reports twice: no callback of its own.
            if case .event(let event) = route, let parsed = parsed {
                PushCenter.notify(event, payload: parsed, instance: pushCallbackBox.callbacks)
            }
            return
        }
        let event = route.newCoreEvent
        guard PushCenter.reserve(event, code: code, shopId: shopId) else {
            logger.debug(LogCode.pushReceived, "the push event was handled already in this launch", ["event": event.rawValue, "repeat": "true"])
            return
        }
        let callbacks = pushCallbackBox
        enqueuePushEvent(event, type: type, code: code, completion: nil, notTaken: notTaken) {
            if let parsed = parsed {
                PushCenter.notify(event, payload: parsed, instance: callbacks.callbacks)
            }
        }
    }

    /// The old tracking methods of pushes on the new core — `notificationDelivered`,
    /// `notificationReceived` (sent as `delivered`), `notificationClicked`: through the queue, once per
    /// message, a click storing the source. `completion` hears the server's answer once the event went,
    /// as the tracking methods do; a repeat succeeds at once, an empty `code` or `type` fails at once.
    /// They call no app callback: the app knows of the event.
    func trackPushEvent(path: String, type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        let event = path == "track/received" ? .delivered : (Rees46.PushEvent(rawValue: String(path.dropFirst("track/".count))) ?? .delivered)
        let later: (Result<Void, SdkError>, Rees46.SdkError?) -> Void = { result, error in
            DispatchQueue.global(qos: .utility).async { CurrentError.with(error) { completion(result) } }
        }
        guard !Self.isBlank(code), !Self.isBlank(type) else {
            let what = "\(event.path): the code and the type of the push must not be empty"
            logger.warning(LogCode.invalidArgument, what, ["reason": "empty"])
            later(.failure(.legacy(.invalidArgument(what))), .invalidArgument(what))
            return
        }
        guard PushCenter.reserve(event, code: code, shopId: shopId) else {
            later(.success(()), nil)
            return
        }
        enqueuePushEvent(event, type: type, code: code, completion: completion)
    }

    /// The event into the shop's queue (`sdk/core/queue.md`), its message reserved by the caller
    /// (`PushCenter.reserve`): it counts as sent once the queue accepted it, and `onAccepted` runs
    /// then; a queue that does not take it — a released instance, a refused shop — frees it, so the
    /// event may go when it comes again, and `notTaken` hears a released instance's. A click stores the
    /// push as the source of the `/push` events of the next 48 hours, when its type is a source
    /// (`TrackingSourceType`).
    private func enqueuePushEvent(
        _ event: Rees46.PushEvent,
        type: String,
        code: String,
        completion: ((Result<Void, SdkError>) -> Void)?,
        notTaken: (() -> Void)? = nil,
        onAccepted: @escaping () -> Void = {}
    ) {
        if event == .clicked, let source = TrackingSourceType(rawValue: type) {
            sourceStore.store(type: source.rawValue, code: code)
        }
        let shopId = self.shopId
        let accepted: (Rees46.SdkError?) -> Void = { error in
            guard error == nil else {
                PushCenter.release(event, code: code, shopId: shopId)
                if error == .notInitialized {
                    notTaken?()
                }
                return
            }
            PushCenter.confirm(event, code: code, shopId: shopId)
            onAccepted()
        }
        _ = enqueueEvent(path: event.path, body: ["code": code, "type": type], accepted: accepted) { result in
            completion?(result.map { _ in () })
        }
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Callbacks

    /// The instance's own push callbacks: they win over the facade's, one by one; `nil` removes them.
    func setPushCallbacks(_ callbacks: Rees46.PushCallbacks?) {
        pushCallbackBox.callbacks = callbacks
    }

    // MARK: - The new core's push token

    /// The new core takes a push token (`sdk/core/push.md`): it becomes the device's token, kept for
    /// every shop, and goes to this shop — at once when it is new to it, at most once a week when it
    /// is not, never without a device id: until `/init` stores one it waits, which is no failure —
    /// `completion` hears the answer once it went. `platform` is `ios` for APNs and `ios_firebase` for
    /// FCM. `apnsData` is the APNs token as the system gave it: kept where the old core reads it.
    func submitPushToken(_ token: Rees46.PushToken, apnsData: Data? = nil, completion: ((Result<Void, SdkError>) -> Void)?) {
        // Off the caller's thread, with the whole error for the bridges (`Rees46.BridgeErrors`).
        let finish: (Result<Void, SdkError>, Rees46.SdkError?) -> Void = { result, error in
            guard let completion = completion else { return }
            DispatchQueue.global(qos: .utility).async { CurrentError.with(error) { completion(result) } }
        }
        guard !isReleased else {
            finish(.failure(.legacy(.notInitialized)), .notInitialized)
            return
        }
        guard !token.token.isEmpty, let platform = token.provider.iosPlatform else {
            let what = token.token.isEmpty ? "the push token must not be empty" : "\(token.provider.rawValue) is not a provider of iOS"
            logger.warning(LogCode.invalidArgument, "the push token was not taken: \(what)", ["reason": token.token.isEmpty ? "empty" : "wrong_provider"])
            finish(.failure(.legacy(.invalidArgument(what))), .invalidArgument(what))
            return
        }
        // Released meanwhile: nothing is written.
        guard !isReleased else {
            finish(.failure(.legacy(.notInitialized)), .notInitialized)
            return
        }
        if let data = apnsData {
            deviceStore.pushToken = data
        }
        deviceStore.deviceToken = token
        guard !deviceId.isEmpty else {
            // Waiting is no failure: the caller hears the answer once the token went.
            deferPushToken(apnsData.map { .device($0) } ?? .direct(token: token.token, isFirebase: token.provider == .fcm), waiter: completion)
            return
        }
        sendPushToken(token.token, platform: platform, completion: finish)
    }

    /// After an `/init` answer: each of the device's tokens — APNs and FCM — goes to this shop when its
    /// own week allows; a provider in `except` had a token of its own sent just now.
    func sendDevicePushToken(except sent: Set<Rees46.PushProvider> = []) {
        for token in deviceStore.deviceTokens where !sent.contains(token.provider) {
            guard let platform = token.provider.iosPlatform else { continue }
            sendPushToken(token.token, platform: platform) { _, _ in }
        }
    }

    /// `POST /mobile_push_tokens` of `token` by the week of its platform (`PushTokenWeek`): marked on its
    /// way first, counted once it went, freed when it failed; a second send of it meanwhile hears this
    /// one's answer. The customer it was marked for: a `deleteUserCredentials()` before it goes cancels
    /// it, and the next customer's `/init` sends it again.
    private func sendPushToken(_ token: String, platform: String, completion: @escaping (Result<Void, SdkError>, Rees46.SdkError?) -> Void) {
        let clock = environment.clock
        let claim: PushTokenWeek.Claim
        switch PushTokenWeek.claim(token, platform: platform, storage: storage, now: clock.now(), completion: completion) {
        case .send(let marked):
            claim = marked
        case .sentRecently:
            logger.debug(LogCode.pushTokenSkipped, "the push token went to the shop within the last week", ["reason": "sent_recently"])
            completion(.success(()), nil)
            return
        case .joined:
            // The send on its way answers for both.
            return
        case .markedElsewhere:
            // Another launch's send of it is on its way: for this shop it went, as far as the week knows.
            logger.debug(LogCode.pushTokenSkipped, "a send of the push token began less than five minutes ago", ["reason": "sent_recently"])
            completion(.success(()), nil)
            return
        }
        let generation = currentInitGeneration()
        var request = CoreRequest(method: .post, path: "mobile_push_tokens", body: ["token": token, "platform": platform])
        request.identity = { [weak self] in self?.identity(ifCurrent: generation) }
        let logger = self.logger
        core.send(request) { response in
            let sent: Bool
            if case .success = response.result {
                sent = true
            } else {
                sent = false
            }
            let joined = PushTokenWeek.finish(claim, sent: sent, at: clock.now())
            let result: Result<Void, SdkError> = response.result.map { _ in () }
            switch response.result {
            case .success:
                logger.info(LogCode.pushTokenSent, "the push token was sent")
            case .failure(let error):
                logger.warning(LogCode.pushTokenFailed, "the push token was not sent", ["error": error.logKind])
            }
            completion(result, response.error)
            joined.forEach { $0(result, response.error) }
        }
    }
}
