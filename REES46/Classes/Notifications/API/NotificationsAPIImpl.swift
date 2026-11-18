//
//  NotificationsAPIImpl.swift
//  REES46
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

/// The `notifications` namespace of one instance, over its push machinery: the queue of the new core
/// for the events, the device's token and its week for `setPushToken`, the instance's callbacks.
///
/// As the other namespaces (`NamespaceRequests`): on an instance of the old core every method ends as
/// `notInitialized`, sends nothing and logs `core_flag_mismatch`; on a conformer of `PersonalizationSDK`
/// other than the SDK's own it ends the same way and logs `not_implemented`.
struct NotificationsAPIImpl: NotificationsAPI {

    private weak var instance: SimplePersonalizationSDK?
    /// Whether it was made for the SDK's own instance: once that is gone, a call is `notInitialized`.
    private let isTheSdks: Bool
    /// The requests of the server method `getHistory`.
    let requests: NamespaceRequests

    init(_ sdk: PersonalizationSDK) {
        instance = sdk as? SimplePersonalizationSDK
        isTheSdks = instance != nil
        requests = NamespaceRequests(sdk)
    }

    // MARK: - Events

    func trackDelivered(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        track(.delivered, code: code, type: type, completion: completion)
    }

    func trackOpened(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        track(.opened, code: code, type: type, completion: completion)
    }

    func trackClicked(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        track(.clicked, code: code, type: type, completion: completion)
    }

    func trackClosed(code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        track(.closed, code: code, type: type, completion: completion)
    }

    func trackDelivered(code: String, type: String) async throws {
        try await Self.awaiting { trackDelivered(code: code, type: type, completion: $0) }
    }

    func trackOpened(code: String, type: String) async throws {
        try await Self.awaiting { trackOpened(code: code, type: type, completion: $0) }
    }

    func trackClicked(code: String, type: String) async throws {
        try await Self.awaiting { trackClicked(code: code, type: type, completion: $0) }
    }

    func trackClosed(code: String, type: String) async throws {
        try await Self.awaiting { trackClosed(code: code, type: type, completion: $0) }
    }

    /// `event` of the message `code` through the instance's queue, once per message in the process.
    private func track(_ event: Rees46.PushEvent, code: String, type: String, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        let name = Self.callName(of: event)
        let finish = Self.onMain(completion)
        guard let instance = onTheNewCore(name) else {
            finish(.failure(.notInitialized))
            return
        }
        if let refusal = Self.refusal(code: code, type: type) {
            instance.logger.warning(LogCode.invalidArgument, "\(name): \(refusal.message)", ["call": name])
            finish(.failure(refusal))
            return
        }
        instance.queuePushEvent(event, type: type, code: code) { error in
            finish(error.map { .failure($0) } ?? .success(()))
        }
    }

    /// The name of `event`'s method, as the log calls it: `notifications.trackDelivered`.
    static func callName(of event: Rees46.PushEvent) -> String {
        "notifications.track" + event.rawValue.prefix(1).uppercased() + event.rawValue.dropFirst()
    }

    /// Why the event of `code` and `type` is not sent: either is blank (`sdk/contract/notifications.md`).
    static func refusal(code: String, type: String) -> Rees46.SdkError? {
        if ApiArguments.isBlank(code) {
            return .invalidArgument("the code of the push must not be empty")
        }
        if ApiArguments.isBlank(type) {
            return .invalidArgument("the type of the push must not be empty")
        }
        return nil
    }

    // MARK: - The token

    func getPushToken(provider: Rees46.PushProvider?) -> Rees46.PushToken? {
        guard let instance = onTheNewCore("notifications.getPushToken"), !instance.isReleased else { return nil }
        if let provider = provider {
            return Self.token(of: provider, on: instance)
        }
        // The provider whose token this shop sent last; without one, the device's last token.
        let lastSent = Rees46.PushProvider.allCases
            .compactMap { provider in
                provider.iosPlatform.flatMap(instance.storage.pushTokenSent(platform:)).map { (provider, $0.at) }
            }
            .max { $0.1 < $1.1 }
        return lastSent.flatMap { Self.token(of: $0.0, on: instance) } ?? instance.deviceStore.deviceToken
    }

