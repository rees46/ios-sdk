//
//  CoreQueueTests.swift
//  REES46Tests
//
//  The event queue of the new core (`sdk/core/queue.md`, decision 0002) over the stub server, with the
//  clock, the scheduler, the network and the app's lifecycle in the test's hands: events on disk and in
//  order, what is stamped when they go, every row of the answer table, the limits, a restart, the
//  triggers and `flush()`, clearing, `release()`, the popup of a `/push` answer, the old callbacks, one
//  owner per shop, the window of the session, and the shared tracking fixtures.
//

import UIKit
import XCTest
@testable import REES46

final class CoreQueueTests: XCTestCase {

    private var shops: [String] = []
    private var clock = FakeClock()
    private var scheduler: ManualScheduler!
    private var lifecycle = ManualAppLifecycle()
    private var network = FakeConnectivity(online: true)
    /// Replies queued per path; the last one repeats. `.some(nil)` is no answer.
    private let replies = Locked<[String: [StubReply?]]>([:])
    private let logs = Locked<[Rees46.SdkLogMessage]>([])
    /// The shops of this test: the replies it queues are theirs. An SDK an earlier test left may still
    /// send to the stub server; it gets the default answer.
    private let ownShops = Locked<Set<String>>([])

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        clock = FakeClock()
        scheduler = ManualScheduler(clock: clock)
        lifecycle = ManualAppLifecycle()
        network = FakeConnectivity(online: true)
        replies.current = [:]
        logs.current = []
        let logs = self.logs
        Rees46.setLogHandler { message in logs.mutate { $0.append(message) } }
        let replies = self.replies
        let inits = Locked(0)
        ownShops.current = []
        let ownShops = self.ownShops
        StubURLProtocol.handler = { request in
            let shop = request.query["shop_id"] ?? request.body["shop_id"] as? String
            guard shop.map({ ownShops.current.contains($0) }) ?? true else {
                return request.path == "/init" ? StubReply(json: #"{"did":"other-did","seance":"other"}"#) : StubReply(json: #"{"status":"success"}"#)
            }
            var reply: StubReply??
            replies.mutate { queued in
                guard var list = queued[request.path], !list.isEmpty else { return }
                reply = .some(list.count > 1 ? list.removeFirst() : list[0])
                queued[request.path] = list
            }
            if let reply = reply {
                return reply
            }
            if request.path == "/init" {
                var call = 0
                inits.mutate { $0 += 1; call = $0 }
                return StubReply(json: #"{"did":"d","seance":"s-\#(call)"}"#)
            }
            return StubReply(json: #"{"status":"success"}"#)
        }
    }

    override func tearDown() {
        Rees46.setLogHandler(nil)
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        shops.forEach { StubSDK.removeSavedInit(shopId: $0) }
        shops.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private var environment: CoreEnvironment {
        CoreEnvironment(clock: clock, scheduler: scheduler, lifecycle: lifecycle, random: { 0.5 })
    }

    private func newShop() -> String {
        let shop = StubSDK.shopId()
        shops.append(shop)
        ownShops.mutate { _ = $0.insert(shop) }
        return shop
    }

    private func answer(_ path: String, _ list: StubReply?...) {
        replies.mutate { $0[path] = list }
    }

    /// An instance of the new core: a known device inside its session's window — ready at once — unless
    /// the test brings its own identity. `settled`: the launch's `/init` has answered and the queue
    /// heard it, so it does not kick the queue in the middle of the test.
    private func make(_ shop: String, identity: UserIdentityRepository? = nil, settled: Bool = true) -> SimplePersonalizationSDK {
        let known = InMemoryUserIdentityRepository()
        known.deviceId = "d"
        known.seance = "s-0"
        known.seanceLastActTime = clock.now()
        let sdk = StubSDK.make(
            shopId: shop, identity: identity ?? known, logLevel: .debug, connectivity: network,
            coreV2: true, environment: environment
        )
        if settled {
            // Settled once the launch's /init answered and the queue heard it — `didSettle` comes after
            // `initSucceeded` and kicks the queue last —, and the queue did what it was told.
            // A stored device id settles once at the start, ready at once (decision 1), then on the answer.
            let settles = ((identity ?? known).deviceId ?? "").isEmpty ? 1 : 2
            XCTAssertTrue(eventually { sdk.settledInitCount >= settles }, "the launch's /init answered")
            sdk.eventQueue?.settle()
        }
        return sdk
    }

    private func requests(_ path: String, _ shop: String) -> [StubRequest] {
        StubURLProtocol.requests(to: path, shop: shop)
    }

    private func files(_ sdk: SimplePersonalizationSDK) -> [String] {
        guard let folder = sdk.storage.queueDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".json") }.sorted()
    }

    /// What the log handler heard: every message logged before the call. The handler hears them on a
    /// queue of its own, after what the SDK did next — a callback, a request —, so a test reads them
    /// through this, and waits (`eventually`) for one logged after what it waited for.
    private var heard: [Rees46.SdkLogMessage] {
        SdkLogger.awaitDelivery()
        return logs.current
    }

    private func dropped(_ shop: String) -> [Rees46.SdkLogMessage] {
        heard.filter { $0.shopId == shop && $0.code == "queue_dropped" }
    }

    private func itemIds(_ requests: [StubRequest]) -> [String] {
        requests.compactMap { (($0.body["items"] as? [[String: Any]])?.first?["id"]) as? String }
    }

    /// Runs `body` with no network, then gives the network back.
    private func offline(_ body: () -> Void) {
        network.isOnline = false
        body()
        network.isOnline = true
    }

    // MARK: - On disk, in order

    func test_an_event_is_on_disk_before_it_goes_and_is_deleted_once_sent() {
        let shop = newShop()
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        let sdk = make(shop)
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/push", (request.query["shop_id"] ?? request.body["shop_id"] as? String) == shop { _ = held.wait(timeout: .now() + 10) }
            return handler(request)
        }
        let done = expectation(description: "sent")
        let result = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.productView(itemId: "37") { result.current = $0; done.fulfill() }
        sdk.eventQueue?.settle()

        XCTAssertEqual(files(sdk).count, 1, "accepted: written to disk")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertNil(result.current, "the old callback hears once it was sent, not when it was queued")
        held.signal()
        wait(for: [done], timeout: 5)
        guard case .success? = result.current else { return XCTFail("\(String(describing: result.current))") }
        XCTAssertTrue(eventually { self.files(sdk).isEmpty }, "deleted once the server has it")
    }

    func test_events_go_one_at_a_time_in_the_order_of_the_calls() {
        let shop = newShop()
        let sdk = make(shop)
        let busy = Locked(0)
        let most = Locked(0)
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            guard request.path == "/push" else { return handler(request) }
            busy.mutate { $0 += 1 }
            most.mutate { $0 = max($0, busy.current) }
            Thread.sleep(forTimeInterval: 0.02)
            busy.mutate { $0 -= 1 }
            return handler(request)
        }
        let ids = (1...8).map { "item-\($0)" }
        ids.forEach { sdk.tracking.productView(itemId: $0) }

