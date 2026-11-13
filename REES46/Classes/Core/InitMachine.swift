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
    /// the answer here and must not call the machine back.
    func initMachine(adopt response: InitResponse, fromServer: Bool)
    /// The same answer, once calls are let through: the popup, the push token, the profile.
    func initMachine(didFinish response: InitResponse, fromServer: Bool)
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
/// - Retries: 1 s, 2 s, 4 s … 5 min, ±20 %, or the answer's `Retry-After`.
/// - A stored device id without a saved answer is `ready` at once (decision 1); `/init` still goes.
/// - With a saved answer or a stored device id, `retrying` lets calls through as `ready` does.
/// - `/init` goes on start, on the way back from more than two hours in the background, and on
///   `checkShop()`, at most once in ten minutes.
/// - No thread waits: `/init` and the calls that wait for it are tasks.
final class InitMachine {

    typealias Transport = (NetworkClient.Request) async -> NetworkClient.Response

    /// The longest pause between two `/init`s, before its spread.
    static let maxPause: TimeInterval = 5 * 60
    /// The spread of a pause: ±20 %.
    static let spread = 0.2
    /// The shortest wait a `Retry-After` gets: `0` would send `/init` again at once, for ever.
    static let minRetryAfter: TimeInterval = 1
    /// A return from the background after this long sends `/init`.
    static let foregroundAfter: TimeInterval = 2 * 60 * 60
    /// `checkShop()` sends `/init` at most this often.
    static let checkShopInterval: TimeInterval = 10 * 60

    let state: InstanceState
    weak var delegate: InitMachineDelegate?

    private let transport: Transport
    private let storage: ShopStorage
    private let identity: UserIdentityRepository
    private let keychain: KeychainInitStore
    private let logger: SdkLogger
    private let environment: CoreEnvironment

    private let lock = NSLock()
    private var started = false
    private var released = false
    /// Bumped by `reset()` and `release()`: an answer to an earlier `/init` changes nothing.
    private var generation = 0
    private var inFlight = false
    /// Failed `/init`s in a row; the pause grows with them.
    private var failures = 0
    private var retry: Cancellable?
    /// Whether the shop has a saved answer to fall back on.
    private var hasSavedAnswer = false
    /// Whether the saved answer already stood in on this launch.
    private var usedSavedAnswer = false
    private var lastCheck: Date?
    private var backgroundSince: Date?
    private var lifecycleSubscription: Cancellable?
    private var waiters: [UUID: Waiter] = [:]

    /// A call waiting for the instance to be usable.
    private final class Waiter {
        let continuation: CheckedContinuation<Rees46.SdkError?, Never>
        var timeout: Cancellable?
        init(_ continuation: CheckedContinuation<Rees46.SdkError?, Never>) {
            self.continuation = continuation
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
        transport: @escaping Transport
    ) {
        self.state = state
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
    }

    // MARK: - Triggers

