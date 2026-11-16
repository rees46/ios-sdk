//
//  EventQueueTests.swift
//  REES46Tests
//
//  The event queue on its own, with a host the test answers for: an answer that comes after its
//  instance was released, files another queue of the folder writes after this one read it, a clear
//  that does not wait for the queue's thread, and the wait of `deleteUserCredentials()` for the files of
//  a clear to be gone.
//

import XCTest
@testable import REES46

/// A host whose sends wait for the test's answer and whose gate the test may hold.
private final class FakeQueueHost: EventQueueHost {
    let clock = FakeClock()
    let scheduler: ManualScheduler
    init() { scheduler = ManualScheduler(clock: clock) }
    let connectivity = FakeConnectivity(online: true)
    let sent = Locked<[NetworkClient.Request]>([])
    private let waiting = Locked<[CheckedContinuation<NetworkClient.Response, Never>]>([])
    /// Held: the gate waits for it, once.
    let gateHold = Locked<DispatchSemaphore?>(nil)
    let gateEntered = DispatchSemaphore(value: 0)
    /// Whether the queue's thread is in the held gate now.
    let gateHolding = Locked(false)

    func queueGate(for path: String) -> EventQueue.Gate {
        if let hold = gateHold.current {
            gateHold.current = nil
            gateHolding.current = true
            gateEntered.signal()
            _ = hold.wait(timeout: .now() + 10)
            gateHolding.current = false
        }
        return .open
    }

    func queueSend(_ request: NetworkClient.Request) async -> NetworkClient.Response {
        sent.mutate { $0.append(request) }
        return await withCheckedContinuation { continuation in
            waiting.mutate { $0.append(continuation) }
        }
    }

    /// Answers the oldest send that waits.
    func answer(_ response: NetworkClient.Response) {
        var next: CheckedContinuation<NetworkClient.Response, Never>?
        waiting.mutate { if !$0.isEmpty { next = $0.removeFirst() } }
        next?.resume(returning: response)
    }

    var waitingSends: Int { waiting.current.count }

    func queueCheckShop() -> InitMachine.ShopCheck { .notAsked }
    func queueSource() -> [String: String]? { nil }
    func queueIdentity() -> CommonFields.Identity { CommonFields.Identity(deviceId: "d", sessionId: "s") }
    func queueDelivered(_ event: EventQueue.Delivered) {}
    var queueEnvironment: CoreEnvironment { CoreEnvironment(clock: clock, scheduler: scheduler, lifecycle: ManualAppLifecycle(), random: { 0.5 }) }
    var queueConnectivity: ConnectivityMonitor { connectivity }
}

final class EventQueueTests: XCTestCase {

    private var root: URL!
    private var shop = ""

