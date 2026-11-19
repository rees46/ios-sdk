//
//  InitPackageTests.swift
//  REES46CoreTests
//
//  The rules of the new core's `/init` that need no server: which answers are repeated and which
//  refuse, the pauses, the state and its listeners, the once-only completion of `initialize`, and the
//  machine over a transport the test answers.
//

import XCTest
@testable import REES46

final class InitPackageTests: XCTestCase {

    // MARK: - Rules

    func test_which_answers_are_repeated_and_which_refuse() {
        for code in [500, 502, 503, 504, 599, 408, 410, 417, 426, 429] {
            XCTAssertTrue(InitMachine.isRetryable(code), "\(code)")
            XCTAssertFalse(InitMachine.isRefusal(code), "\(code)")
        }
        for code in [400, 401, 402, 403, 404, 405, 422, 451] {
            XCTAssertTrue(InitMachine.isRefusal(code), "\(code)")
            XCTAssertFalse(InitMachine.isRetryable(code), "\(code)")
        }
        XCTAssertFalse(InitMachine.isRefusal(304))
        XCTAssertFalse(InitMachine.isRefusal(200))
    }

    func test_the_pause_doubles_up_to_five_minutes_with_a_spread_of_twenty_percent() {
        let middle = (1...12).map { InitMachine.pause(afterFailures: $0, random: 0.5) }
        XCTAssertEqual(middle, [1, 2, 4, 8, 16, 32, 64, 128, 256, 300, 300, 300])
        XCTAssertEqual(InitMachine.pause(afterFailures: 1, random: 0), 0.8, accuracy: 0.0001)
        XCTAssertEqual(InitMachine.pause(afterFailures: 1, random: 0.999_999), 1.2, accuracy: 0.0001)
        XCTAssertEqual(InitMachine.pause(afterFailures: 40, random: 0), 240, accuracy: 0.0001)
        XCTAssertEqual(InitMachine.pause(afterFailures: 40, random: 0.999_999), 300, accuracy: 0.001, "the spread never goes past five minutes")
        XCTAssertEqual(InitMachine.pause(afterFailures: 9, random: 0.999_999), 300, accuracy: 0.001, "256 s spread up is held to the cap")
        XCTAssertEqual(InitMachine.pause(afterFailures: 9, random: 0), 204.8, accuracy: 0.001)
        for failures in 1...40 {
            for random in [0, 0.25, 0.5, 0.75, 0.999_999] {
                XCTAssertLessThanOrEqual(RetryPolicy.pause(afterFailures: failures, random: random), 300)
            }
        }
        // A server's Retry-After is held between one second and five minutes.
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 0), 1)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: -5), 1)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 42), 42)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 86_400), 300)
    }

    // MARK: - State

    func test_a_listener_hears_each_change_once_on_the_main_thread_in_order() {
        let state = InstanceState()
        var heard: [(Rees46.SdkState, Bool)] = []
        let subscription = state.observe { heard.append(($0, Thread.isMainThread)) }
        let done = expectation(description: "changes")
        DispatchQueue.global().async {
            state.set(.initializing)
            state.set(.initializing)
            state.set(.retrying)
            state.set(.ready)
            DispatchQueue.main.async { done.fulfill() }
        }
        wait(for: [done], timeout: 2)
        subscription.cancel()
        state.set(.notInitialized)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        XCTAssertEqual(heard.map(\.0), [.notInitialized, .initializing, .retrying, .ready], "the current state first, then each change")
        XCTAssertTrue(heard.allSatisfy(\.1))
        XCTAssertEqual(Rees46.SdkState.refused.rawValue, "refused")
    }

    func test_a_change_right_after_subscribing_comes_after_the_current_state_from_any_thread() {
        for _ in 0..<100 {
            let state = InstanceState(.initializing)
            var heard: [Rees46.SdkState] = []
            let both = DispatchGroup()
            var subscription: Cancellable?
            DispatchQueue.global().async(group: both) { subscription = state.observe { heard.append($0) } }
            DispatchQueue.global().async(group: both) { state.set(.ready) }
            both.wait()
            let done = expectation(description: "delivered")
            DispatchQueue.main.async { done.fulfill() }
            wait(for: [done], timeout: 2)
            XCTAssertEqual(heard.last, .ready, "the last state heard is the current one")
            XCTAssertTrue(heard == [.ready] || heard == [.initializing, .ready], "\(heard)")
            subscription?.cancel()
        }
    }

    func test_the_completion_of_initialize_is_called_once_with_the_first_outcome() {
        let completion = InitCompletion(onMain: true)
        var heard: [String] = []
        let both = expectation(description: "both")
        both.expectedFulfillmentCount = 2
        completion.add { error in heard.append("early \(error == nil)"); both.fulfill() }
        completion.finish(nil, full: nil)
        completion.finish(.decodeError, full: .decoding)
        completion.add { error in heard.append("late \(error == nil)"); both.fulfill() }
        wait(for: [both], timeout: 2)
        // Whatever else had been dispatched to the main queue has run by now.
        let drained = expectation(description: "the main queue")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        XCTAssertEqual(heard, ["early true", "late true"])
    }

    func test_the_completion_of_initialize_runs_with_the_whole_error_behind_the_old_one() {
        let completion = InitCompletion(onMain: true)
        var heard: [Rees46.SdkError?] = []
        let both = expectation(description: "both")
        both.expectedFulfillmentCount = 2
        completion.add { _ in heard.append(CurrentError.current); both.fulfill() }
        completion.finish(.legacy(.shopBlocked), full: .shopBlocked)
        completion.add { _ in heard.append(CurrentError.current); both.fulfill() }
        wait(for: [both], timeout: 2)
        XCTAssertEqual(heard, [.shopBlocked, .shopBlocked], "early and late")
        XCTAssertNil(CurrentError.current, "only while the completion runs")
    }

    // MARK: - Config

    func test_the_device_id_of_the_config_is_none_by_default_and_counts_as_a_setting() {
        XCTAssertNil(Rees46Config(shopId: "a").deviceId)
        XCTAssertEqual(Rees46Config(shopId: "a", deviceId: "did-1").deviceId, "did-1")
        XCTAssertTrue(Rees46Config(shopId: "a").hasSameSettings(as: Rees46Config(shopId: "a", deviceId: "")))
        XCTAssertFalse(Rees46Config(shopId: "a").hasSameSettings(as: Rees46Config(shopId: "a", deviceId: "did-1")))
        XCTAssertFalse(Rees46Config(shopId: "a").hasSameSettings(as: Rees46Config(shopId: "a", stream: "flutter")))
        XCTAssertTrue(Rees46Config(shopId: "a", enableLogs: true).hasSameSettings(as: Rees46Config(shopId: "a", logLevel: .debug)))
    }

    func test_the_app_domain_is_app_rees46_ru_unless_the_config_gives_another() {
        XCTAssertEqual(Rees46Config(shopId: "a").appDomain, "app.rees46.ru")
        XCTAssertEqual(Rees46Config(shopId: "a", appDomain: " app.cluster.example \n").appDomain, "app.cluster.example")
        XCTAssertEqual(Rees46Config(shopId: "a", appDomain: "").appDomain, "app.rees46.ru", "empty is the default")
        XCTAssertEqual(Rees46Config(shopId: "a", appDomain: "app.cluster.example").onNewCore().appDomain, "app.cluster.example")
        XCTAssertFalse(Rees46Config(shopId: "a").hasSameSettings(as: Rees46Config(shopId: "a", appDomain: "app.cluster.example")))
        XCTAssertTrue(Rees46Config(shopId: "a").hasSameSettings(as: Rees46Config(shopId: "a", appDomain: "app.rees46.ru")))
    }

    // MARK: - The machine over a transport the test answers

    func test_the_machine_retries_with_a_pause_and_lets_waiting_calls_through_once_ready() async throws {
        let shop = "machine-\(UUID().uuidString.prefix(6))"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(shop)
        let suite = try XCTUnwrap(UserDefaults(suiteName: shop))
        defer {
            UserDefaults.standard.removePersistentDomain(forName: shop)
            try? FileManager.default.removeItem(at: root)
        }
        let logger = SdkLogger(shopId: shop, level: .none)
        let storage = ShopStorage(shopId: shop, logger: logger, partition: suite, root: root, documents: root)
        let identity = UserIdentityRepositoryImpl(store: suite)
        let scheduler = StepScheduler()
        let answers = Answers([
            .init(status: 503, body: Data(), retryAfter: nil, result: .failure(.http(code: 503, serverCode: nil))),
            .init(status: 200, body: Data(#"{"did":"m-did"}"#.utf8), retryAfter: nil, result: .success(["did": "m-did"])),
        ])
        let state = InstanceState()
        let machine = InitMachine(
            state: state,
            storage: storage,
            identity: identity,
            keychain: NoKeychain(),
            logger: logger,
            environment: CoreEnvironment(clock: SystemClock(), scheduler: scheduler, lifecycle: NoLifecycle(), random: { 0.5 })
        ) { _ in await answers.next() }

        machine.start()
        XCTAssertEqual(state.current, .initializing)
        let waiting = _Concurrency.Task { await machine.awaitUsable(timeout: 60) }

        try await until { state.current == .retrying && scheduler.delays.contains(1) }
        XCTAssertFalse(machine.isUsable, "no did and no saved answer: calls wait")
        scheduler.fire(delay: 1)

        let outcome = await waiting.value
        XCTAssertNil(outcome)
        XCTAssertEqual(state.current, .ready)
        XCTAssertEqual(identity.deviceId, "m-did")
        XCTAssertEqual(storage.readSavedInitAnswer(), Data(#"{"did":"m-did"}"#.utf8))
        let requests = await answers.count
        XCTAssertEqual(requests, 2)
        machine.release()
        let afterRelease = await machine.awaitUsable(timeout: 1)
        XCTAssertEqual(afterRelease, .notInitialized)
    }

    private func until(timeout: TimeInterval = 3, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return XCTFail("the condition did not hold in time") }
            try await _Concurrency.Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

/// Answers in turn; the last one again once the others are used.
private actor Answers {
    private var queue: [NetworkClient.Response]
    private(set) var count = 0
    init(_ answers: [NetworkClient.Response]) { queue = answers }
    func next() -> NetworkClient.Response {
        count += 1
        return queue.count > 1 ? queue.removeFirst() : queue[0]
    }
}

/// Keeps scheduled work until the test fires it by its delay.
private final class StepScheduler: Scheduler {
    private let lock = NSLock()
    private var jobs: [(delay: TimeInterval, work: () -> Void, cancelled: () -> Bool)] = []

    var delays: [TimeInterval] {
        lock.lock(); defer { lock.unlock() }
        return jobs.filter { !$0.cancelled() }.map(\.delay)
    }

    @discardableResult
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> Cancellable {
        let flag = Flag()
        lock.lock()
        jobs.append((delay, work, { flag.isSet }))
        lock.unlock()
        return Cancellable { flag.set() }
    }

    func fire(delay: TimeInterval) {
        lock.lock()
        let due = jobs.filter { $0.delay == delay && !$0.cancelled() }
        jobs.removeAll { $0.delay == delay }
        lock.unlock()
        due.forEach { $0.work() }
    }

    private final class Flag {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
        func set() { lock.lock(); value = true; lock.unlock() }
    }
}

private final class NoLifecycle: AppLifecycle {
    func observe(_ handler: @escaping (AppLifecycleEvent) -> Void) -> Cancellable { .noop }
}

private final class NoKeychain: KeychainInitStore {
    func readInitData() -> Data? { nil }
    func writeInitData(_ data: Data) {}
    func clear() {}
}