    /// The first `/init`. A shop that refused on an earlier launch stays `refused` until this `/init`
    /// passes; a stored device id without a saved answer is `ready` at once (decision 1); otherwise the
    /// instance is `initializing`.
    func start() {
        let saved = readSavedAnswer()
        let refused = storage.refused
        let deviceId = identity.deviceId ?? ""
        lock.lock()
        guard !started, !released else {
            lock.unlock()
            return
        }
        started = true
        hasSavedAnswer = saved != nil
        let initial: Rees46.SdkState
        if refused {
            initial = .refused
        } else if !deviceId.isEmpty && saved == nil {
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

        if initial == .ready {
            delegate?.initMachine(didSettle: nil)
        }
        send()
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

    private func lifecycle(_ event: AppLifecycleEvent) {
        let now = environment.clock.now()
        lock.lock()
        switch event {
        case .didEnterBackground:
            backgroundSince = now
            lock.unlock()
        case .willEnterForeground:
            let since = backgroundSince
            backgroundSince = nil
            // A refusal is not asked again while the app runs: the next launch asks.
            let refused = state.current == .refused
            lock.unlock()
            guard let since = since, !refused, now.timeIntervalSince(since) > Self.foregroundAfter else { return }
            send()
        }
    }

    // MARK: - deleteUserCredentials

    /// Forgets the `/init` in flight and the retries: called before the customer's data is wiped, so a
    /// late answer cannot write the deleted device id back. The instance waits for a new device id.
    func reset() {
        lock.lock()
        generation += 1
        inFlight = false
        retry?.cancel()
        retry = nil
        failures = 0
        hasSavedAnswer = false
        usedSavedAnswer = false
        if !released {
            state.set(.initializing)
        }
        lock.unlock()
    }

    /// The `/init` without a device id after `reset()` and the wipe.
    func resume() {
        send()
    }

    // MARK: - release()

    /// Stops the machine: no more `/init`, the calls that wait end as `cancelled`.
    func release() {
        lock.lock()
        guard !released else {
            lock.unlock()
            return
        }
        released = true
        generation += 1
        inFlight = false
        retry?.cancel()
        retry = nil
        let ended = waiters
        waiters.removeAll()
        let subscription = lifecycleSubscription
        lifecycleSubscription = nil
        lock.unlock()
        subscription?.cancel()
        for waiter in ended.values {
            waiter.timeout?.cancel()
            waiter.continuation.resume(returning: .cancelled)
        }
    }

    // MARK: - Calls that wait

    /// Waits until calls may go out, at most `timeout`: `nil` once they may; `shopBlocked` when the
    /// shop refused; `timeout` when the instance did not get there in time; `notInitialized` after
    /// `release()`, and `cancelled` for a call `release()` ended while it waited.
    func awaitUsable(timeout: TimeInterval) async -> Rees46.SdkError? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Rees46.SdkError?, Never>) in
            lock.lock()
            switch gateLocked() {
            case .pass:
                lock.unlock()
                continuation.resume(returning: nil)
            case .fail(let error):
                lock.unlock()
                continuation.resume(returning: error)
            case .wait:
                let id = UUID()
                let waiter = Waiter(continuation)
                waiters[id] = waiter
                waiter.timeout = environment.scheduler.schedule(after: timeout) { [weak self] in
                    self?.expire(id)
                }
                lock.unlock()
            }
        }
    }

    /// Whether calls go out now; for the instance and tests.
    var isUsable: Bool {
        lock.lock(); defer { lock.unlock() }
        if case .pass = gateLocked() { return true }
        return false
    }

