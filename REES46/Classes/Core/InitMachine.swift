//
//  InitMachine.swift
//  REES46
//
//  `/init` on the new core (`sdk/core/init.md`, decisions 0002 and 1 of the core's brief): the
//  instance's states, retries after a pause, the shop's refusal kept on disk, the saved answer as a
//  fallback, and the wait of the calls that return a result.
//

import Foundation

// `_Concurrency.Task`: the module has a `Task` class of its own (the stories image loader).

/// The instance's side of `/init`.
protocol InitMachineDelegate: AnyObject {
    /// The query of the next `/init`, without what the client adds itself (`shop_id`, `stream`).
    func initQuery() -> [String: String]
    /// `/init` answered with a device id (`fromServer`), or the saved answer stands in for it. Called
    /// under the machine's lock, before calls are let through: the instance takes the device id and
    /// the answer here — in memory only — and must not call the machine back.
    func initMachine(adopt response: InitResponse, fromServer: Bool)
    /// The same answer, once calls are let through: the popup, the push token, the profile. Called off
    /// the machine's lock; `generation` is the `/init` it answers, for `isCurrent(_:)`.
    func initMachine(didFinish response: InitResponse, fromServer: Bool, generation: Int)
    /// The first outcome of each `/init`: `nil` when calls work, otherwise why they do not.
    func initMachine(didSettle error: Rees46.SdkError?)
}

/// The seams of the new core: time, pauses, the app's lifecycle and the spread of a pause.
struct CoreEnvironment {
    var clock: Clock = SystemClock()
    var scheduler: Scheduler = DispatchScheduler()
    var lifecycle: AppLifecycle = SystemAppLifecycle.shared
    /// A number in `0..<1`, for the ±20 % spread of a pause.
    var random: () -> Double = { Double.random(in: 0..<1) }
}

/// The `/init` of one instance on the new core.
///
/// - States: `initializing` until `/init` answers; `ready` with a device id; `retrying` after no
///   answer, a `2xx` without a device id or `5xx`, `408`, `410`, `417`, `426`, `429`; `refused` after
///   another `4xx`, kept in the shop's storage until a later `/init` passes.
/// - Retries: 1 s, 2 s, 4 s … 5 min, ±20 %, or the `Retry-After` of a `429` or `503`, held to
///   1 s … 5 min (`RetryPolicy`). An `/init` cancelled by anything but `release()` or `reset()` — the
///   app's URL protocol, say — is repeated the same way.
/// - A stored device id is `ready` at once, with a saved answer or without (decision 1): calls do not
///   wait for `/init` on every launch; `/init` still goes.
/// - With a saved answer or a stored device id, `retrying` lets calls through as `ready` does.
/// - Each successful answer gives the session its `sid` (`seance`) and opens its window again
///   (`sdk/core/session.md`).
/// - `/init` goes on start; when the session's window ran out — before a call or an event
///   (`renewSession()`), and back in the foreground two hours after the last event, however long the
///   app was in the background and also when it was launched there —; and on `checkShop()`, at most
///   once in ten minutes.
/// - No thread waits: `/init` and the calls that wait for it are tasks. `start()` reads only the
///   shop's `UserDefaults` on the caller's thread; the saved answer — a file, the keychain, JSON — is
///   read by the task that sends `/init`. Nothing is written to disk under the lock that calls, state
///   reads and `checkShop()` take: an answer writes under `writeLock`, which only `reset()` waits for.
final class InitMachine {

    typealias Transport = (NetworkClient.Request) async -> NetworkClient.Response

    /// The longest pause between two `/init`s, before its spread.
    static let maxPause = RetryPolicy.maxPause
    /// The spread of a pause: ±20 %.
    static let spread = RetryPolicy.spread
    /// The shortest wait a `Retry-After` gets: `0` would send `/init` again at once, for ever.
    static let minRetryAfter = RetryPolicy.minRetryAfter
    /// `checkShop()` sends `/init` at most this often.
    static let checkShopInterval: TimeInterval = 10 * 60

    let state: InstanceState
    /// The shop's session: `/init` carries its `sid` while the window is open and gives it a new one.
    let session: SessionWindow
    weak var delegate: InitMachineDelegate?

