//
//  CoreSessionTests.swift
//  REES46Tests
//
//  The session of the new core (`sdk/core/session.md`, decision 0001) over the stub server, with the
//  clock, the scheduler and the app's lifecycle in the test's hands: the server's `sid` and no client
//  one, the stored client `sid` sent once, `/init` with a `sid` only inside the window, every request
//  checking the window, what extends it and what does not, the foreground after two hours since the last
//  event, `sessionId`, the "session changed" listener, and the old core left as it was.
//

import XCTest
@testable import REES46

final class CoreSessionTests: XCTestCase {

    private var shops: [String] = []
    private var clock = FakeClock()
    private var scheduler: ManualScheduler!
    private var lifecycle = ManualAppLifecycle()

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        clock = FakeClock()
        scheduler = ManualScheduler(clock: clock)
        lifecycle = ManualAppLifecycle()
    }

    override func tearDown() {
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
        return shop
    }

    /// Every `/init` gets the did it sent, as the server answers, or `did` without one, and a new
    /// `seance`: `s-1`, `s-2`… — or the one `seance` says; the n-th waits for `gates[n]` when there is
    /// one.
    @discardableResult
    private func answerInit(did: String = "d", seance: ((Int) -> String)? = nil, gates: [Int: DispatchSemaphore] = [:]) -> Locked<Int> {
        let count = Locked(0)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            var call = 0
            count.mutate { $0 += 1; call = $0 }
            if let gate = gates[call] {
                _ = gate.wait(timeout: .now() + 10)
            }
            let sid = seance?(call) ?? "s-\(call)"
            return StubReply(json: #"{"did":"\#(request.query["did"] ?? did)","seance":"\#(sid)"}"#)
        }
        return count
    }

    private func make(
        _ shop: String,
        identity: UserIdentityRepository = InMemoryUserIdentityRepository(),
        connectivity: ConnectivityMonitor? = nil,
        needReInitialization: Bool = false
    ) -> SimplePersonalizationSDK {
        // Online unless the test says otherwise: the system's monitor is not the test's to rely on.
        StubSDK.make(
            shopId: shop, identity: identity, needReInitialization: needReInitialization, logLevel: .debug,
            connectivity: connectivity ?? FakeConnectivity(online: true), coreV2: true, environment: environment
        )
    }

    private func inits(_ shop: String) -> [StubRequest] {
        StubURLProtocol.requests(to: "/init", shop: shop)
    }

    private func products(_ shop: String) -> [StubRequest] {
        StubURLProtocol.requests(to: "/products/get", shop: shop)
    }

    private func getProduct(_ sdk: SimplePersonalizationSDK) -> Result<ProductInfo, SdkError>? {
        let done = expectation(description: "products/get")
        let outcome = Locked<Result<ProductInfo, SdkError>?>(nil)
        sdk.getProductInfo(id: "item-1") { outcome.current = $0; done.fulfill() }
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    /// An identity with a client session from an older SDK, last active `ago` seconds before now.
    private func identity(did: String? = "kept-did", sid: String?, ago: TimeInterval) -> InMemoryUserIdentityRepository {
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = did
        identity.seance = sid
        identity.seanceLastActTime = sid == nil ? nil : clock.now().addingTimeInterval(-ago)
        return identity
    }

    // MARK: - The server's sid

    func test_the_sid_is_the_seance_of_init_and_the_new_core_never_makes_one() {
        let shop = newShop()
        let answer = DispatchSemaphore(value: 0)
        defer { answer.signal() }
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            _ = answer.wait(timeout: .now() + 10)
            return StubReply(json: #"{"did":"AbCdEf1234","seance":"XyZ0987654"}"#)
        }
        let identity = InMemoryUserIdentityRepository()
        let sdk = make(shop, identity: identity)

        XCTAssertEqual(sdk.userSeance, "", "no sid before /init answers")
        XCTAssertNil(sdk.sessionId)
        XCTAssertNil(identity.seance, "none made and stored")
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        XCTAssertNil(inits(shop).first?.query["sid"])
        XCTAssertNil(inits(shop).first?.query["seance"])

        answer.signal()
        XCTAssertTrue(eventually { sdk.state == .ready })
        XCTAssertEqual(sdk.sessionId, "XyZ0987654")
        XCTAssertEqual(sdk.userSeance, "XyZ0987654")
        XCTAssertEqual(identity.seance, "XyZ0987654", "kept for the next launch")
        XCTAssertEqual(identity.seanceLastActTime, clock.now(), "/init opens the window")
    }

    func test_the_client_sid_of_an_older_sdk_goes_once_on_init_inside_its_window_then_the_servers() {
        let shop = newShop()
        answerInit()
        let stored = identity(sid: "ClientSid1", ago: 60 * 60)
        let sdk = make(shop, identity: stored)

        XCTAssertEqual(sdk.sessionId, "ClientSid1", "the live window goes on")
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" }, "the server's replaces it")
        XCTAssertEqual(inits(shop).first?.query["sid"], "ClientSid1")
        XCTAssertEqual(inits(shop).first?.query["seance"], "ClientSid1")

        // The next /init — a check of the shop — carries the server's.
        clock.advance(by: 10 * 60)
        XCTAssertEqual(sdk.initMachine?.askShop(), .asked)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 })
        XCTAssertEqual(inits(shop).last?.query["sid"], "s-1")
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }
        XCTAssertEqual(products(shop).last?.query["sid"], "s-2")
    }

    func test_init_carries_no_sid_once_the_window_ran_out() {
        let shop = newShop()
        answerInit()
        let sdk = make(shop, identity: identity(sid: "OldSid0001", ago: 2 * 60 * 60 + 1))

        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        XCTAssertNil(inits(shop).first?.query["sid"])
        XCTAssertNil(inits(shop).first?.query["seance"])
        XCTAssertEqual(inits(shop).first?.query["did"], "kept-did")
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
    }

    // MARK: - The window

    func test_a_request_after_the_window_ran_out_waits_for_init_and_goes_with_the_new_sid() {
        let shop = newShop()
        answerInit()
        let sdk = make(shop)
        XCTAssertTrue(eventually { sdk.state == .ready && sdk.sessionId == "s-1" })
        var heard: [Rees46.SdkState] = []
        sdk.onStateChange { heard.append($0) }
        XCTAssertTrue(eventually { heard == [.ready] })

        clock.advance(by: 2 * 60 * 60 + 1)
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }

        XCTAssertEqual(inits(shop).count, 2, "/init first")
        XCTAssertNil(inits(shop).last?.query["sid"], "the window ran out: no sid on it")
        XCTAssertEqual(products(shop).last?.query["sid"], "s-2", "the caller put s-1 in: the new one goes")
        XCTAssertEqual(products(shop).last?.query["seance"], "s-2")
        // The state does not flap on a renewal: the request waited inside the SDK.
        let changed = expectation(description: "a state change")
        changed.isInverted = true
        if heard != [.ready] { changed.fulfill() }
        wait(for: [changed], timeout: 0.3)
        XCTAssertEqual(heard, [.ready], "\(heard)")
        XCTAssertEqual(sdk.state, .ready)
    }

    func test_requests_with_a_result_do_not_extend_the_window_and_init_does() {
        let shop = newShop()
        answerInit()
        let sdk = make(shop)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })

        clock.advance(by: 2 * 60 * 60 - 60)
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }
        XCTAssertEqual(inits(shop).count, 1, "inside the window")
        XCTAssertEqual(products(shop).last?.query["sid"], "s-1")

        clock.advance(by: 120)
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }
        XCTAssertEqual(inits(shop).count, 2, "the earlier request did not extend it")
        XCTAssertEqual(products(shop).last?.query["sid"], "s-2")

        // An /init opens it again: a check of the shop an hour on keeps it open two hours from there.
        clock.advance(by: 60 * 60)
        XCTAssertEqual(sdk.initMachine?.askShop(), .asked)
        XCTAssertTrue(eventually { self.inits(shop).count == 3 && sdk.sessionId == "s-3" })
        clock.advance(by: 90 * 60)
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }
        XCTAssertEqual(inits(shop).count, 3)
    }

    func test_a_stored_did_is_ready_at_once_and_a_call_after_the_window_ran_out_waits_for_the_launchs_init() {
        let shop = newShop()
        let answer = DispatchSemaphore(value: 0)
        defer { answer.signal() }
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            _ = answer.wait(timeout: .now() + 10)
            return StubReply(json: #"{"did":"kept-did","seance":"NewSid0001"}"#)
        }
        let sdk = make(shop, identity: identity(sid: "OldSid0001", ago: 3 * 60 * 60))
        XCTAssertEqual(sdk.state, .ready)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })

        let done = expectation(description: "call")
        let outcome = Locked<Result<ProductInfo, SdkError>?>(nil)
        expectNoRequest(to: "/products/get", shop: shop) {
            sdk.getProductInfo(id: "item-1") { outcome.current = $0; done.fulfill() }
        }
        XCTAssertEqual(sdk.state, .ready, "the launch's /init renews it: no other one, no other state")
        answer.signal()
        wait(for: [done], timeout: 5)
        guard case .success? = outcome.current else { return XCTFail("the call went out") }
        XCTAssertEqual(products(shop).first?.query["sid"], "NewSid0001")
        XCTAssertEqual(inits(shop).count, 1)
    }

    func test_offline_a_request_does_not_wait_for_the_session_and_fails_at_once() {
        let shop = newShop()
        answerInit()
        let offline = FakeConnectivity(online: false)
        let sdk = make(shop, identity: identity(sid: "OldSid0001", ago: 3 * 60 * 60), connectivity: offline)
        XCTAssertEqual(sdk.state, .ready)
        guard case .failure(.networkOfflineError)? = getProduct(sdk) else { return XCTFail("offline: networkOfflineError") }
    }

    func test_an_init_answer_without_a_seance_keeps_the_live_sid_and_brings_no_init_storm() {
        let shop = newShop()
        StubURLProtocol.handler = { request in
            request.path == "/init" ? StubReply(json: #"{"did":"\#(request.query["did"] ?? "d")"}"#) : StubReply()
        }
        let sdk = make(shop, identity: identity(sid: "OldSid0001", ago: 60))
        XCTAssertTrue(eventually { self.inits(shop).count == 1 && sdk.settledInitCount >= 2 })
        XCTAssertEqual(sdk.sessionId, "OldSid0001", "a live sid is not erased")
        for _ in 0..<3 {
            guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }
        }
        clock.advance(by: 2 * 60 * 60 - 60)
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }
        XCTAssertEqual(inits(shop).count, 1, "the window /init opened lives: no /init again")
        XCTAssertEqual(products(shop).last?.query["sid"], "OldSid0001")

        clock.advance(by: 120)
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out") }
        XCTAssertEqual(inits(shop).count, 2, "once it ended, one /init")
    }

    func test_session_id_is_nil_once_the_window_ended() {
        let shop = newShop()
        answerInit()
        let sdk = make(shop)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
        clock.advance(by: 2 * 60 * 60 + 1)
        XCTAssertNil(sdk.sessionId)
        XCTAssertEqual(sdk.userSeance, "s-1", "the last sid, for whatever still reads it")
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { sdk.sessionId == "s-2" })
    }

    func test_a_failed_renewal_or_check_keeps_ready_replays_no_saved_answer_and_does_not_storm() {
        let shop = newShop()
        let replies = Locked<[StubReply]>([StubReply(json: #"{"did":"d","seance":"s-1","popups_v3":true}"#), StubReply(503)])
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            var reply = StubReply()
            replies.mutate { reply = $0.count > 1 ? $0.removeFirst() : $0[0] }
            return reply
        }
        let logs = Locked<[Rees46.SdkLogMessage]>([])
        Rees46.setLogHandler { message in
            if message.shopId == shop { logs.mutate { $0.append(message) } }
        }
        defer { Rees46.setLogHandler(nil) }
        let sdk = make(shop)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" && sdk.state == .ready })
        var heard: [Rees46.SdkState] = []
        sdk.onStateChange { heard.append($0) }

        clock.advance(by: 2 * 60 * 60 + 1)
        guard case .success? = getProduct(sdk) else { return XCTFail("the call went out after the failed renewal") }
        XCTAssertEqual(inits(shop).count, 2)
        XCTAssertTrue(eventually { self.scheduler.pending == 1 }, "the renewal is repeated after a pause")
        XCTAssertEqual(sdk.state, .ready, "not retrying")
        // Calls do not cut the pause short.
        expectNoRequest(to: "/init", shop: shop) {
            for _ in 0..<3 { _ = self.getProduct(sdk) }
        }
        // Back in the foreground the renewal goes at once; failing again, it keeps ready too.
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == 3 && self.scheduler.pending == 1 })
        XCTAssertEqual(sdk.state, .ready)
        XCTAssertEqual(heard, [.ready], "no state change")
        SdkLogger.awaitDelivery()
        XCTAssertFalse(logs.current.contains { $0.code == "init_saved_answer" }, "the saved answer is not replayed")
    }

    // MARK: - The foreground

    func test_back_in_the_foreground_two_hours_after_the_last_event_renews_the_session_however_long_in_the_background() {
        let shop = newShop()
        answerInit()
        let sdk = make(shop)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })

        // A short trip to the background inside the window: nothing.
        expectNoRequest(to: "/init", shop: shop) {
            clock.advance(by: 60 * 60)
            lifecycle.send(.didEnterBackground)
            clock.advance(by: 60)
            lifecycle.send(.willEnterForeground)
        }

        // Idle in the foreground past the window, then a minute in the background: renewed.
        clock.advance(by: 61 * 60)
        lifecycle.send(.didEnterBackground)
        clock.advance(by: 60)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 }, "inits \(inits(shop).count)")
        XCTAssertTrue(eventually { sdk.sessionId == "s-2" }, "sid \(String(describing: sdk.sessionId))")
        XCTAssertTrue(eventually { sdk.state == .ready }, "state \(sdk.state)")
    }

    func test_launched_in_the_background_the_first_foreground_after_the_window_renews_the_session() {
        let shop = newShop()
        answerInit()
        // A push or a fetch launched the app: it never went to the background, it came to the foreground.
        let sdk = make(shop)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
        expectNoRequest(to: "/init", shop: shop) {
            clock.advance(by: 30 * 60)
            lifecycle.send(.willEnterForeground)
        }
        clock.advance(by: 2 * 60 * 60)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 && sdk.sessionId == "s-2" })
    }

    // MARK: - What the app and the bridges see

    func test_the_session_listener_hears_every_new_sid_on_the_main_thread_and_not_the_same_one_again() {
        let shop = newShop()
        let first = DispatchSemaphore(value: 0)
        let fourth = DispatchSemaphore(value: 0)
        defer { first.signal(); fourth.signal() }
        answerInit(seance: { $0 == 3 ? "s-2" : "s-\($0)" }, gates: [1: first, 4: fourth])
        let sdk = make(shop)
        var heard: [String] = []
        var onMain = true
        let subscription = sdk.onSessionChange { sid in
            onMain = onMain && Thread.isMainThread
            heard.append(sid)
        }
        first.signal()
        XCTAssertTrue(eventually { heard == ["s-1"] })

        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { heard == ["s-1", "s-2"] })

        // The same sid again (the server's session lives on): nothing new.
        clock.advance(by: 10 * 60)
        XCTAssertEqual(sdk.initMachine?.askShop(), .asked)
        XCTAssertTrue(eventually { self.inits(shop).count == 3 })
        let again = expectation(description: "the same sid told again")
        again.isInverted = true
        let late = sdk.onSessionChange { _ in again.fulfill() }
        wait(for: [again], timeout: 0.3)
        late.cancel()
        XCTAssertEqual(heard, ["s-1", "s-2"])
        XCTAssertTrue(onMain)

        subscription.cancel()
        sdk.deleteUserCredentials()
        XCTAssertNil(sdk.sessionId, "the deleted customer's session is gone until /init brings one")
        fourth.signal()
        XCTAssertTrue(eventually { sdk.sessionId == "s-4" })
        XCTAssertEqual(heard, ["s-1", "s-2"], "a cancelled listener hears nothing")
    }

    func test_need_re_initialization_forgets_the_session_with_the_did() {
        let shop = newShop()
        answerInit(did: "new-did")
        let sdk = make(shop, identity: identity(sid: "OldSid0001", ago: 60), needReInitialization: true)

        XCTAssertNil(sdk.sessionId)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        XCTAssertNil(inits(shop).first?.query["did"])
        XCTAssertNil(inits(shop).first?.query["sid"])
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
    }

    func test_the_old_core_keeps_its_own_sid_and_tells_the_new_one_after_delete() {
        let shop = newShop()
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shop) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        let own = sdk.userSeance
        XCTAssertEqual(own.count, 10, "made by the old core")
        XCTAssertEqual(sdk.sessionId, own)
        XCTAssertNotEqual(own, "stub-seance", "the server's is not taken")
        XCTAssertNil(sdk.sessionWindow)

        let told = expectation(description: "told")
        let heard = Locked<[String]>([])
        let subscription = sdk.onSessionChange { sid in
            heard.mutate { $0.append(sid) }
            told.fulfill()
        }
        sdk.deleteUserCredentials()
        wait(for: [told], timeout: 5)
        XCTAssertEqual(heard.current, [sdk.userSeance])
        XCTAssertNotEqual(sdk.userSeance, own)
        subscription.cancel()
    }

    // MARK: - After the review of stages 4–5

    /// `/init` answers in turn from `replies`; the last one repeats.
    private func answerInit(_ replies: [StubReply]) {
        let list = Locked(replies)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            var reply = StubReply()
            list.mutate { reply = $0.count > 1 ? $0.removeFirst() : $0[0] }
            return reply
        }
    }

    private func live(_ sid: String) -> InMemoryUserIdentityRepository {
        identity(did: "d", sid: sid, ago: 0)
    }

    func test_an_init_answer_without_a_seance_keeps_a_live_sid_and_extends_its_window() {
        let shop = newShop()
        answerInit([StubReply(json: #"{"did":"d","seance":"s-1"}"#), StubReply(json: #"{"did":"d"}"#)])
        let stored = live("s-0")
        let sdk = make(shop, identity: stored)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
        clock.advance(by: 60 * 60)
        XCTAssertEqual(sdk.initMachine?.askShop(), .asked)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 2 && stored.seanceLastActTime == self.clock.now() })
        XCTAssertEqual(sdk.sessionId, "s-1", "the live sid stays")
        XCTAssertEqual(stored.seance, "s-1")
    }

    func test_an_init_answer_without_a_seance_after_the_window_ended_leaves_no_sid() {
        let shop = newShop()
        answerInit([StubReply(json: #"{"did":"d","seance":"s-1"}"#), StubReply(json: #"{"did":"d"}"#)])
        let sdk = make(shop, identity: live("s-0"))
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 2 })
        XCTAssertTrue(eventually { sdk.userSeance.isEmpty }, "an ended sid is not kept alive")
        XCTAssertNil(sdk.sessionId)
    }

    func test_the_return_of_the_network_sends_an_init_waiting_out_its_own_pause_at_once() {
        let shop = newShop()
        answerInit()
        let network = FakeConnectivity(online: true)
        let sdk = make(shop, identity: live("s-0"), connectivity: network)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })

        // The session ends offline: its /init fails at once and waits out a pause.
        network.isOnline = false
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.scheduler.pending == 1 }, "the /init waits out its pause")
        XCTAssertEqual(inits(shop).count, 1)

        network.isOnline = true
        XCTAssertTrue(eventually { self.inits(shop).count == 2 }, "at once, not after the pause")
        XCTAssertTrue(eventually { sdk.sessionId == "s-2" })
    }

    func test_the_servers_retry_after_on_init_is_cut_by_nothing_and_its_own_pause_by_the_foreground() {
        let shop = newShop()
        answerInit([
            StubReply(json: #"{"did":"d","seance":"s-1"}"#),
            StubReply(503, headers: ["Retry-After": "120"]),
            StubReply(json: #"{"did":"d","seance":"s-3"}"#),
        ])
        let network = FakeConnectivity(online: true)
        let sdk = make(shop, identity: live("s-0"), connectivity: network)
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 && self.scheduler.pendingDelays == [120] })

        expectNoRequest(to: "/init", shop: shop, within: 0.3) {
            self.lifecycle.send(.didEnterBackground)
            self.lifecycle.send(.willEnterForeground)
            _ = sdk.initMachine?.askShop()
            network.isOnline = false
            network.isOnline = true
        }
        XCTAssertEqual(scheduler.pendingDelays, [120], "the server's pause stands")
        scheduler.advance(by: 120)
        XCTAssertTrue(eventually { self.inits(shop).count == 3 })
        XCTAssertTrue(eventually { sdk.sessionId == "s-3" })
    }

    func test_popups_v3_and_the_polls_take_the_session_after_the_window_check() {
        let shop = newShop()
        answerInit()
        let sdk = make(shop, identity: live("s-0"))
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
        XCTAssertEqual(sdk.currentSessionId, "s-1")
        clock.advance(by: 2 * 60 * 60 + 1)
        XCTAssertEqual(sdk.currentSessionId, "", "no live session: none")

        let asked = Locked<[URL]>([])
        let transport = StoriesApiV3.transport
        defer { StoriesApiV3.transport = transport }
        StoriesApiV3.transport = { request, completion in
            request.url.map { url in asked.mutate { $0.append(url) } }
            completion(Data(#"{"status":"success","popups":[]}"#.utf8), HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }
        let api = PopupsV3API(sdk: sdk, appHost: { "app.stub.test" }, apiHost: "stub.test")
        let done = expectation(description: "list")
        api.fetchList(testMode: false, debug: false) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(inits(shop).count, 2, "the window was renewed first")
        let query = asked.current.first.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        XCTAssertEqual(query.first { $0.name == "sid" }?.value, "s-2", "the new session, not the ended one")

        let fields = Locked<String?>(nil)
        let polled = expectation(description: "poll body")
        DispatchQueue.global().async {
            fields.current = sdk.sessionIdForRequest()
            polled.fulfill()
        }
        wait(for: [polled], timeout: 5)
        XCTAssertEqual(fields.current, "s-2")
    }

    func test_a_poll_of_stories_v3_and_an_event_of_popups_v3_post_the_live_sid_renewed_first_when_it_ended() throws {
        let shop = newShop()
        answerInit()
        let sdk = make(shop, identity: live("s-0"))
        XCTAssertTrue(eventually { sdk.sessionId == "s-1" })
        clock.advance(by: 2 * 60 * 60 + 1)

        let posted = Locked<[(path: String, body: [String: Any])]>([])
        let transport = StoriesApiV3.transport
        defer { StoriesApiV3.transport = transport }
        StoriesApiV3.transport = { request, completion in
            let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            posted.mutate { $0.append((request.url?.path ?? "", body)) }
            let url = request.url ?? URL(fileURLWithPath: "/")
            completion(Data(#"{"status":"success","payload":{}}"#.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }

        // A poll of stories v3: the window ended, so a new session comes first and the poll goes with it.
        let answered = expectation(description: "poll")
        StoriesPollsApi(api: StoriesApiV3(domain: "app.stub.test"), sdk: sdk).answerMiniPoll(code: "mp-1", body: ["answer": "yes"]) { _ in
            answered.fulfill()
        }
        wait(for: [answered], timeout: 5)
        XCTAssertEqual(inits(shop).count, 2, "the window was renewed first")
        let poll = try XCTUnwrap(posted.current.first)
        XCTAssertEqual(poll.path, "/api/v3/polls/mini_polls/mp-1/answers")
        XCTAssertEqual(poll.body["sid"] as? String, "s-2", "the new session, not the ended one")
        XCTAssertEqual(poll.body["did"] as? String, "d")
        XCTAssertEqual(poll.body["shop_id"] as? String, shop)

        // An event of popups v3: the same, after the next window ended.
        clock.advance(by: 2 * 60 * 60 + 1)
        let api = PopupsV3API(sdk: sdk, appHost: { "app.stub.test" }, apiHost: "stub.test")
        api.sendEvent(popupId: 7, event: "view", channel: nil)
        XCTAssertTrue(eventually { posted.current.count == 2 })
        let event = try XCTUnwrap(posted.current.last)
        XCTAssertEqual(event.path, "/api/v3/storefront/popups/7/events")
        XCTAssertEqual(event.body["sid"] as? String, "s-3")
        XCTAssertEqual(event.body["event"] as? String, "view")
        XCTAssertEqual(inits(shop).count, 3)
    }
}