        XCTAssertTrue(eventually { self.requests("/push", shop).count == 8 })
        XCTAssertEqual(itemIds(requests("/push", shop)), ids)
        XCTAssertEqual(most.current, 1)
    }

    func test_sid_and_the_stored_source_are_stamped_when_the_event_goes_and_time_only_on_push_custom() {
        let shop = newShop()
        let sdk = make(shop)
        let created = Int(clock.now().timeIntervalSince1970)
        offline {
            sdk.tracking.productView(itemId: "37")
            sdk.tracking.custom(event: "compare")
            sdk.tracking.storyView(storyId: "12", slideId: "34", code: "main")
            sdk.eventQueue?.settle()
            // After the events were made: a new source, and the window runs out.
            sdk.tracking.setSource(TrackingSource(type: .chain, code: "c-9"))
            clock.advance(by: 2 * 60 * 60 + 1)
        }

        XCTAssertTrue(eventually { self.requests("/track/stories", shop).count == 1 })
        XCTAssertEqual(requests("/init", shop).count, 2, "/init first: the window ran out")
        let push = requests("/push", shop).first?.body ?? [:]
        XCTAssertEqual(push["sid"] as? String, "s-2", "the sid when it went, not when it was made")
        XCTAssertEqual(push["seance"] as? String, "s-2")
        XCTAssertEqual(push["did"] as? String, "d")
        XCTAssertEqual(push["source"] as? [String: String], ["from": "chain", "code": "c-9"], "an object, the one stored when it went")
        XCTAssertNil(push["time"], "/push does not read it")
        let custom = requests("/push/custom", shop).first?.body ?? [:]
        XCTAssertEqual(custom["time"] as? Int, created, "the time it was made")
        XCTAssertNil(custom["source"], "push/custom does not read it")
        XCTAssertEqual(custom["sid"] as? String, "s-2")
        let story = requests("/track/stories", shop).first?.body ?? [:]
        XCTAssertNil(story["source"])
        XCTAssertNil(story["time"])
        XCTAssertEqual(story["story_id"] as? Int, 12, "a number on the new core's wire")
    }

    // MARK: - The answers

    func test_without_network_an_event_waits_for_it_and_no_answer_online_is_repeated_without_counting() {
        let shop = newShop()
        let sdk = make(shop)
        network.isOnline = false
        expectNoRequest(to: "/push", shop: shop) {
            sdk.tracking.productView(itemId: "37")
        }
        // No answer though the monitor says online: repeated after a pause, more than ten times.
        answer("/push", StubReply.noAnswer, StubReply.noAnswer, StubReply.noAnswer, StubReply.noAnswer, StubReply.noAnswer,
               StubReply.noAnswer, StubReply.noAnswer, StubReply.noAnswer, StubReply.noAnswer, StubReply.noAnswer,
               StubReply.noAnswer, StubReply(json: #"{"status":"success"}"#))
        network.isOnline = true
        for attempt in 1...11 {
            XCTAssertTrue(eventually { self.requests("/push", shop).count == attempt && self.scheduler.pending == 1 }, "attempt \(attempt)")
            scheduler.advance(by: scheduler.pendingDelays.first ?? 0)
        }
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 12 && self.files(sdk).isEmpty })
        XCTAssertTrue(dropped(shop).isEmpty, "no answer is not counted")
    }

    func test_a_timeout_is_repeated_after_a_growing_pause_without_counting() {
        let shop = newShop()
        let sdk = make(shop)
        let cut = StubReply(json: #"{"status":"success"}"#, cutAfter: 2, cutWith: .timedOut)
        answer("/push", cut, cut, cut, cut, cut, cut, cut, cut, cut, cut, cut, StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "37")
        var pauses: [TimeInterval] = []
        for attempt in 1...11 {
            XCTAssertTrue(eventually { self.requests("/push", shop).count == attempt && self.scheduler.pending == 1 }, "attempt \(attempt)")
            let pause = scheduler.pendingDelays.first ?? 0
            pauses.append(pause)
            scheduler.advance(by: pause)
        }
        XCTAssertEqual(Array(pauses.prefix(10)), [1, 2, 4, 8, 16, 32, 64, 128, 256, 300])
        XCTAssertTrue(eventually { self.files(sdk).isEmpty })
        XCTAssertTrue(dropped(shop).isEmpty)
    }

    func test_passing_server_errors_are_repeated_with_retry_after_and_the_event_is_dropped_after_ten() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push",
               StubReply(503, headers: ["Retry-After": "7"]), StubReply(429, headers: ["Retry-After": "9999"]),
               StubReply(500, headers: ["Retry-After": "7"]), StubReply(408), StubReply(410), StubReply(417),
               StubReply(426), StubReply(502), StubReply(504), StubReply(500, json: #"{"status":"error","message":"down"}"#),
               StubReply(json: #"{"status":"success"}"#))
        let first = expectation(description: "dropped")
        let result = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.productView(itemId: "first") { result.current = $0; first.fulfill() }
        sdk.tracking.productView(itemId: "second")
        var pauses: [TimeInterval] = []
        for attempt in 1...10 {
            XCTAssertTrue(eventually { self.requests("/push", shop).count == attempt && self.scheduler.pending == 1 }, "attempt \(attempt)")
            let pause = scheduler.pendingDelays.first ?? 0
            pauses.append(pause)
            scheduler.advance(by: pause)
        }
        wait(for: [first], timeout: 5)
        // Retry-After of a 503 and a 429, held to five minutes; a 500's is not one.
        XCTAssertEqual(Array(pauses.prefix(3)), [7, 300, 4])
        guard case .failure(.custom("down"))? = result.current else { return XCTFail("the old error: \(String(describing: result.current))") }
        XCTAssertTrue(eventually { self.dropped(shop).first?.context["reason"] == "attempts" })
        XCTAssertEqual(dropped(shop).first?.level, .warning)
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)).last == "second" }, "the queue goes on")
        XCTAssertTrue(eventually { self.files(sdk).isEmpty })
    }

    func test_402_403_404_pause_the_queue_and_ask_the_shop_and_a_passed_check_sends_the_event_again() {
        let shop = newShop()
        let sdk = make(shop)
        let check = DispatchSemaphore(value: 0)
        defer { check.signal() }
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init", (StubURLProtocol.requests(to: "/init").count) > 1 {
                _ = check.wait(timeout: .now() + 10)
            }
            return handler(request)
        }
        sdk.tracking.productView(itemId: "first")
        XCTAssertTrue(eventually { self.requests("/init", shop).count == 2 }, "the shop is asked")
        // Paused while it is asked: the next event waits.
        expectNoRequest(to: "/push", shop: shop) {
            sdk.tracking.productView(itemId: "second")
        }
        XCTAssertEqual(requests("/push", shop).count, 1)
        check.signal()
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 3 })
        XCTAssertEqual(itemIds(requests("/push", shop)), ["first", "first", "second"])
        XCTAssertTrue(dropped(shop).isEmpty)
    }

    func test_the_same_refusal_after_a_passed_check_drops_the_event_and_the_queue_goes_on() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push/custom", StubReply(403))
        let first = expectation(description: "first")
        let result = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.custom(event: "no-crm") { result.current = $0; first.fulfill() }
        sdk.tracking.productView(itemId: "second")
        wait(for: [first], timeout: 5)
        guard case .failure? = result.current else { return XCTFail("dropped") }
        // The log handler hears it on a queue of its own, not before the callback.
        XCTAssertTrue(eventually { !self.dropped(shop).isEmpty })
        XCTAssertEqual(dropped(shop).first?.context["reason"], "service_refused")
        XCTAssertEqual(requests("/init", shop).count, 2, "one check")
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["second"] })

        // The shop passed a check less than ten minutes ago and is ready: the same answer to another
        // event is the service's refusal — it is dropped at once, and the queue does not wait.
        answer("/push", StubReply(404), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "third")
        sdk.tracking.productView(itemId: "fourth")
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["second", "third", "fourth"] })
        XCTAssertTrue(eventually { self.dropped(shop).count == 2 })
        XCTAssertEqual(dropped(shop).last?.context["reason"], "service_refused")
        XCTAssertEqual(requests("/init", shop).count, 2, "not asked again within ten minutes")
        // The request of "fourth" was seen; its file goes once the answer is back.
        XCTAssertTrue(eventually { self.files(sdk).isEmpty })
    }

    func test_a_refusal_in_the_background_asks_the_shop_only_once_the_app_is_in_the_foreground() {
        let shop = newShop()
        let sdk = make(shop)
        let inits = requests("/init", shop).count
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        lifecycle.send(.didEnterBackground)
        sdk.tracking.productView(itemId: "first")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && sdk.eventQueue?.inFlightCount == 0 })
        // The flush ends without waiting for the check, which waits for the foreground: no read timeout
        // runs out on the test's scheduler.
        let flushed = expectation(description: "flushed")
        sdk.flush { _ in flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertFalse(scheduler.pendingDelays.contains(10), "it did not wait for the instance")
        sdk.eventQueue?.settle()
        XCTAssertEqual(requests("/init", shop).count, inits, "no /init from the background")
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 1, "the event waits for the check")

        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.requests("/init", shop).count == inits + 1 }, "asked once in the foreground")
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["first", "first"] }, "checked and sent again")
        XCTAssertTrue(dropped(shop).isEmpty)
    }

    func test_a_refusal_in_the_background_is_answered_by_an_init_that_comes_before_the_foreground() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push", StubReply(403), StubReply(json: #"{"status":"success"}"#))
        lifecycle.send(.didEnterBackground)
        sdk.tracking.productView(itemId: "first")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && sdk.eventQueue?.inFlightCount == 0 })
        sdk.eventQueue?.settle()
        // An /init that answers meanwhile, whatever sent it, answers the check.
        sdk.eventQueue?.initSucceeded()
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["first", "first"] }, "checked by it")
        XCTAssertTrue(dropped(shop).isEmpty)
    }

    func test_a_refusal_while_the_last_check_is_still_on_its_way_waits_for_its_answer() {
        let shop = newShop()
        let sdk = make(shop)
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init", (request.query["shop_id"] ?? request.body["shop_id"] as? String) == shop { _ = held.wait(timeout: .now() + 10) }
            return handler(request)
        }
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.requests("/init", shop).count == 2 }, "the check")
        XCTAssertEqual(requests("/push", shop).count, 1)
        held.signal()
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["a", "a"] }, "sent again once checked")
        XCTAssertTrue(dropped(shop).isEmpty)
    }

    func test_a_refusal_of_the_shop_clears_the_queue_and_takes_no_new_events() {
        let shop = newShop()
        answer("/init", StubReply(json: #"{"did":"d","seance":"s-1"}"#), StubReply(404))
        let sdk = make(shop)
        answer("/push", StubReply(404))
        let first = expectation(description: "first")
        let second = expectation(description: "second")
        let results = Locked<[Result<Void, SdkError>]>([])
        offline {
            sdk.tracking.productView(itemId: "first") { r in results.mutate { $0.append(r) }; first.fulfill() }
            sdk.tracking.productView(itemId: "second") { r in results.mutate { $0.append(r) }; second.fulfill() }
            sdk.eventQueue?.settle()
        }
        wait(for: [first, second], timeout: 5)
        XCTAssertEqual(sdk.state, .refused)
        // Cleared by the refusal: `cancelled` (`sdk/core/queue.md`), which the old callbacks hear as
        // `invalidResponse`; a new event is refused at once with `shopBlocked`.
        for result in results.current {
            guard case .failure(.invalidResponse) = result else { return XCTFail("\(result)") }
        }
        XCTAssertTrue(files(sdk).isEmpty, "cleared")
        // The log handler hears it on a queue of its own, not before the callbacks.
        XCTAssertTrue(eventually { self.dropped(shop).last?.context["reason"] == "refused" })

        let refused = expectation(description: "refused at once")
        expectNoRequest(to: "/push", shop: shop) {
            sdk.tracking.categoryView(categoryId: "1") { result in
                if case .failure(.custom("shop blocked")) = result { refused.fulfill() }
            }
        }
        wait(for: [refused], timeout: 1)
        XCTAssertTrue(files(sdk).isEmpty)
    }

    func test_any_other_4xx_drops_the_event_with_the_servers_message_and_the_queue_goes_on() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push", StubReply(422, json: #"{"status":"error","message":"bad item"}"#), StubReply(400), StubReply(json: #"{"status":"success"}"#))
        let results = Locked<[Result<Void, SdkError>]>([])
        let both = expectation(description: "both")
        both.expectedFulfillmentCount = 2
        sdk.tracking.productView(itemId: "a") { r in results.mutate { $0.append(r) }; both.fulfill() }
        sdk.tracking.productView(itemId: "b") { r in results.mutate { $0.append(r) }; both.fulfill() }
        sdk.tracking.productView(itemId: "c")
        wait(for: [both], timeout: 5)
        guard case .failure(.custom("bad item")) = results.current[0] else { return XCTFail("\(results.current[0])") }
        guard case .failure(.invalidResponse) = results.current[1] else { return XCTFail("\(results.current[1])") }
        XCTAssertTrue(eventually { self.dropped(shop).count == 2 })
        XCTAssertEqual(dropped(shop).map { $0.context["reason"] }, ["rejected", "rejected"])
        XCTAssertEqual(dropped(shop).map { $0.context["status"] }, ["422", "400"])
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["a", "b", "c"] })
        XCTAssertTrue(eventually { self.heard.contains { $0.shopId == shop && $0.code == "request_failed" && $0.level == .error } }, "a 4xx is an error")
    }

    // MARK: - Limits

    func test_an_event_older_than_seven_days_is_dropped_when_its_turn_comes() {
        let shop = newShop()
        let sdk = make(shop)
        offline {
            sdk.tracking.productView(itemId: "old")
            sdk.eventQueue?.settle()
            clock.advance(by: 7 * 24 * 60 * 60 + 1)
            sdk.tracking.productView(itemId: "new")
            sdk.eventQueue?.settle()
        }
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["new"] })
        XCTAssertTrue(eventually { self.dropped(shop).first?.context["reason"] == "expired" })
    }

    func test_a_shop_keeps_at_most_a_thousand_events_and_the_oldest_go_first() {
        let shop = newShop()
        let sdk = make(shop)
        network.isOnline = false
        for index in 1...1003 {
            sdk.tracking.productView(itemId: "item-\(index)")
        }
        let waiting = sdk.eventQueue?.waiting ?? []
        XCTAssertEqual(waiting.count, 1000)
        XCTAssertEqual((waiting.first?.body["items"] as? [[String: Any]])?.first?["id"] as? String, "item-4")
        XCTAssertEqual(files(sdk).count, 1000)
        // The queue logged the drops; the log handler, a queue of its own, may not have heard them yet.
        XCTAssertTrue(eventually { self.dropped(shop).count >= 3 })
        XCTAssertEqual(dropped(shop).count, 3)
        XCTAssertTrue(dropped(shop).allSatisfy { $0.context["reason"] == "overflow" })
        sdk.release()
    }

    // MARK: - A restart

    func test_the_queue_outlives_a_restart_and_goes_in_order_from_where_it_was() {
        let shop = newShop()
        let first = make(shop)
        network.isOnline = false
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        ["a", "b", "c"].forEach { first.tracking.productView(itemId: $0) }
        first.eventQueue?.settle()
        let released = expectation(description: "the callback of a released instance")
        first.tracking.productView(itemId: "d") { result in
            if case .failure(.initializationFailed) = result { released.fulfill() }
        }
        first.eventQueue?.settle()
        first.release()
        wait(for: [released], timeout: 5)
        XCTAssertEqual(files(first).count, 4, "release keeps the queue on disk")

        // The next launch: a new instance over the same folder.
        network.isOnline = true
        let second = make(shop, settled: false)
        // The first answer is a 503: "a" goes again — after its pause, or at once when the launch's
        // /init answers and kicks the queue — and the rest follow in order.
        XCTAssertTrue(eventually {
            if let pause = self.scheduler.pendingDelays.first {
                self.scheduler.advance(by: pause)
            }
            return self.requests("/push", shop).count == 5
        })
        XCTAssertEqual(itemIds(requests("/push", shop)), ["a", "a", "b", "c", "d"])
        XCTAssertTrue(eventually { self.files(second).isEmpty })
    }

    func test_the_attempts_and_the_check_of_an_event_outlive_a_restart() {
        let shop = newShop()
        let first = make(shop)
        answer("/push", StubReply(503))
        first.tracking.productView(itemId: "a")
        for attempt in 1...9 {
            XCTAssertTrue(eventually { self.requests("/push", shop).count == attempt && self.scheduler.pending == 1 }, "attempt \(attempt)")
            if attempt < 9 { scheduler.advance(by: scheduler.pendingDelays.first ?? 0) }
        }
        first.release()

        let second = make(shop)
        XCTAssertTrue(eventually { self.dropped(shop).count == 1 }, "the tenth 503 drops it: nine came before the restart")
        XCTAssertTrue(eventually { self.dropped(shop).first?.context["reason"] == "attempts" })
        XCTAssertTrue(eventually { self.files(second).isEmpty })
    }

    // MARK: - Triggers and flush()

    func test_events_made_before_ready_go_once_init_answers() {
        let shop = newShop()
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init", (request.query["shop_id"] ?? request.body["shop_id"] as? String) == shop { _ = held.wait(timeout: .now() + 10) }
            return handler(request)
        }
        let sdk = make(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertEqual(sdk.state, .initializing)
        expectNoRequest(to: "/push", shop: shop) {
            sdk.tracking.productView(itemId: "early")
        }
        held.signal()
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertEqual(requests("/push", shop).first?.body["did"] as? String, "d")
        XCTAssertEqual(requests("/push", shop).first?.body["sid"] as? String, "s-1")
    }

    func test_the_foreground_the_background_and_the_network_send_the_queue() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && self.scheduler.pending == 1 })
        // The foreground does not wait for the pause.
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 2 && self.files(sdk).isEmpty })

        // The background: under a background task, ended once the queue was tried.
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "b")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 3 && self.scheduler.pending == 1 })
        lifecycle.send(.didEnterBackground)
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 4 && self.files(sdk).isEmpty })
        XCTAssertTrue(eventually { self.lifecycle.backgroundTasks == (begun: 1, ended: 1) })

        // The network coming back.
        offline {
            sdk.tracking.productView(itemId: "c")
            sdk.eventQueue?.settle()
            XCTAssertEqual(files(sdk).count, 1)
        }
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)).last == "c" && self.files(sdk).isEmpty })
    }

    func test_flush_tries_every_event_now_and_completes_on_the_main_thread() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        sdk.tracking.productView(itemId: "b")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && self.scheduler.pending == 1 })

        let flushed = expectation(description: "flushed")
        sdk.flush { error in
            XCTAssertNil(error)
            XCTAssertTrue(Thread.isMainThread)
            flushed.fulfill()
        }
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(itemIds(requests("/push", shop)), ["a", "a", "b"], "both tried, without waiting for the pause")
        XCTAssertTrue(files(sdk).isEmpty)

        // Offline it completes at once, the events kept.
        network.isOnline = false
        sdk.tracking.productView(itemId: "c")
        let offlineFlush = expectation(description: "offline")
        sdk.flush { _ in offlineFlush.fulfill() }
        wait(for: [offlineFlush], timeout: 5)
        XCTAssertEqual(files(sdk).count, 1)
    }

    func test_flush_waits_for_the_instance_at_most_a_read_timeout() {
        let shop = newShop()
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init", (request.query["shop_id"] ?? request.body["shop_id"] as? String) == shop { _ = held.wait(timeout: .now() + 10) }
            return handler(request)
        }
        let sdk = make(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        sdk.tracking.productView(itemId: "a")
        let flushed = expectation(description: "flushed")
        let early = expectation(description: "flushed before ready")
        early.isInverted = true
        let isReady = Locked(false)
        sdk.flush { _ in
            if !isReady.current { early.fulfill() }
            flushed.fulfill()
        }
        wait(for: [early], timeout: 0.3)
        isReady.current = true
        held.signal()
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(requests("/push", shop).count, 1, "tried once the instance was ready")

        // An instance that does not get there: the flush ends after a read timeout, the event kept.
        let other = newShop()
        let never = DispatchSemaphore(value: 0)
        defer { never.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init", request.query["shop_id"] == other { _ = never.wait(timeout: .now() + 10) }
            return handler(request)
        }
        let waiting = make(other, identity: InMemoryUserIdentityRepository(), settled: false)
        waiting.tracking.productView(itemId: "b")
        let timedOut = expectation(description: "timed out")
        waiting.flush { _ in timedOut.fulfill() }
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(NetworkClient.defaultTimeout) })
        scheduler.advance(by: NetworkClient.defaultTimeout)
        wait(for: [timedOut], timeout: 5)
        XCTAssertTrue(requests("/push", other).isEmpty)
        XCTAssertEqual(files(waiting).count, 1)
    }

    func test_flush_does_not_cut_the_servers_retry_after_short() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push", StubReply(503, headers: ["Retry-After": "30"]), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && self.scheduler.pendingDelays == [30] })
        let flushed = expectation(description: "flushed")
        sdk.flush { _ in flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        lifecycle.send(.willEnterForeground)
        expectNoRequest(to: "/push", shop: shop, within: 0.3)
        XCTAssertEqual(scheduler.pendingDelays, [30], "the server's pause stands")
        scheduler.advance(by: 30)
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 2 && self.files(sdk).isEmpty })
    }

    func test_an_event_the_disk_refuses_is_sent_once_as_a_plain_request() throws {
        let shop = newShop()
        let sdk = make(shop)
        // A file where the queue's folder should be: the folder cannot be made.
        let folder = try XCTUnwrap(sdk.storage.queueDirectory)
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: folder)
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        let done = expectation(description: "done")
        let result = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.productView(itemId: "a") { result.current = $0; done.fulfill() }
        wait(for: [done], timeout: 5)

        guard case .failure? = result.current else { return XCTFail("the plain request's answer: \(String(describing: result.current))") }
        XCTAssertEqual(requests("/push", shop).count, 1)
        XCTAssertEqual(scheduler.pending, 0, "not repeated")
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 0, "not queued")
        XCTAssertTrue(eventually { self.heard.contains { $0.shopId == shop && $0.code == "storage_failed" } })
        XCTAssertEqual(requests("/push", shop).first?.body["sid"] as? String, sdk.sessionId)
        try? FileManager.default.removeItem(at: folder)
    }

    func test_flush_async_and_on_the_old_core_and_a_conformer_completes_at_once_and_after_release_is_not_initialized() async throws {
        let shop = newShop()
        let sdk = make(shop)
        sdk.tracking.productView(itemId: "a")
        try await sdk.flush()
        XCTAssertEqual(requests("/push", shop).count, 1)
        sdk.release()
        do {
            try await sdk.flush()
            XCTFail("flush after release")
        } catch let error as Rees46.SdkError {
            XCTAssertEqual(error, .notInitialized)
        }

        CoreFlag.reset(to: false)
        let legacy = StubSDK.make(shopId: newShop())
        XCTAssertNil(legacy.eventQueue)
        try await legacy.flush()
        legacy.release()
        do {
            try await legacy.flush()
            XCTFail("flush after release, old core")
        } catch let error as Rees46.SdkError {
            XCTAssertEqual(error, .notInitialized)
        }
        try await FakeSDK(shopId: "fake").flush()
    }

    // MARK: - Clearing and release()

    func test_delete_user_credentials_clears_the_queue_and_later_events_wait_for_the_new_did() {
        let shop = newShop()
        let sdk = make(shop)
        let results = Locked<[Result<Void, SdkError>]>([])
        network.isOnline = false
        sdk.tracking.productView(itemId: "deleted-1") { r in results.mutate { $0.append(r) } }
        sdk.tracking.productView(itemId: "deleted-2") { r in results.mutate { $0.append(r) } }
        sdk.eventQueue?.settle()

        sdk.deleteUserCredentials()

        // Gone when the call returns: a process that ends right after it leaves none of them behind.
        XCTAssertTrue(files(sdk).isEmpty, "gone with the customer")
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 0)
        XCTAssertTrue(eventually { self.dropped(shop).last?.context["reason"] == "delete_user_credentials" })
        XCTAssertTrue(eventually { self.dropped(shop).last?.context["count"] == "2" })
        XCTAssertTrue(eventually { results.current.count == 2 })
        sdk.tracking.productView(itemId: "new-customer")
        network.isOnline = true
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertEqual(itemIds(requests("/push", shop)), ["new-customer"])
        XCTAssertEqual(requests("/push", shop).first?.body["did"] as? String, "d")
        XCTAssertNil(requests("/init", shop).last?.query["did"], "the new did came first")
    }

    func test_release_stops_sending_keeps_the_queue_and_later_calls_are_not_initialized() {
        let shop = newShop()
        let sdk = make(shop)
        network.isOnline = false
        sdk.tracking.productView(itemId: "kept")
        sdk.eventQueue?.settle()
        sdk.release()
        expectNoRequest(to: "/push", shop: shop) {
            network.isOnline = true
            lifecycle.send(.willEnterForeground)
        }
        XCTAssertEqual(files(sdk).count, 1)
        let call = expectation(description: "after release")
        sdk.tracking.productView(itemId: "late") { result in
            if case .failure(.initializationFailed) = result { call.fulfill() }
        }
        wait(for: [call], timeout: 2)
        XCTAssertEqual(files(sdk).count, 1, "nothing is queued after release")
        let flushed = expectation(description: "flush")
        sdk.flush { error in
            XCTAssertEqual(error, .notInitialized)
            flushed.fulfill()
        }
        wait(for: [flushed], timeout: 2)
    }

    // MARK: - The customer an event goes as

    func test_an_event_on_its_way_when_the_customer_is_deleted_goes_as_that_customer_and_never_again() {
        let shop = newShop()
        let sdk = make(shop)
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/push", (request.body["items"] as? [[String: Any]])?.first?["id"] as? String == "old" {
                _ = held.wait(timeout: .now() + 10)
            }
            return handler(request)
        }
        answer("/init", StubReply(json: #"{"did":"next-did","seance":"next-sid"}"#))
        let old = expectation(description: "the deleted customer's event")
        let result = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.productView(itemId: "old") { result.current = $0; old.fulfill() }
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })

        sdk.deleteUserCredentials()
        held.signal()
        wait(for: [old], timeout: 5)

        guard case .failure? = result.current else { return XCTFail("cleared with its customer") }
        XCTAssertEqual(requests("/push", shop).first?.body["did"] as? String, "d", "taken when it was sent")
        sdk.tracking.productView(itemId: "new")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 2 })
        expectNoRequest(to: "/push", shop: shop, within: 0.3)
        XCTAssertEqual(itemIds(requests("/push", shop)), ["old", "new"], "the deleted customer's event is not sent again")
        XCTAssertEqual(requests("/push", shop).last?.body["did"] as? String, "next-did")
        XCTAssertEqual(requests("/push", shop).last?.body["sid"] as? String, "next-sid")
    }

    func test_a_disk_refused_event_waiting_for_the_instance_does_not_go_for_the_next_customer() throws {
        let shop = newShop()
        let first = DispatchSemaphore(value: 0)
        defer { first.signal() }
        let inits = Locked(0)
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init" {
                var call = 0
                inits.mutate { $0 += 1; call = $0 }
                if call == 1 { _ = first.wait(timeout: .now() + 10) }
            }
            return handler(request)
        }
        let sdk = make(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let folder = try XCTUnwrap(sdk.storage.queueDirectory)
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: folder)
        defer { try? FileManager.default.removeItem(at: folder) }
        let done = expectation(description: "done")
        let result = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.productView(itemId: "old") { result.current = $0; done.fulfill() }

        // It waits for the instance; meanwhile the customer is deleted and a new did comes.
        sdk.deleteUserCredentials()
        wait(for: [done], timeout: 5)
        guard case .failure? = result.current else { return XCTFail("\(String(describing: result.current))") }
        expectNoRequest(to: "/push", shop: shop, within: 0.3)
        XCTAssertTrue(requests("/push", shop).isEmpty)
    }

    // MARK: - Disk that fails

    func test_a_write_or_a_removal_that_fails_never_sends_an_event_again_at_once() throws {
        let shop = newShop()
        let sdk = make(shop)
        network.isOnline = false
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        sdk.eventQueue?.settle()
        let folder = try XCTUnwrap(sdk.storage.queueDirectory)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }

        // 402: the shop is checked; the event cannot be marked as checked on disk, so it is not resent
        // at once but after a pause.
        network.isOnline = true
        XCTAssertTrue(eventually { self.requests("/init", shop).count == 2 && self.scheduler.pending == 1 })
        expectNoRequest(to: "/push", shop: shop, within: 0.3)
        XCTAssertEqual(requests("/push", shop).count, 1)
        XCTAssertTrue(eventually { self.heard.contains { $0.shopId == shop && $0.code == "storage_failed" } })

        // Delivered, its file cannot be removed: it leaves the queue anyway.
        scheduler.advance(by: scheduler.pendingDelays.first ?? 0)
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 2 })
        expectNoRequest(to: "/push", shop: shop, within: 0.3)
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 0)
        XCTAssertEqual(files(sdk).count, 1, "the file stays where the disk refused")
    }

    func test_the_identity_source_and_time_go_on_a_copy_and_a_retry_takes_them_anew() throws {
        let shop = newShop()
        let sdk = make(shop)
        sdk.tracking.setSource(TrackingSource(type: .chain, code: "c-1"))
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && self.scheduler.pending == 1 })
        XCTAssertEqual(requests("/push", shop).first?.body["source"] as? [String: String], ["from": "chain", "code": "c-1"])

        // On disk: the event, not what it went with.
        let name = try XCTUnwrap(files(sdk).first)
        let folder = try XCTUnwrap(sdk.storage.queueDirectory)
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent(name))) as? [String: Any])
        let stored = try XCTUnwrap(record["body"] as? [String: Any])
        for key in ["did", "sid", "seance", "segment", "stream", "shop_id", "source", "time"] {
            XCTAssertNil(stored[key], key)
        }

        // The source expired before the retry: the retry goes without it.
        sdk.sourceStore.clear()
        scheduler.advance(by: scheduler.pendingDelays.first ?? 0)
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 2 })
        XCTAssertNil(requests("/push", shop).last?.body["source"])
    }

    func test_a_file_that_does_not_parse_is_dropped_and_one_that_cannot_be_read_now_waits() throws {
        let shop = newShop()
        let first = make(shop)
        network.isOnline = false
        first.tracking.productView(itemId: "ok")
        first.tracking.productView(itemId: "locked")
        first.eventQueue?.settle()
        first.release()
        let folder = try XCTUnwrap(first.storage.queueDirectory)
        let names = files(first)
        XCTAssertEqual(names.count, 2)
        let locked = folder.appendingPathComponent(names[1])
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
        let broken = folder.appendingPathComponent(String(format: "%020llu.json", UInt64(99)))
        try Data("{not json".utf8).write(to: broken)

        network.isOnline = true
        let second = make(shop, settled: false)
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["ok"] })
        XCTAssertTrue(eventually { self.dropped(shop).contains { $0.context["reason"] == "unreadable" } })
        XCTAssertFalse(FileManager.default.fileExists(atPath: broken.path), "dropped")
        XCTAssertTrue(FileManager.default.fileExists(atPath: locked.path), "kept to be read later")

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path)
        let flushed = expectation(description: "flushed")
        second.flush { _ in flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(itemIds(requests("/push", shop)), ["ok", "locked"])
    }

    // MARK: - Popups, callbacks, arguments

    func test_a_popup_in_a_push_answer_shows_only_when_the_event_went_within_ten_seconds_in_the_foreground() {
        final class Delegate: PopupPresentationDelegate {
            let asked = Locked<[Int]>([])
            func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? {
                asked.mutate { $0.append(popup.id) }
                return nil
            }
        }
        func withPopup(_ id: Int) -> StubReply {
            StubReply(json: #"{"status":"success","popup":{"id":\#(id),"html":"<p>x</p>"}}"#)
        }
        let shop = newShop()
        let sdk = make(shop)
        let delegate = Delegate()
        sdk.popupPresentationDelegate = delegate

        answer("/push", withPopup(1))
        // A test before may leave the modal slot held by a popup of popups v3: a legacy popup would
        // wait for it to close.
        PopupV3Slots.shared.reset()
        sdk.tracking.productView(itemId: "fresh")
        XCTAssertTrue(eventually { delegate.asked.current == [1] }, "fresh, in the foreground")

        answer("/push", withPopup(2))
        offline {
            sdk.tracking.productView(itemId: "late")
            sdk.eventQueue?.settle()
            clock.advance(by: 11)
        }
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)).last == "late" })
        answer("/push/custom", withPopup(3))
        lifecycle.isInForeground = false
        sdk.tracking.custom(event: "in-background")
        XCTAssertTrue(eventually { self.requests("/push/custom", shop).count == 1 })
        let shown = expectation(description: "another popup")
        shown.isInverted = true
        wait(for: [shown], timeout: 0.5)
        XCTAssertEqual(delegate.asked.current, [1])
        XCTAssertTrue(eventually { self.heard.filter { $0.shopId == shop && $0.code == "popup_not_shown" }.count == 3 })
        // The app's delegate declined the fresh one; the late and the background ones were not offered.
        XCTAssertEqual(heard.filter { $0.shopId == shop && $0.code == "popup_not_shown" }.map { $0.context["reason"] },
                       ["app_declined", "late_event", "app_in_background"])
        XCTAssertTrue(heard.filter { $0.shopId == shop && $0.code == "popup_not_shown" }.allSatisfy { $0.level == .debug })
    }

    func test_the_old_callbacks_hear_what_they_always_heard_once_the_event_went() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push", StubReply(json: "{}"))
        let notSuccess = expectation(description: "{}")
        sdk.track(event: .productView(id: "1"), recommendedBy: nil) { result in
            if case .failure(.responseError) = result { notSuccess.fulfill() }
        }
        wait(for: [notSuccess], timeout: 5)

        answer("/popup/showed", StubReply(204, json: ""))
        let shown = expectation(description: "popup/showed")
        sdk.trackPopupShown(popupId: 7) { result in
            if case .success = result { shown.fulfill() }
        }
        wait(for: [shown], timeout: 5)
        XCTAssertEqual(requests("/popup/showed", shop).first?.body["popup"] as? Int, 7)
        XCTAssertEqual(requests("/popup/showed", shop).first?.body["sid"] as? String, sdk.sessionId)
        XCTAssertNotNil(sdk.sessionId)

        answer("/push", StubReply(json: #"{"status":"success"}"#))
        let purchase = expectation(description: "purchase")
        sdk.trackPurchase(PurchaseTrackingRequest(orderId: "A-1", orderPrice: 10, items: [PurchaseItemRequest(id: "1", amount: 1, price: 10)]), recommendedBy: nil) { result in
            if case .success = result { purchase.fulfill() }
        }
        wait(for: [purchase], timeout: 5)
    }

    func test_argument_errors_come_back_at_once_and_nothing_is_queued() {
        let shop = newShop()
        let sdk = make(shop)
        let calls: [(String, (@escaping (Result<Void, SdkError>) -> Void) -> Void)] = [
            ("empty item", { sdk.tracking.productView(itemId: " ", completion: $0) }),
            ("empty cart item", { sdk.tracking.addToCart(item: TrackingItem(id: ""), completion: $0) }),
            ("empty query", { sdk.tracking.search(query: "", completion: $0) }),
            ("empty event", { sdk.tracking.custom(event: " ", completion: $0) }),
            ("empty story", { sdk.tracking.storyView(storyId: "", slideId: "1", completion: $0) }),
            ("empty slide", { sdk.tracking.storyClick(storyId: "1", slideId: "", completion: $0) }),
            ("reserved key", { sdk.tracking.custom(event: "e", customFields: ["sid": "x"], completion: $0) }),
            ("not JSON", { sdk.tracking.custom(event: "e", customFields: ["when": Date()], completion: $0) }),
            ("NaN", { sdk.tracking.custom(event: "e", customFields: ["value": Double.nan], completion: $0) }),
            ("infinity", { sdk.tracking.custom(event: "e", customFields: ["value": Double.infinity], completion: $0) }),
            ("NaN in a purchase", { sdk.tracking.purchase(PurchaseTrackingRequest(orderId: "A", orderPrice: 1, items: [PurchaseItemRequest(id: "1", amount: 1, price: 1)], custom: ["x": Double.nan]), completion: $0) }),
            ("no items", { sdk.tracking.purchase(PurchaseTrackingRequest(orderId: "A", orderPrice: 0, items: []), completion: $0) }),
        ]
        for (name, call) in calls {
            let failed = expectation(description: name)
            call { result in
                // Told later, on another queue: never inside the call, which the test makes on main.
                XCTAssertFalse(Thread.isMainThread, name)
                if case .failure(.custom) = result { failed.fulfill() }
            }
            wait(for: [failed], timeout: 1)
        }
        sdk.eventQueue?.settle()
        XCTAssertTrue(files(sdk).isEmpty)
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 0)
    }

    // MARK: - One owner per shop, the session

    func test_two_instances_of_one_shop_share_one_queue_and_send_each_event_once() {
        let shop = newShop()
        let first = make(shop)
        let second = make(shop)
        XCTAssertTrue(first.eventQueue === second.eventQueue)
        network.isOnline = false
        first.tracking.productView(itemId: "from-first")
        second.tracking.productView(itemId: "from-second")
        first.tracking.productView(itemId: "first-again")
        second.eventQueue?.settle()
        network.isOnline = true
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 3 })
        expectNoRequest(to: "/push", shop: shop, within: 0.3)
        XCTAssertEqual(itemIds(requests("/push", shop)), ["from-first", "from-second", "first-again"])
        XCTAssertTrue(files(first).isEmpty)

        // The one that sends goes: the other goes on sending.
        second.release()
        first.tracking.productView(itemId: "after")
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)).last == "after" })
    }

    func test_events_extend_the_session_and_requests_with_a_result_do_not() {
        let shop = newShop()
        let sdk = make(shop)
        clock.advance(by: 100 * 60)
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && self.files(sdk).isEmpty })
        // Two hours after the identity's last activity, but under two after the event: no /init.
        clock.advance(by: 100 * 60)
        sdk.tracking.productView(itemId: "b")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 2 })
        XCTAssertEqual(requests("/init", shop).count, 1, "only the launch's")
        XCTAssertEqual(requests("/push", shop).last?.body["sid"] as? String, sdk.sessionId)
    }

    // MARK: - Contract fixtures

    func test_the_shared_tracking_fixtures_pass_on_the_new_core() throws {
        for item in try ContractFixtures.cases("tracking") {
            let name = item["name"] as? String ?? "?"
            let call = item["call"] as? [String: Any] ?? [:]
            let args = call["args"] as? [String: Any] ?? [:]
            let shop = newShop()
            let sdk = make(shop)
            let done = expectation(description: name)
            let result = Locked<Result<Void, SdkError>?>(nil)
            let completion: (Result<Void, SdkError>) -> Void = { result.current = $0; done.fulfill() }
            switch call["method"] as? String {
            case "productView":
                let source = (args["source"] as? [String: String]).flatMap { raw in
                    Self.sourceType(raw["type"]).map { TrackingSource(type: $0, code: raw["code"] ?? "") }
                }
                sdk.tracking.productView(itemId: args["itemId"] as? String ?? "", source: source, completion: completion)
            case "categoryView":
                sdk.tracking.categoryView(categoryId: args["categoryId"] as? String ?? "", completion: completion)
            case "addToCart":
                let raw = args["item"] as? [String: Any] ?? [:]
                let trackingItem = TrackingItem(id: raw["id"] as? String ?? "", quantity: raw["quantity"] as? Int ?? 1,
                                                price: raw["price"] as? Double, fashionSize: raw["fashionSize"] as? String)
                sdk.tracking.addToCart(item: trackingItem, completion: completion)
            case "syncCart":
                let items = (args["items"] as? [[String: Any]] ?? []).map {
                    TrackingItem(id: $0["id"] as? String ?? "", quantity: $0["quantity"] as? Int ?? 1, price: $0["price"] as? Double)
                }
                sdk.tracking.syncCart(items: items, completion: completion)
            case "syncFavorites":
                sdk.tracking.syncFavorites(itemIds: args["itemIds"] as? [String] ?? [], completion: completion)
            case "purchase":
                let raw = args["request"] as? [String: Any] ?? [:]
                let items = (raw["items"] as? [[String: Any]] ?? []).map {
                    PurchaseItemRequest(id: $0["id"] as? String ?? "", amount: $0["amount"] as? Int ?? 0, price: $0["price"] as? Double ?? 0)
                }
                let request = PurchaseTrackingRequest(orderId: raw["orderId"] as? String ?? "", orderPrice: raw["orderPrice"] as? Double ?? 0,
                                                      items: items, isTaxFree: raw["isTaxFree"] as? Bool ?? false)
                sdk.tracking.purchase(request, completion: completion)
            case "storyView":
                sdk.tracking.storyView(storyId: args["storyId"] as? String ?? "", slideId: args["slideId"] as? String ?? "",
                                       code: args["code"] as? String, completion: completion)
            case "custom":
                sdk.tracking.custom(event: args["event"] as? String ?? "", category: args["category"] as? String,
                                    customFields: args["customFields"] as? [String: Any], completion: completion)
            default:
                XCTFail("\(name): a method the test does not know")
                continue
            }
            wait(for: [done], timeout: 5)

            if item["error"] != nil {
                guard case .failure(.custom)? = result.current else { XCTFail("\(name): \(String(describing: result.current))"); continue }
                XCTAssertTrue(StubURLProtocol.requests.filter { ($0.body["shop_id"] as? String) == shop && $0.path != "/init" }.isEmpty, name)
                continue
            }
            let expected = item["request"] as? [String: Any] ?? [:]
            let path = "/" + (expected["path"] as? String ?? "")
            guard let sent = requests(path, shop).first else { XCTFail("\(name): nothing sent to \(path)"); continue }
            XCTAssertEqual(sent.method, expected["method"] as? String, name)
            for (key, value) in expected["body"] as? [String: Any] ?? [:] {
                XCTAssertTrue((sent.body[key] as AnyObject?)?.isEqual(value) ?? false, "\(name): \(key) = \(String(describing: sent.body[key])), expected \(value)")
            }
            sdk.release()
        }
    }

    private static func sourceType(_ raw: String?) -> TrackingSourceType? {
        switch raw {
        case "instantSearch": return .instantSearch
        case "fullSearch": return .fullSearch
        case "webPushDigest": return .webPushDigest
        default: return raw.flatMap(TrackingSourceType.init(rawValue:))
        }
    }

    // MARK: - After the review of stages 4–5

    func test_the_queue_wakes_itself_every_60_seconds_while_events_wait_and_not_when_empty() {
        let shop = newShop()
        let sdk = make(shop)
        network.isOnline = false
        sdk.tracking.productView(itemId: "a")
        sdk.eventQueue?.settle()
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(EventQueue.timerInterval) })
        // The network came back and nobody said so: the timer finds out.
        network.setOnlineSilently(true)
        scheduler.advance(by: EventQueue.timerInterval)
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        sdk.eventQueue?.settle()
        XCTAssertTrue(eventually { !self.scheduler.pendingDelays.contains(EventQueue.timerInterval) }, "an empty queue does not wake")
    }

    func test_no_timer_while_a_pause_or_an_event_on_its_way_wakes_the_queue() {
        let shop = newShop()
        let sdk = make(shop)
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && self.scheduler.pending == 1 })
        XCTAssertFalse(scheduler.pendingDelays.contains(EventQueue.timerInterval), "the pause wakes it")
    }

    func test_an_event_extends_a_live_session_when_it_is_accepted_and_not_an_ended_one() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "d"
        identity.seance = "s-0"
        identity.seanceLastActTime = clock.now()
        let sdk = make(shop, identity: identity)
        let opened = identity.seanceLastActTime
        offline {
            clock.advance(by: 30 * 60)
            sdk.tracking.productView(itemId: "a")
            XCTAssertEqual(identity.seanceLastActTime, clock.now(), "accepted, not sent: the window moved")
            XCTAssertNotEqual(identity.seanceLastActTime, opened)

            clock.advance(by: 2 * 60 * 60 + 1)
            let ended = identity.seanceLastActTime
            sdk.tracking.productView(itemId: "b")
            XCTAssertEqual(identity.seanceLastActTime, ended, "an ended window is not opened by an event")
            XCTAssertNil(sdk.sessionId)
        }
    }

    func test_a_virtual_story_slide_is_not_sent_and_is_no_error_on_any_path() {
        let shop = newShop()
        let sdk = make(shop)
        let done = expectation(description: "done")
        done.expectedFulfillmentCount = 4
        let results = Locked<[Result<Void, SdkError>]>([])
        let record: (Result<Void, SdkError>) -> Void = { result in results.mutate { $0.append(result) }; done.fulfill() }
        expectNoRequest(to: "/track/stories", shop: shop, within: 0.5) {
            sdk.tracking.storyView(storyId: "12_3", slideId: "5", code: "main", completion: record)
            sdk.tracking.storyClick(storyId: "12", slideId: "12_0", code: "main", completion: record)
            sdk.tracking.storyView(storyId: "0", slideId: "5", code: "main", completion: record)
            sdk.track(event: .slideView(storyId: "7_1", slideId: "2"), recommendedBy: nil, completion: record)
        }
        wait(for: [done], timeout: 5)
        for result in results.current {
            guard case .success = result else { return XCTFail("\(result)") }
        }
        sdk.eventQueue?.settle()
        XCTAssertTrue(files(sdk).isEmpty, "nothing queued")
        XCTAssertEqual(sdk.trackingSourceStore.currentSource()?.type, "stories", "the slide still makes its block the source")
    }

    func test_an_empty_category_id_is_an_invalid_argument_at_once_on_any_path() {
        let shop = newShop()
        let sdk = make(shop)
        let done = expectation(description: "done")
        done.expectedFulfillmentCount = 2
        let results = Locked<[Result<Void, SdkError>]>([])
        let record: (Result<Void, SdkError>) -> Void = { result in results.mutate { $0.append(result) }; done.fulfill() }
        expectNoRequest(to: "/push", shop: shop) {
            sdk.tracking.categoryView(categoryId: "", completion: record)
            sdk.track(event: .categoryView(id: "  "), recommendedBy: nil, completion: record)
        }
        wait(for: [done], timeout: 5)
        for result in results.current {
            guard case .failure(.custom) = result else { return XCTFail("\(result)") }
        }
        XCTAssertTrue(eventually { self.heard.contains { $0.shopId == shop && $0.code == "invalid_argument" } })
        sdk.eventQueue?.settle()
        XCTAssertTrue(files(sdk).isEmpty)
    }

    func test_the_files_of_the_queue_have_unique_names_of_time_process_and_a_random_part() throws {
        let shop = newShop()
        let sdk = make(shop)
        offline {
            (1...5).forEach { sdk.tracking.productView(itemId: "item-\($0)") }
            sdk.eventQueue?.settle()
        }
        let names = files(sdk)
        XCTAssertEqual(names.count, 5)
        XCTAssertEqual(Set(names).count, 5)
        let pattern = try NSRegularExpression(pattern: #"^\d{20}-\d+-[0-9a-f]{8}\.json$"#)
        for name in names {
            XCTAssertNotNil(pattern.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)), name)
            XCTAssertTrue(name.contains("-\(ProcessInfo.processInfo.processIdentifier)-"), name)
        }
        XCTAssertEqual(names, names.sorted(), "in the order of the calls")
    }

    func test_release_then_initialize_sends_each_event_once_with_new_names() {
        let shop = newShop()
        let first = make(shop)
        network.isOnline = false
        first.tracking.productView(itemId: "a")
        first.eventQueue?.settle()
        let before = files(first)
        first.release()
        let second = make(shop, settled: false)
        second.tracking.productView(itemId: "b")
        second.eventQueue?.settle()
        XCTAssertEqual(files(second).count, 2)
        XCTAssertTrue(Set(files(second)).isSuperset(of: before), "the first file is kept, the new one has its own name")

        network.isOnline = true
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["a", "b"] })
        expectNoRequest(to: "/push", shop: shop, within: 0.3)
        XCTAssertEqual(itemIds(requests("/push", shop)), ["a", "b"], "each once")
        XCTAssertTrue(eventually { self.files(second).isEmpty })
    }

    func test_the_remaining_instance_takes_over_the_check_of_a_released_owner() {
        let shop = newShop()
        let older = InMemoryUserIdentityRepository()
        older.deviceId = "older-did"
        older.seance = "s-0"
        older.seanceLastActTime = clock.now()
        let first = make(shop, identity: older)
        let newer = InMemoryUserIdentityRepository()
        newer.deviceId = "newer-did"
        newer.seance = "s-0"
        newer.seanceLastActTime = clock.now()
        let owner = make(shop, identity: newer)
        // The owner's check is held, and its instance goes while it is on its way.
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/init", request.query["did"] == "newer-did" { _ = held.wait(timeout: .now() + 10) }
            return handler(request)
        }
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        owner.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.requests("/init", shop).filter { $0.query["did"] == "newer-did" }.count == 2 }, "the owner's check")
        owner.release()

        XCTAssertTrue(eventually { self.requests("/push", shop).count == 2 }, "sent again through the remaining instance")
        XCTAssertEqual(requests("/push", shop).last?.body["did"] as? String, "older-did")
        XCTAssertTrue(eventually { self.files(first).isEmpty })
        XCTAssertTrue(dropped(shop).isEmpty)
    }

    func test_delete_user_credentials_on_any_instance_resets_the_other_ones_of_the_shop() {
        let shop = newShop()
        let shared = InMemoryUserIdentityRepository()
        shared.deviceId = "d"
        shared.seance = "s-0"
        shared.seanceLastActTime = clock.now()
        let first = make(shop, identity: shared)
        let owner = make(shop, identity: shared)
        XCTAssertEqual(owner.deviceId, "d")
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply(json: #"{"status":"success"}"#) }
            // Only this shop's: an SDK an earlier test left must not take a signal meant for it.
            if request.query["did"] == nil, request.query["shop_id"] == shop { _ = held.wait(timeout: .now() + 10) }
            return StubReply(json: #"{"did":"\#(request.query["did"] ?? "next-did")","seance":"s-9"}"#)
        }

        first.deleteUserCredentials()
        XCTAssertEqual(owner.deviceId, "", "the owner forgot the deleted did")
        XCTAssertEqual(owner.state, .initializing)
        let done = expectation(description: "products/get")
        owner.getProductInfo(id: "37") { _ in done.fulfill() }
        owner.tracking.productView(itemId: "after")
        expectNoRequest(to: "/products/get", shop: shop, within: 0.3)
        XCTAssertTrue(requests("/push", shop).isEmpty)

        // Both instances asked for the next did; the first answer stored is the one both take.
        held.signal()
        held.signal()
        wait(for: [done], timeout: 5)
        XCTAssertEqual(requests("/products/get", shop).first?.query["did"], "next-did")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertEqual(requests("/push", shop).first?.body["did"] as? String, "next-did")
        XCTAssertTrue(eventually { owner.deviceId == "next-did" && first.deviceId == "next-did" })
        let all = requests("/products/get", shop) + requests("/push", shop)
        XCTAssertFalse(all.contains { (($0.query["did"] ?? $0.body["did"] as? String) ?? "").isEmpty }, "never without a did")
    }

    func test_two_instances_answered_after_delete_user_credentials_never_pair_the_did_of_one_answer_with_the_sid_of_the_other() {
        let shop = newShop()
        let shared = InMemoryUserIdentityRepository()
        shared.deviceId = "d"
        shared.seance = "s-0"
        shared.seanceLastActTime = clock.now()
        let first = make(shop, identity: shared)
        let owner = make(shop, identity: shared)
        let held = DispatchSemaphore(value: 0)
        defer { held.signal(); held.signal() }
        let answers = Locked(0)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply(json: #"{"status":"success"}"#) }
            guard request.query["shop_id"] == shop else { return StubReply(json: #"{"did":"other-did","seance":"other"}"#) }
            guard request.query["did"] == nil else { return StubReply(json: #"{"did":"\#(request.query["did"] ?? "")","seance":"s-x"}"#) }
            _ = held.wait(timeout: .now() + 10)
            var call = 0
            answers.mutate { $0 += 1; call = $0 }
            return call == 1 ? StubReply(json: #"{"did":"one","seance":"s-one"}"#) : StubReply(json: #"{"did":"two","seance":"s-two"}"#)
        }
        let settled = (first.settledInitCount, owner.settledInitCount)

        first.deleteUserCredentials()
        XCTAssertTrue(eventually { self.requests("/init", shop).filter { $0.query["did"] == nil }.count == 2 }, "both ask for the next did")
        held.signal()
        XCTAssertTrue(eventually { shared.deviceId == "one" && shared.seance == "s-one" }, "the first answer: its did and its sid")
        held.signal()
        XCTAssertTrue(eventually { first.settledInitCount > settled.0 && owner.settledInitCount > settled.1 }, "both answers taken")
        XCTAssertEqual(shared.deviceId, "one", "the first did stored stays")
        XCTAssertEqual(shared.seance, "s-one", "the sid of the other answer does not go with it")
        XCTAssertEqual(first.sessionId, "s-one")
        XCTAssertEqual(owner.sessionId, "s-one")
        XCTAssertEqual(first.deviceId, "one")
        XCTAssertEqual(owner.deviceId, "one")
    }

    func test_delete_user_credentials_from_the_main_thread_does_not_wait_for_the_queue_and_nothing_old_goes_after_it() {
        let shop = newShop()
        let sdk = make(shop)
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        let holds = Locked(true)
        let letGo = Locked(false)
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/push", request.body["shop_id"] as? String == shop {
                var first = false
                holds.mutate { first = $0; $0 = false }
                if first {
                    _ = held.wait(timeout: .now() + 10)
                    letGo.current = true
                }
            }
            return handler(request)
        }
        sdk.tracking.productView(itemId: "old-1")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        network.isOnline = false
        sdk.tracking.productView(itemId: "old-2")
        sdk.eventQueue?.settle()
        network.isOnline = true

        XCTAssertTrue(Thread.isMainThread)
        sdk.deleteUserCredentials()
        // It returned while the event on its way was still held at the server: it did not wait for it.
        XCTAssertFalse(letGo.current, "not held by the queue")
        sdk.tracking.productView(itemId: "new")
        held.signal()
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)).contains("new") })
        XCTAssertEqual(itemIds(requests("/push", shop)).filter { $0.hasPrefix("old") }, ["old-1"], "only the one on its way at the call")
        XCTAssertTrue(eventually { self.dropped(shop).contains { $0.context["reason"] == "delete_user_credentials" } })
    }
}