    private let transport: Transport
    private let storage: ShopStorage
    private let identity: UserIdentityRepository
    private let keychain: KeychainInitStore
    private let logger: SdkLogger
    private let environment: CoreEnvironment

    /// Guards the machine's state; held only for memory, never for disk.
    private let lock = NSLock()
    /// Held while an answer writes the shop's storage — the device id, the saved answer, `refused` —
    /// and while `reset()` raises the generation, so a late answer lands before the wipe or not at all.
    /// Taken before `lock`.
    private let writeLock = NSLock()
    private var started = false
    private var released = false
    /// Bumped by `reset()` and `release()`: an answer to an earlier `/init` changes nothing.
    private var generation = 0
    private var inFlight = false
    /// The task of the `/init` on its way: `reset()` and `release()` cancel it.
    private var inFlightTask: _Concurrency.Task<Void, Never>?
    /// Failed `/init`s in a row; the pause grows with them.
    private var failures = 0
    private var retry: Cancellable?
    /// Whether the shop has a saved answer to fall back on; known once `savedAnswerChecked`.
    private var hasSavedAnswer = false
    /// Whether the disk and the keychain were asked for a saved answer.
    private var savedAnswerChecked = false
    /// Whether the saved answer already stood in on this launch.
    private var usedSavedAnswer = false
    /// Whether `/init` answered since the start or the last `reset()`: a later `/init` that fails — a
    /// new session, a check of the shop — leaves `ready` as it is.
    private var hasAnswered = false
    private var lastCheck: Date?
    private var lifecycleSubscription: Cancellable?
    private var waiters: [UUID: Waiter] = [:]

    /// A call waiting for the instance to be usable.
    private final class Waiter {
        let continuation: CheckedContinuation<Rees46.SdkError?, Never>
        /// Whether it waits for the `/init` on its way when the session's window ran out.
        let needsSession: Bool
        var timeout: Cancellable?
        init(_ continuation: CheckedContinuation<Rees46.SdkError?, Never>, needsSession: Bool) {
            self.continuation = continuation
            self.needsSession = needsSession
        }
    }

    /// What a call does now.
    private enum Gate {
        case pass
        case fail(Rees46.SdkError)
        case wait
    }

    init(
        state: InstanceState,
        storage: ShopStorage,
        identity: UserIdentityRepository,
        keychain: KeychainInitStore,
        logger: SdkLogger,
        environment: CoreEnvironment,
        session: SessionWindow? = nil,
        transport: @escaping Transport
    ) {
        self.state = state
        self.session = session ?? SessionWindow(identity: identity, clock: environment.clock)
        self.storage = storage
        self.identity = identity
        self.keychain = keychain
        self.logger = logger
        self.environment = environment
        self.transport = transport
    }

    deinit {
        // Gone without `release()`: it stops observing the app and repeats nothing.
        lifecycleSubscription?.cancel()
        retry?.cancel()
        inFlightTask?.cancel()
    }

    // MARK: - Triggers

    /// The first `/init`. A shop that refused on an earlier launch stays `refused` until this `/init`
    /// passes; a stored device id is `ready` at once (decision 1); otherwise the instance is
    /// `initializing`. Reads the shop's `UserDefaults` only.
    func start() {
        let refused = storage.refused
        let deviceId = identity.deviceId ?? ""
        lock.lock()
        guard !started, !released else {
            lock.unlock()
            return
        }
        started = true
        let initial: Rees46.SdkState
        if refused {
            initial = .refused
        } else if !deviceId.isEmpty {
            initial = .ready
        } else {
            initial = .initializing
        }
        state.set(initial)
        lock.unlock()

        let subscription = environment.lifecycle.observe { [weak self] event in
            self?.lifecycle(event)
        }
        lock.lock()
        if released {
            lock.unlock()
            subscription.cancel()
            return
        }
        lifecycleSubscription = subscription
        lock.unlock()

        // `/init` is on its way before anything hears the instance is ready.
        send()
        if initial == .ready {
            delegate?.initMachine(didSettle: nil)
        }
    }

