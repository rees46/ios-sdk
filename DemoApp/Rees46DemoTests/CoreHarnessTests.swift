//
//  CoreHarnessTests.swift
//  REES46Tests
//
//  Test doubles of the core's seams — clock, scheduler, connectivity, app lifecycle — the contract
//  fixtures every SDK shares, and the stub server's headers, cut bodies and delays.
//

import XCTest
@testable import REES46

// MARK: - Doubles

/// A clock that moves only when told; read from any thread.
final class FakeClock: Clock {
    private let lock = NSLock()
    private var value: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) { value = start }
    var current: Date {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

/// A scheduler that runs work only when its time comes on the paired `FakeClock`. Work may be
/// scheduled from any thread (the new core's tasks); it runs on the thread that advances the clock.
final class ManualScheduler: Scheduler {
    private struct Job { let due: Date; let work: () -> Void; let id: Int }
    private let clock: FakeClock
    private let lock = NSLock()
    private var jobs: [Job] = []
    private var cancelled: Set<Int> = []
    private var nextId = 0

    init(clock: FakeClock) { self.clock = clock }

    var pending: Int {
        lock.lock(); defer { lock.unlock() }
        return jobs.filter { !cancelled.contains($0.id) }.count
    }

    /// The delays of the work waiting, from now, in order.
    var pendingDelays: [TimeInterval] {
        lock.lock(); defer { lock.unlock() }
        let now = clock.now()
        return jobs.filter { !cancelled.contains($0.id) }.map { $0.due.timeIntervalSince(now) }.sorted()
    }

    @discardableResult
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> Cancellable {
        lock.lock()
        nextId += 1
        let id = nextId
        jobs.append(Job(due: clock.now().addingTimeInterval(delay), work: work, id: id))
        lock.unlock()
        return Cancellable { [weak self] in
            guard let self = self else { return }
            self.lock.lock(); self.cancelled.insert(id); self.lock.unlock()
        }
    }

    /// Moves the clock and runs, in order, the work that has come due.
    func advance(by seconds: TimeInterval) {
        lock.lock()
        clock.advance(by: seconds)
        let now = clock.now()
        let due = jobs.filter { $0.due <= now && !cancelled.contains($0.id) }.sorted { $0.due < $1.due }
        jobs.removeAll { $0.due <= now }
        lock.unlock()
        due.forEach { $0.work() }
    }
}

/// Connectivity set by the test; read and observed from any thread (the new client is an actor).
final class FakeConnectivity: ConnectivityMonitor {
    private let lock = NSLock()
    private var observers: [Int: (Bool) -> Void] = [:]
    private var nextId = 0
    private var online: Bool

    var isOnline: Bool {
        get { lock.lock(); defer { lock.unlock() }; return online }
        set {
            lock.lock()
            online = newValue
            let current = Array(observers.values)
            lock.unlock()
            current.forEach { $0(newValue) }
        }
    }

    private var pathReported = true

    /// Changes the network without telling the observers: a change the system's monitor missed.
    func setOnlineSilently(_ value: Bool) {
        lock.lock()
        online = value
        lock.unlock()
    }

    /// `false` plays a cold start: the monitor has not reported its first path yet.
    var hasPath: Bool {
        get { lock.lock(); defer { lock.unlock() }; return pathReported }
        set { lock.lock(); pathReported = newValue; lock.unlock() }
    }

    init(online: Bool, hasPath: Bool = true) {
        self.online = online
        self.pathReported = hasPath
    }

    func observe(_ handler: @escaping (Bool) -> Void) -> Cancellable {
        lock.lock()
        nextId += 1
        let id = nextId
        observers[id] = handler
        let current = online
        lock.unlock()
        handler(current)
        return Cancellable { [weak self] in
            guard let self = self else { return }
            self.lock.lock(); self.observers[id] = nil; self.lock.unlock()
        }
    }
}

/// App lifecycle events sent by the test.
final class ManualAppLifecycle: AppLifecycle {
    private let lock = NSLock()
    private var observers: [Int: (AppLifecycleEvent) -> Void] = [:]
    private var nextId = 0

    var observerCount: Int {
        lock.lock(); defer { lock.unlock() }
        return observers.count
    }

    func observe(_ handler: @escaping (AppLifecycleEvent) -> Void) -> Cancellable {
        lock.lock()
        nextId += 1
        let id = nextId
        observers[id] = handler
        lock.unlock()
        return Cancellable { [weak self] in
            guard let self = self else { return }
            self.lock.lock(); self.observers[id] = nil; self.lock.unlock()
        }
    }

    private var foreground = true
    private var begun = 0
    private var ended = 0

    /// In the foreground until the test sends the app to the background.
    var isInForeground: Bool {
        get { lock.lock(); defer { lock.unlock() }; return foreground }
        set { lock.lock(); foreground = newValue; lock.unlock() }
    }

    /// The background tasks begun and ended.
    var backgroundTasks: (begun: Int, ended: Int) {
        lock.lock(); defer { lock.unlock() }
        return (begun, ended)
    }

    func beginBackgroundTask(_ name: String, expiration: @escaping () -> Void) -> Cancellable {
        lock.lock(); begun += 1; lock.unlock()
        return Cancellable { [weak self] in
            guard let self = self else { return }
            self.lock.lock(); self.ended += 1; self.lock.unlock()
        }
    }

    func send(_ event: AppLifecycleEvent) {
        lock.lock()
        foreground = event == .willEnterForeground
        let current = Array(observers.values)
        lock.unlock()
        current.forEach { $0(event) }
    }
}

/// A value written on one thread and read on another: a test's shared variable.
final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    var current: Value {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
    func mutate(_ change: (inout Value) -> Void) {
        lock.lock(); change(&value); lock.unlock()
    }
}

// MARK: - Contract fixtures

// `ContractFixtures`, the loader of the contract's shared fixtures, is the package tests' own file
// (`Tests/REES46CoreTests/ContractFixtures.swift`), which this target compiles too: the simulator reads
// the Mac's file system, so the copy of the fixtures is one for both.

// MARK: - Tests

final class CoreHarnessTests: XCTestCase {

    private var shopId = ""

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        shopId = StubSDK.shopId()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubSDK.removeSavedInit(shopId: shopId)
        super.tearDown()
    }

    func test_the_manual_scheduler_runs_due_work_in_order_and_skips_what_was_cancelled() {
        let clock = FakeClock()
        let scheduler = ManualScheduler(clock: clock)
        var ran: [String] = []
        scheduler.schedule(after: 10) { ran.append("10s") }
        scheduler.schedule(after: 5) { ran.append("5s") }
        scheduler.schedule(after: 7) { ran.append("cancelled") }.cancel()

        scheduler.advance(by: 6)
        XCTAssertEqual(ran, ["5s"])
        scheduler.advance(by: 4)
        XCTAssertEqual(ran, ["5s", "10s"])
        XCTAssertEqual(scheduler.pending, 0)
    }

    func test_the_dispatch_scheduler_runs_work_and_a_cancelled_one_does_not() {
        let scheduler = DispatchScheduler()
        let ran = expectation(description: "ran")
        var cancelledRan = false
        scheduler.schedule(after: 0.05) { ran.fulfill() }
        scheduler.schedule(after: 0.05) { cancelledRan = true }.cancel()
        wait(for: [ran], timeout: 2)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(cancelledRan)
    }

    func test_the_system_lifecycle_reports_background_and_foreground_until_cancelled() {
        var events: [AppLifecycleEvent] = []
        let subscription = SystemAppLifecycle.shared.observe { events.append($0) }
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        subscription.cancel()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertEqual(events, [.didEnterBackground, .willEnterForeground])
    }

    func test_a_failed_request_is_offline_only_when_the_monitor_says_so() {
        let connectivity = FakeConnectivity(online: true)
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId, connectivity: connectivity) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        StubURLProtocol.handler = { $0.path == "/init" ? StubURLProtocol.defaultHandler($0) : StubReply.noAnswer }

        func failure() -> SdkError? {
            let done = expectation(description: "done")
            var error: SdkError?
            sdk.postRequest(path: "push", params: ["event": "view"]) { result in
                if case let .failure(failure) = result { error = failure }
                done.fulfill()
            }
            wait(for: [done], timeout: 5)
            return error
        }

        guard case .invalidResponse? = failure() else { return XCTFail("online: expected invalidResponse") }
        connectivity.isOnline = false
        guard case .networkOfflineError? = failure() else { return XCTFail("offline: expected networkOfflineError") }
    }

    func test_the_stub_server_sends_headers_holds_answers_back_and_cuts_bodies() {
        StubURLProtocol.handler = { request in
            switch request.path {
            case "/headers": return StubReply(429, headers: ["Retry-After": "7"])
            case "/slow": return StubReply(delay: 0.3)
            case "/cut": return StubReply(json: #"{"products":[1,2,3,4,5,6,7,8]}"#, cutAfter: 5)
            default: return StubReply()
            }
        }
        let session = URLSession(configuration: .default)

        func load(_ path: String) -> (HTTPURLResponse?, Error?, TimeInterval) {
            let done = expectation(description: path)
            var response: HTTPURLResponse?
            var failure: Error?
            let started = Date()
            session.dataTask(with: URL(string: "https://stub.test\(path)")!) { _, answer, error in
                response = answer as? HTTPURLResponse
                failure = error
                done.fulfill()
            }.resume()
            wait(for: [done], timeout: 5)
            return (response, failure, Date().timeIntervalSince(started))
        }

        let headers = load("/headers")
        XCTAssertEqual(headers.0?.statusCode, 429)
        XCTAssertEqual(headers.0?.value(forHTTPHeaderField: "Retry-After"), "7")
        XCTAssertGreaterThanOrEqual(load("/slow").2, 0.3)
        XCTAssertNotNil(load("/cut").1, "a cut body ends in an error, not in success")
    }

    func test_the_contract_fixtures_are_the_shared_ones() throws {
        for name in ["init", "tracking"] {
            let fixture = try ContractFixtures.load(name)
            XCTAssertEqual(fixture["contract"] as? String, ContractFixtures.version, name)
            let cases = try ContractFixtures.cases(name)
            XCTAssertFalse(cases.isEmpty, name)
            for item in cases {
                XCTAssertNotNil(item["name"] as? String, name)
                XCTAssertTrue(item["call"] != nil || item["response"] != nil, "\(name): \(item["name"] ?? "?")")
            }
        }
    }
}