    private func gateLocked() -> Gate {
        guard !released else { return .fail(.notInitialized) }
        switch state.current {
        case .ready:
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
            switch gateLocked() {
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
    /// one it fails at once offline, and the saved answer stands in.
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
        let waitsForNetwork = !hasSavedAnswer
        lock.unlock()

        let request = NetworkClient.Request(
            method: .get,
            path: "init",
            query: delegate?.initQuery() ?? [:],
            timeout: NetworkClient.initTimeout,
            waitsForNetwork: waitsForNetwork
        )
        let transport = self.transport
        _Concurrency.Task { [weak self] in
            let response = await transport(request)
            self?.handle(response, generation: generation)
        }
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
        case .failure(.cancelled):
            // `release()` or a reset ended it; whatever comes next is theirs.
            lock.lock()
            if generation == self.generation {
                inFlight = false
            }
            lock.unlock()
        case .failure(.http(let code, let serverCode)) where Self.isRefusal(code):
            refused(code, error: .http(code: code, serverCode: serverCode), generation: generation)
        case .failure(let error):
            failed(response, error: error, generation: generation)
        }
    }

    private func succeeded(_ answer: InitResponse, body: Data, generation: Int) {
        lock.lock()
        guard generation == self.generation, !released else {
            lock.unlock()
            return
        }
        inFlight = false
        failures = 0
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
        hasSavedAnswer = true
        usedSavedAnswer = false
        delegate?.initMachine(adopt: response, fromServer: true)
        state.set(.ready)
        settleWaitersLocked()
        lock.unlock()

        logger.info(LogCode.initSucceeded, "initialization finished")
        delegate?.initMachine(didFinish: response, fromServer: true)
        delegate?.initMachine(didSettle: nil)
    }

    private func failed(_ response: NetworkClient.Response, error: Rees46.SdkError, generation: Int) {
        lock.lock()
        guard generation == self.generation, !released else {
            lock.unlock()
            return
        }
        inFlight = false
        failures += 1
        let attempt = failures
        let pause = response.retryAfter.map { max($0, Self.minRetryAfter) }
            ?? Self.pause(afterFailures: attempt, random: environment.random())
        // A shop that refused on an earlier launch stays refused while the first answer of this launch
        // has not come; otherwise the instance retries, usable if it has something to fall back on.
        var standIn: InitResponse?
        let wasRefused = state.current == .refused
        if !wasRefused {
            state.set(.retrying)
            if hasSavedAnswer && !usedSavedAnswer, let saved = adoptSavedAnswerLocked() {
                usedSavedAnswer = true
                standIn = saved
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

        var context = ["error": error.logKind, "attempt": String(attempt)]
        if let status = response.status {
            context["status"] = String(status)
        }
        logger.warning(LogCode.initFailed, "initialization failed", context)
        context["delay"] = String(format: "%.1f", pause)
        logger.warning(LogCode.initRetry, "/init is repeated in \(Int(pause.rounded())) s", context)
        if let standIn = standIn {
            logger.warning(LogCode.initSavedAnswer, "no answer to /init: the saved init answer stands in")
            delegate?.initMachine(didFinish: standIn, fromServer: false)
        }
        delegate?.initMachine(didSettle: usable ? nil : (wasRefused ? .shopBlocked : error))
    }

    private func refused(_ code: Int, error: Rees46.SdkError, generation: Int) {
        lock.lock()
        guard generation == self.generation, !released else {
            lock.unlock()
            return
        }
        inFlight = false
        failures = 0
        retry?.cancel()
        retry = nil
        storage.refused = true
        state.set(.refused)
        settleWaitersLocked()
        lock.unlock()

        let context = ["status": String(code)]
        if ![402, 403, 404].contains(code) {
            // Not a refusal the API documents: the SDK's own request is wrong.
            logger.error(LogCode.initFailed, "/init was rejected: the SDK's request is not accepted", context)
        }
        logger.error(LogCode.initRefused, "the shop refused the SDK: calls fail until a later launch's /init passes", context)
        delegate?.initMachine(didSettle: .shopBlocked)
    }

    /// The saved answer as the instance takes it: without its popup, which was shown when it came, and
    /// with the device id the shop keeps — the saved one only when the shop has none. Under `lock`.
    private func adoptSavedAnswerLocked() -> InitResponse? {
        guard var response = readSavedAnswer() else { return nil }
        response.popup = nil
        let stored = identity.deviceId ?? ""
        if stored.isEmpty {
            if !response.deviceId.isEmpty {
                identity.deviceId = response.deviceId
            }
        } else {
            response.deviceId = stored
        }
        delegate?.initMachine(adopt: response, fromServer: false)
        return response
    }

    /// The shop's saved answer: its file, or the keychain backup that outlives a reinstall.
    private func readSavedAnswer() -> InitResponse? {
        guard let data = storage.readSavedInitAnswer() ?? keychain.readInitData(),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return InitResponse(json: json)
    }

    // MARK: - Rules

    /// `5xx`, `408`, `410`, `417`, `426`, `429`: the server will answer later.
    static func isRetryable(_ code: Int) -> Bool {
        (500..<600).contains(code) || [408, 410, 417, 426, 429].contains(code)
    }

    /// Any other `4xx`: the shop refused (`402`, `403`, `404`), or the SDK's request is wrong.
    static func isRefusal(_ code: Int) -> Bool {
        (400..<500).contains(code) && !isRetryable(code)
    }

    /// The pause after `failures` failed `/init`s in a row: 1 s, 2 s, 4 s … 5 min, spread by ±20 %
    /// with `random` in `0..<1`.
    static func pause(afterFailures failures: Int, random: Double) -> TimeInterval {
        let exponent = Double(min(max(failures - 1, 0), 16))
        let base = min(pow(2, exponent), maxPause)
        let unit = min(max(random, 0), 1)
        return base * (1 + spread * (2 * unit - 1))
    }
}