    /// Asks the shop through `/init` whether it still serves the SDK — at most once in ten minutes, and
    /// not once it refused. The queue asks after `402`, `403` or `404` to an event. `false` when it was
    /// too soon or there is nothing to ask.
    @discardableResult
    func checkShop() -> Bool {
        let now = environment.clock.now()
        lock.lock()
        guard started, !released, state.current != .refused else {
            lock.unlock()
            return false
        }
        if let last = lastCheck, now.timeIntervalSince(last) < Self.checkShopInterval {
            lock.unlock()
            return false
        }
        lastCheck = now
        lock.unlock()
        // An `/init` on its way answers the question too.
        send()
        return true
    }

    /// Back in the foreground two hours after the last event, the session gets a new `sid`. The time
    /// since the last event counts, not the time in the background: the app may have stood idle in the
    /// foreground, or been launched in the background by a push or a fetch and never left it.
    private func lifecycle(_ event: AppLifecycleEvent) {
        guard event == .willEnterForeground, !session.isAlive else { return }
        renewSession(fromForeground: true)
    }

    /// The session's window ran out: `/init` gets a new `sid`. The state does not change — the
    /// instance stays `ready` (`sdk/core/init.md`) —, but calls and events that need a session wait for
    /// this `/init` inside the SDK, so they go with the new `sid`. An `/init` on its way, or one that
    /// `retrying` repeats after its pause, answers anyway: nothing more goes — but the return to the
    /// foreground repeats a failing `/init` at once. A refusal is not asked again while the app runs:
    /// the next launch asks.
    func renewSession(fromForeground: Bool = false) {
        lock.lock()
        guard started, !released, !inFlight else {
            lock.unlock()
            return
        }
        // A failed renewal repeats after its pause: a call or an event does not cut it short, the return
        // to the foreground does.
        guard retry == nil || fromForeground else {
            lock.unlock()
            return
        }
        switch state.current {
        case .ready:
            break
        case .retrying where fromForeground:
            break
        case .retrying, .initializing, .refused, .notInitialized:
            lock.unlock()
            return
        }
        lock.unlock()
        send()
    }

    // MARK: - The saved answer

    /// The `sendIDFARequest` of the instance saved an answer: it stands in from now on.
    func savedAnswerWritten() {
        lock.lock()
        hasSavedAnswer = true
        savedAnswerChecked = true
        lock.unlock()
    }

    /// Whether the shop refused; a refused shop sends no `/init` of its own (`sendIDFARequest`).
    var isRefused: Bool {
        lock.lock(); defer { lock.unlock() }
        return state.current == .refused
    }

    /// Whether `generation` is still the machine's `/init`: no `reset()` or `release()` came after it.
    func isCurrent(_ generation: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return generation == self.generation && !released
    }

    // MARK: - deleteUserCredentials

    /// Forgets the `/init` in flight — cancelled, so the deleted device id does not reach the server
    /// once the wipe began — and the retries: called before the customer's data is wiped, so a late
    /// answer cannot write the deleted device id back. The instance waits for a new device id.
    func reset() {
        writeLock.lock()
        lock.lock()
        generation += 1
        let task = inFlightTask
        inFlightTask = nil
        inFlight = false
        retry?.cancel()
        retry = nil
        failures = 0
        // The wipe takes the saved answer and its keychain backup.
        hasSavedAnswer = false
        savedAnswerChecked = true
        usedSavedAnswer = false
        hasAnswered = false
        if !released {
            state.set(.initializing)
        }
        lock.unlock()
        writeLock.unlock()
        task?.cancel()
    }

    /// The `/init` without a device id after `reset()` and the wipe.
    func resume() {
        send()
    }

    // MARK: - release()

    /// Stops the machine: no more `/init`, the one on its way is cancelled, the calls that wait end as
    /// `cancelled`.
    func release() {
        lock.lock()
        guard !released else {
            lock.unlock()
            return
        }
        released = true
        generation += 1
        inFlight = false
        let task = inFlightTask
        inFlightTask = nil
        retry?.cancel()
        retry = nil
        let ended = waiters
        waiters.removeAll()
        let subscription = lifecycleSubscription
        lifecycleSubscription = nil
        lock.unlock()
        task?.cancel()
        subscription?.cancel()
        for waiter in ended.values {
            waiter.timeout?.cancel()
            waiter.continuation.resume(returning: .cancelled)
        }
    }