    /// The device's token of `provider`, or the one the shop of `instance` sent.
    private static func token(of provider: Rees46.PushProvider, on instance: SimplePersonalizationSDK) -> Rees46.PushToken? {
        if let token = instance.deviceStore.deviceToken(provider) {
            return token
        }
        return provider.iosPlatform
            .flatMap(instance.storage.pushTokenSent(platform:))
            .map { Rees46.PushToken(token: $0.token, provider: provider) }
    }

    func setPushToken(_ token: String, provider: Rees46.PushProvider, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        let name = "notifications.setPushToken"
        guard let instance = onTheNewCore(name) else {
            Self.onMain(completion)(.failure(.notInitialized))
            return
        }
        if let refusal = Self.refusal(token: token, provider: provider) {
            instance.logger.warning(LogCode.invalidArgument, "\(name): \(refusal.message)", ["call": name])
            Self.onMain(completion)(.failure(refusal))
            return
        }
        // The bridges' way of a token they got: its whole error, on the main thread.
        instance.setPushToken(Rees46.PushToken(token: token, provider: provider), completion: completion)
    }

    func setPushToken(_ token: String, provider: Rees46.PushProvider) async throws {
        try await Self.awaiting(endsOnCancel: true) { setPushToken(token, provider: provider, completion: $0) }
    }

    /// Why `token` of `provider` is not taken: it is empty, or the provider is not one of iOS.
    static func refusal(token: String, provider: Rees46.PushProvider) -> Rees46.SdkError? {
        if token.isEmpty {
            return .invalidArgument("the push token must not be empty")
        }
        if provider.iosPlatform == nil {
            return .invalidArgument("\(provider.rawValue) is not a provider of iOS")
        }
        return nil
    }

    // MARK: - Callbacks

    func setCallbacks(_ callbacks: Rees46.PushCallbacks) {
        onTheNewCore("notifications.setCallbacks")?.setPushCallbacks(callbacks)
    }

    // MARK: - The instance

    /// The instance, when the method `name` may run on it: the SDK's own, on the new core.
    private func onTheNewCore(_ name: String) -> SimplePersonalizationSDK? {
        NamespaceRequests.onTheNewCore(instance, isTheSdks: isTheSdks, call: name)
    }

    // MARK: - completion and async

    /// `completion`, called once, on the main thread.
    static func onMain(_ completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) -> (Result<Void, Rees46.SdkError>) -> Void {
        let once = Once()
        return { result in
            guard once.take() else { return }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// The `async` form of a method with `completion` (`start`): returns or throws its result. A task
    /// cancelled before the call throws `cancelled` and does not start it. `endsOnCancel`: cancelling the
    /// task while the call goes on ends the wait as `cancelled` too — for a call that may wait long, as
    /// a token waits for the device id; the call itself goes on.
    static func awaiting(
        endsOnCancel: Bool = false,
        _ start: (@escaping (Result<Void, Rees46.SdkError>) -> Void) -> Void
    ) async throws {
        guard !_Concurrency.Task.isCancelled else {
            throw Rees46.SdkError.cancelled
        }
        let outcome = Outcome()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                outcome.wait(continuation)
                start { outcome.finish($0) }
            }
        } onCancel: {
            if endsOnCancel {
                outcome.finish(.failure(.cancelled))
            }
        }
    }

    /// The first result of a call and who waits for it: the waiting `async` call resumes once, with
    /// the first of the result and the cancellation.
    private final class Outcome {
        private let lock = NSLock()
        private var result: Result<Void, Rees46.SdkError>?
        private var continuation: CheckedContinuation<Void, Error>?

        func wait(_ continuation: CheckedContinuation<Void, Error>) {
            lock.lock()
            guard let result = result else {
                self.continuation = continuation
                lock.unlock()
                return
            }
            lock.unlock()
            continuation.resume(with: result)
        }

        func finish(_ result: Result<Void, Rees46.SdkError>) {
            lock.lock()
            guard self.result == nil else {
                lock.unlock()
                return
            }
            self.result = result
            let waiting = continuation
            continuation = nil
            lock.unlock()
            waiting?.resume(with: result)
        }
    }

    /// `true` the first time only.
    private final class Once {
        private let lock = NSLock()
        private var taken = false

        func take() -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard !taken else { return false }
            taken = true
            return true
        }
    }
}