    override func setUp() {
        super.setUp()
        shop = "queue-\(UUID().uuidString.prefix(8))"
        root = FileManager.default.temporaryDirectory.appendingPathComponent("queue-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    private func storage() -> ShopStorage {
        ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .none), partition: UserDefaults(suiteName: "test-\(shop)"), root: root)
    }

    private func files(_ storage: ShopStorage) -> [String] {
        guard let folder = storage.queueDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".json") }.sorted()
    }

    private static let ok = NetworkClient.Response(status: 200, body: Data(), retryAfter: nil, result: .success([String: Any]()))

    /// The clock every host of a test shares: events are made on it.
    private let clock = FakeClock()

    private func take(_ queue: EventQueue, _ id: String, completion: ((EventQueue.Outcome) -> Void)? = nil) {
        queue.enqueue(path: "push", body: ["event": "view", "items": [["id": id]]], createdAt: clock.now(), completion: completion, unstored: { _ in })
    }

    private func ids(_ requests: [NetworkClient.Request]) -> [String] {
        requests.compactMap { (($0.body["items"] as? [[String: Any]])?.first?["id"]) as? String }
    }

    func test_a_2xx_that_comes_after_release_still_deletes_the_events_file() {
        let store = storage()
        let host = FakeQueueHost()
        let queue = EventQueue.attach(host, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        take(queue, "a")
        XCTAssertTrue(eventually { host.waitingSends == 1 })
        XCTAssertEqual(files(store).count, 1)

        queue.detach(host)
        queue.settle()
        host.answer(Self.ok)
        XCTAssertTrue(eventually { self.files(store).isEmpty }, "the server has it: not sent again on the next launch")

        // The next instance of the shop has nothing to send.
        let next = FakeQueueHost()
        let again = EventQueue.attach(next, storage: storage(), logger: SdkLogger(shopId: shop, level: .none))
        let flushed = expectation(description: "flushed")
        again.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertTrue(next.sent.current.isEmpty)
        withExtendedLifetime(queue) {}
    }

    func test_a_new_queue_finds_the_files_a_released_one_wrote_after_it_read_the_folder_and_names_never_clash() {
        let store = storage()
        let first = FakeQueueHost()
        let old = EventQueue.attach(first, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        first.connectivity.isOnline = false
        take(old, "a")
        old.settle()
        old.detach(first)
        old.settle()

        let second = FakeQueueHost()
        second.connectivity.isOnline = false
        let current = EventQueue.attach(second, storage: storage(), logger: SdkLogger(shopId: shop, level: .none))
        take(current, "b")
        current.settle()
        // The released queue takes one more event: on disk, for whoever sends the shop's queue.
        take(old, "c")
        old.settle()
        XCTAssertEqual(Set(files(store)).count, 3, "three files, three names")

        second.connectivity.isOnline = true
        let flushed = expectation(description: "flushed")
        current.flush { flushed.fulfill() }
        for _ in 0..<3 {
            XCTAssertTrue(eventually { second.waitingSends == 1 })
            second.answer(Self.ok)
        }
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(ids(second.sent.current), ["a", "b", "c"])
        XCTAssertTrue(eventually { self.files(store).isEmpty })
    }

    func test_each_lane_keeps_its_order_and_a_pause_of_the_tracking_does_not_hold_the_events_of_pushes() {
        let store = storage()
        let host = FakeQueueHost()
        let queue = EventQueue.attach(host, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        take(queue, "a")
        XCTAssertTrue(eventually { host.waitingSends == 1 })
        take(queue, "b")
        queue.enqueue(path: "track/delivered", body: ["code": "m-1", "type": "bulk"], createdAt: clock.now(), completion: nil, unstored: { _ in })
        queue.enqueue(path: "track/clicked", body: ["code": "m-1", "type": "bulk"], createdAt: clock.now(), completion: nil, unstored: { _ in })
        // The tracking's event is on its way: the push lane goes beside it.
        XCTAssertTrue(eventually { host.waitingSends == 2 })
        XCTAssertEqual(host.sent.current.map(\.path), ["push", "track/delivered"])

        // The tracking gets a server error and pauses; the push lane goes on, in its order.
        host.answer(NetworkClient.Response(status: 500, body: Data(), retryAfter: nil, result: .failure(.http(code: 500, serverCode: nil))))
        host.answer(Self.ok)
        XCTAssertTrue(eventually { host.waitingSends == 1 })
        XCTAssertEqual(host.sent.current.map(\.path), ["push", "track/delivered", "track/clicked"])
        host.answer(Self.ok)
        XCTAssertTrue(eventually { queue.inFlightCount == 0 })
        XCTAssertEqual(queue.waiting.map { $0.path }, ["push", "push"], "the tracking waits out its pause")
        XCTAssertEqual(host.scheduler.pendingDelays.first, 1, "its own pause, after one failure")

        host.scheduler.advance(by: 1)
        XCTAssertTrue(eventually { host.waitingSends == 1 })
        XCTAssertEqual(ids(host.sent.current), ["a", "a"], "the tracking in its order: the one that failed first")
    }

    func test_clear_returns_without_waiting_for_the_queues_thread_and_no_event_taken_before_it_goes() {
        let store = storage()
        let host = FakeQueueHost()
        let queue = EventQueue.attach(host, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        let hold = DispatchSemaphore(value: 0)
        defer { hold.signal() }
        host.gateHold.current = hold
        let outcome = Locked<EventQueue.Outcome?>(nil)
        take(queue, "old") { outcome.current = $0 }
        // The queue's thread is busy deciding to send it.
        XCTAssertEqual(host.gateEntered.wait(timeout: .now() + 5), .success)

        queue.clear(error: .cancelled, reason: "delete_user_credentials")
        // Had it waited for the queue's thread, that thread would have left the gate first.
        XCTAssertTrue(host.gateHolding.current, "it returned while the queue's thread was still busy")
        take(queue, "new")
        hold.signal()

        XCTAssertTrue(eventually { host.waitingSends == 1 })
        XCTAssertEqual(ids(host.sent.current), ["new"], "the event taken before the clear never went")
        guard case .failed(.cancelled, _)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        host.answer(Self.ok)
        XCTAssertTrue(eventually { self.files(store).isEmpty })
    }

    func test_await_clear_returns_once_the_files_are_gone_also_when_the_queues_thread_was_busy() {
        let store = storage()
        let host = FakeQueueHost()
        let queue = EventQueue.attach(host, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        let hold = DispatchSemaphore(value: 0)
        defer { hold.signal() }
        host.gateHold.current = hold
        let outcome = Locked<EventQueue.Outcome?>(nil)
        take(queue, "old") { outcome.current = $0 }
        // The queue's thread is busy deciding to send it, and its file is on disk.
        XCTAssertEqual(host.gateEntered.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(files(store).count, 1)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { hold.signal() }

        queue.clear(error: .cancelled, reason: "delete_user_credentials")
        queue.awaitClear()

        XCTAssertFalse(host.gateHolding.current, "it waited for the queue's thread")
        XCTAssertTrue(files(store).isEmpty, "gone when it returns: a process that ends now leaves none")
        queue.settle()
        XCTAssertTrue(host.sent.current.isEmpty, "the event taken before it never went")
        XCTAssertTrue(eventually { outcome.current != nil })
        guard case .failed(.cancelled, _)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
    }

    // MARK: - A new queue while a released one's event is on its way (Q-H2)

    func test_a_new_queue_does_not_send_again_an_event_the_released_queue_has_on_its_way() {
        let store = storage()
        let first = FakeQueueHost()
        let old = EventQueue.attach(first, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        take(old, "a")
        XCTAssertTrue(eventually { first.waitingSends == 1 })
        old.detach(first)
        old.settle()

        let second = FakeQueueHost()
        let current = EventQueue.attach(second, storage: storage(), logger: SdkLogger(shopId: shop, level: .none))
        let flushed = expectation(description: "flushed")
        current.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertTrue(second.sent.current.isEmpty, "it is on its way: the new queue waits for its answer")

        first.answer(Self.ok)
        XCTAssertTrue(eventually { self.files(store).isEmpty })
        current.settle()
        XCTAssertEqual(current.inFlightCount, 0)
        XCTAssertTrue(second.sent.current.isEmpty, "delivered: never sent again")
        withExtendedLifetime(old) {}
    }

    func test_a_new_queue_sends_once_an_event_the_released_queues_send_lost() {
        let store = storage()
        let first = FakeQueueHost()
        let old = EventQueue.attach(first, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        take(old, "a")
        XCTAssertTrue(eventually { first.waitingSends == 1 })
        old.detach(first)
        old.settle()
        let second = FakeQueueHost()
        let current = EventQueue.attach(second, storage: storage(), logger: SdkLogger(shopId: shop, level: .none))

        // The released queue's send was cancelled: the new queue, woken by its answer, sends it once.
        first.answer(.failure(.cancelled))
        XCTAssertTrue(eventually { second.waitingSends == 1 })
        XCTAssertEqual(ids(second.sent.current), ["a"])
        second.answer(Self.ok)
        XCTAssertTrue(eventually { self.files(store).isEmpty })
        current.settle()
        XCTAssertEqual(ids(second.sent.current), ["a"], "once")
        withExtendedLifetime(old) {}
    }

    // MARK: - A stopped queue that wrote the event (b6c2003)

    func test_a_stopped_queue_that_wrote_the_event_accepts_it_and_sends_nothing() {
        let store = storage()
        let host = FakeQueueHost()
        let queue = EventQueue.attach(host, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        queue.detach(host)
        queue.settle()

        let heard = Locked<[String]>([])
        let done = expectation(description: "both")
        done.expectedFulfillmentCount = 2
        queue.enqueue(
            path: "track/delivered", body: ["code": "m-1", "type": "bulk"], createdAt: clock.now(),
            accepted: { error in heard.mutate { $0.append("accepted:\(error.map { "\($0)" } ?? "nil")") }; done.fulfill() },
            completion: { _ in heard.mutate { $0.append("completion") }; done.fulfill() },
            unstored: { _ in XCTFail("written") }
        )
        wait(for: [done], timeout: 5)
        // On disk it counts as accepted — the shop's next queue sends it —, and it was told first.
        XCTAssertEqual(heard.current, ["accepted:nil", "completion"])
        XCTAssertEqual(files(store).count, 1)
        queue.settle()
        XCTAssertTrue(host.sent.current.isEmpty, "a stopped queue sends nothing")
    }

    func test_a_cleared_queue_tells_accepted_before_the_callback() {
        let store = storage()
        let host = FakeQueueHost()
        let queue = EventQueue.attach(host, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        let hold = DispatchSemaphore(value: 0)
        defer { hold.signal() }
        host.gateHold.current = hold
        take(queue, "busy")
        XCTAssertEqual(host.gateEntered.wait(timeout: .now() + 5), .success)

        let heard = Locked<[String]>([])
        let done = expectation(description: "both")
        done.expectedFulfillmentCount = 2
        queue.enqueue(
            path: "push", body: ["event": "view"], createdAt: clock.now(),
            accepted: { _ in heard.mutate { $0.append("accepted") }; done.fulfill() },
            completion: { _ in heard.mutate { $0.append("completion") }; done.fulfill() },
            unstored: { _ in }
        )
        queue.clear(error: .cancelled, reason: "delete_user_credentials")
        hold.signal()
        wait(for: [done], timeout: 5)
        XCTAssertEqual(heard.current, ["accepted", "completion"])
    }

    // MARK: - A 2xx after release()

    func test_an_answer_the_client_calls_cancelled_after_release_but_with_a_2xx_deletes_the_event() {
        let store = storage()
        let host = FakeQueueHost()
        let queue = EventQueue.attach(host, storage: store, logger: SdkLogger(shopId: shop, level: .none))
        let outcome = Locked<EventQueue.Outcome?>(nil)
        take(queue, "a") { outcome.current = $0 }
        XCTAssertTrue(eventually { host.waitingSends == 1 })
        // The client's answer once release() came: cancelled, with the 2xx it got.
        host.answer(NetworkClient.Response(status: 200, body: Data(#"{"status":"success"}"#.utf8), retryAfter: nil, result: .failure(.cancelled)))
        XCTAssertTrue(eventually { self.files(store).isEmpty }, "the server has it")
        XCTAssertTrue(eventually { outcome.current != nil })
        guard case .sent? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        queue.settle()
        XCTAssertEqual(host.sent.current.count, 1, "not sent again")
    }
}