    // MARK: - Calls that wait

    /// Waits until calls may go out, at most `timeout`: `nil` once they may; `shopBlocked` when the
    /// shop refused; `timeout` when the instance did not get there in time; `notInitialized` after
    /// `release()`, and `cancelled` for a call `release()` ended while it waited. With `needsSession`, a
    /// call to a `ready` instance whose session's window ran out waits for the `/init` on its way — the
    /// one of the launch, say —, so it goes with the new `sid`.
    func awaitUsable(timeout: TimeInterval, needsSession: Bool = false) async -> Rees46.SdkError? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Rees46.SdkError?, Never>) in
            lock.lock()
            switch gateLocked(needsSession: needsSession) {
            case .pass:
                lock.unlock()
                continuation.resume(returning: nil)
            case .fail(let error):
                lock.unlock()
                continuation.resume(returning: error)
            case .wait:
                let id = UUID()
                let waiter = Waiter(continuation, needsSession: needsSession)
                waiters[id] = waiter
                waiter.timeout = environment.scheduler.schedule(after: timeout) { [weak self] in
                    self?.expire(id)
                }
                lock.unlock()
            }
        }
    }

    /// Whether calls go out now.
    var isUsable: Bool {
        lock.lock(); defer { lock.unlock() }
        if case .pass = gateLocked() { return true }
        return false
    }

    private func gateLocked(needsSession: Bool = false) -> Gate {
        guard !released else { return .fail(.notInitialized) }
        switch state.current {
        case .ready:
            // The `/init` on its way brings the session a new `sid`: the call goes with it.
            if needsSession && inFlight && !session.isAlive {
                return .wait
            }
            return .pass
        case .retrying:
            return hasFallbackLocked() ? .pass : .wait
        case .refused:
            return .fail(.shopBlocked)
        case .initializing:
            return .wait
        case .notInitialized:
            return started ? .fail(.notInitialized) : .wait
        }
    }

    /// A saved answer, or a device id the shop already has (decision 1).
    private func hasFallbackLocked() -> Bool {
        hasSavedAnswer || !(identity.deviceId ?? "").isEmpty
    }

    private func expire(_ id: UUID) {
        lock.lock()
        let waiter = waiters.removeValue(forKey: id)
        lock.unlock()
        waiter?.continuation.resume(returning: .timeout)
    }

    /// Lets through or fails every waiting call the state now decides. Under `lock`.
    private func settleWaitersLocked() {
        for (id, waiter) in waiters {
            let outcome: Rees46.SdkError?
            switch gateLocked(needsSession: waiter.needsSession) {
            case .wait:
                continue
            case .pass:
                outcome = nil
            case .fail(let error):
                outcome = error
            }
            waiters[id] = nil
            waiter.timeout?.cancel()
            waiter.continuation.resume(returning: outcome)
        }
    }

    // MARK: - /init

    /// Sends `/init` unless one is on its way. Without a saved answer it waits for the network; with
    /// one it fails at once offline, and the saved answer stands in. Whether there is one is read by
    /// the task, off the caller's thread, the first time.
    private func send() {
        lock.lock()
        guard started, !released, !inFlight else {
            lock.unlock()
            return
        }
        inFlight = true
        retry?.cancel()
        retry = nil
        let generation = self.generation
        lock.unlock()

        let task = _Concurrency.Task { [weak self] in
            guard let self = self else { return }
            let waitsForNetwork = self.waitsForNetwork()
            let request = NetworkClient.Request(
                method: .get,
                path: "init",
                query: self.delegate?.initQuery() ?? [:],
                timeout: NetworkClient.initTimeout,
                waitsForNetwork: waitsForNetwork
            )
            let response = await self.transport(request)
            self.handle(response, generation: generation)
        }
        lock.lock()
        if generation == self.generation, inFlight {
            inFlightTask = task
            lock.unlock()
        } else {
            // `reset()` or `release()` came in between: this `/init` is not theirs.
            lock.unlock()
            task.cancel()
        }
    }

    /// Whether the `/init` about to go waits for the network: only without a saved answer. The first
    /// time it asks the disk and the keychain.
    private func waitsForNetwork() -> Bool {
        lock.lock()
        let checked = savedAnswerChecked
        let known = hasSavedAnswer
        lock.unlock()
        guard !checked else { return !known }
        let found = readSavedAnswer() != nil
        lock.lock()
        if !savedAnswerChecked {
            savedAnswerChecked = true
            hasSavedAnswer = hasSavedAnswer || found
        }
        let has = hasSavedAnswer
        lock.unlock()
        return !has
    }

    private func handle(_ response: NetworkClient.Response, generation: Int) {
        switch response.result {
        case .success(let json):
            guard let object = json as? [String: Any], let deviceId = object["did"] as? String, !deviceId.isEmpty else {
                logger.warning(LogCode.decodingFailed, "the answer to GET init has no device id", ["path": "init"])
                failed(response, error: .decoding, generation: generation)
                return
            }
            succeeded(InitResponse(json: object), body: response.body, generation: generation)
        case .failure(.cancelled) where !isCurrent(generation):
            // `release()` or `reset()` ended it; whatever comes next is theirs.
            return
        case .failure(.http(let code, let serverCode)) where Self.isRefusal(code):
            refused(code, error: .http(code: code, serverCode: serverCode), generation: generation)
        case .failure(let error):
            // A cancellation of its own — the app's URL protocol, say — is repeated like a failure.
            failed(response, error: error, generation: generation)
        }
    }

    private func succeeded(_ answer: InitResponse, body: Data, generation: Int) {
        writeLock.lock()
        guard isCurrent(generation) else {
            writeLock.unlock()
            return
        }
        // The shop's storage, under `writeLock` only: a `reset()` waits for it, the calls do not.
        storage.refused = false
        // The device id the shop keeps; the answer's only when the shop has none.
        var response = answer
        let stored = identity.deviceId ?? ""
        if stored.isEmpty {
            identity.deviceId = answer.deviceId
        } else {
            response.deviceId = stored
        }
        // The last answer, every time. Its keychain backup stays as it is: only `sendIDFARequest` and
        // the migrations write it (`sdk/core/storage.md`).
        storage.writeSavedInitAnswer(body)
        // The server's session from now on, before any call is let through.
        session.adopt(answer.seance)

        lock.lock()
        guard generation == self.generation, !released else {
            lock.unlock()
            writeLock.unlock()
            return
        }
        inFlight = false
        inFlightTask = nil
        failures = 0
        hasSavedAnswer = true
        savedAnswerChecked = true
        // The saved answer may stand in, and say so, again after a later failure.
        usedSavedAnswer = false
        hasAnswered = true
        delegate?.initMachine(adopt: response, fromServer: true)
        state.set(.ready)
        settleWaitersLocked()
        lock.unlock()
        writeLock.unlock()

        logger.info(LogCode.initSucceeded, "initialization finished")
        delegate?.initMachine(didFinish: response, fromServer: true, generation: generation)
        delegate?.initMachine(didSettle: nil)
    }

    private func failed(_ response: NetworkClient.Response, error: Rees46.SdkError, generation: Int) {
        // The saved answer that stands in is read before any lock: a file, the keychain, JSON.
        lock.lock()
        // After an answer of this launch, a failing `/init` — a new session, a check of the shop — keeps
        // `ready`: no `retrying`, no saved answer standing in again, no popups v3 refresh.
        let keepsReady = state.current == .ready && hasAnswered
        let wantsSaved = generation == self.generation && !released && hasSavedAnswer && !usedSavedAnswer
            && state.current != .refused && !keepsReady
        lock.unlock()
        var saved = wantsSaved ? readSavedAnswer() : nil

        writeLock.lock()
        guard isCurrent(generation) else {
            writeLock.unlock()
            return
        }
        // Its device id goes to the shop's storage only when the shop has none.
        if var standIn = saved {
            standIn.popup = nil
            let stored = identity.deviceId ?? ""
            if stored.isEmpty {
                if !standIn.deviceId.isEmpty {
                    identity.deviceId = standIn.deviceId
                }
            } else {
                standIn.deviceId = stored
            }
            saved = standIn
        }

        lock.lock()
        guard generation == self.generation, !released else {
            lock.unlock()
            writeLock.unlock()
            return
        }
        inFlight = false
        inFlightTask = nil
        failures += 1
        let attempt = failures
        let pause = RetryPolicy.pause(retryAfter: response.retryAfter, afterFailures: attempt, random: environment.random())
        // A shop that refused on an earlier launch stays refused while the first answer of this launch
        // has not come; otherwise the instance retries, usable if it has something to fall back on.
        var standIn: InitResponse?
        let wasRefused = state.current == .refused
        if keepsReady {
            settleWaitersLocked()
        } else if !wasRefused {
            state.set(.retrying)
            if let saved = saved, !usedSavedAnswer {
                usedSavedAnswer = true
                standIn = saved
                delegate?.initMachine(adopt: saved, fromServer: false)
            }
            settleWaitersLocked()
        }
        let usable: Bool
        if case .pass = gateLocked() {
            usable = true
        } else {
            usable = false
        }
        retry = environment.scheduler.schedule(after: pause) { [weak self] in
            self?.send()
        }
        lock.unlock()
        writeLock.unlock()

        var context = ["error": error.logKind, "attempt": String(attempt)]
        if let status = response.status {
            context["status"] = String(status)
        }
        logger.warning(LogCode.initFailed, "initialization failed", context)
        context["delay"] = String(format: "%.1f", pause)
        logger.warning(LogCode.initRetry, "/init is repeated in \(String(format: "%.0f", pause)) s", context)
        if let standIn = standIn {
            logger.warning(LogCode.initSavedAnswer, "no answer to /init: the saved init answer stands in")
            delegate?.initMachine(didFinish: standIn, fromServer: false, generation: generation)
        }
        delegate?.initMachine(didSettle: usable ? nil : (wasRefused ? .shopBlocked : error))
    }

    private func refused(_ code: Int, error: Rees46.SdkError, generation: Int) {
        writeLock.lock()
        guard isCurrent(generation) else {
            writeLock.unlock()
            return
        }
        storage.refused = true
        lock.lock()
        guard generation == self.generation, !released else {
            lock.unlock()
            writeLock.unlock()
            return
        }
        inFlight = false
        inFlightTask = nil
        failures = 0
        retry?.cancel()
        retry = nil
        state.set(.refused)
        settleWaitersLocked()
        lock.unlock()
        writeLock.unlock()

        let context = ["status": String(code)]
        if ![402, 403, 404].contains(code) {
            // Not a refusal the API documents: the SDK's own request is wrong.
            logger.error(LogCode.initFailed, "/init was rejected: the SDK's request is not accepted", context)
        }
        logger.error(LogCode.initRefused, "the shop refused the SDK: calls fail until a later launch's /init passes", context)
        delegate?.initMachine(didSettle: .shopBlocked)
    }

    /// The shop's saved answer — its file, or the keychain backup that outlives a reinstall — without
    /// its popup, which was shown when it came. Reads the disk: never under `lock`.
    private func readSavedAnswer() -> InitResponse? {
        guard let data = storage.readSavedInitAnswer() ?? keychain.readInitData(),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        var response = InitResponse(json: json)
        response.popup = nil
        return response
    }

    // MARK: - Rules

    /// `5xx`, `408`, `410`, `417`, `426`, `429`: the server will answer later.
    static func isRetryable(_ code: Int) -> Bool {
        RetryPolicy.isRetryable(code)
    }

    /// Any other `4xx`: the shop refused (`402`, `403`, `404`), or the SDK's request is wrong.
    static func isRefusal(_ code: Int) -> Bool {
        (400..<500).contains(code) && !isRetryable(code)
    }

    /// The pause after `failures` failed `/init`s in a row: 1 s, 2 s, 4 s … 5 min, spread by ±20 %
    /// with `random` in `0..<1`.
    static func pause(afterFailures failures: Int, random: Double) -> TimeInterval {
        RetryPolicy.pause(afterFailures: failures, random: random)
    }
}
