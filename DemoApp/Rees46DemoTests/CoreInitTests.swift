//
//  CoreInitTests.swift
//  REES46Tests
//
//  `/init` of the new core (`sdk/core/init.md`, decision 0002, decision 1 of the core's brief) over
//  the stub server, with the clock, the scheduler and the app's lifecycle in the test's hands: every
//  row of the answer table, the pauses and `Retry-After`, `refused` kept and cleared, a stored did
//  without a saved answer, the saved answer as a fallback, calls that wait for the instance, the
//  request itself, the triggers, the logs, and the shared contract fixtures.
//

import XCTest
@testable import REES46

final class CoreInitTests: XCTestCase {

    private var shops: [String] = []
    private var clock = FakeClock()
    private var scheduler: ManualScheduler!
    private var lifecycle = ManualAppLifecycle()
    private let logLock = NSLock()
    private var logs: [Rees46.SdkLogMessage] = []

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        clock = FakeClock()
        scheduler = ManualScheduler(clock: clock)
        lifecycle = ManualAppLifecycle()
        logs = []
        Rees46.setLogHandler { [weak self] message in
            guard let self = self else { return }
            self.logLock.lock(); self.logs.append(message); self.logLock.unlock()
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
        return shop
    }

    private func storage(_ shop: String) -> ShopStorage {
        ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .none))
    }

    /// `/init` answers `reply`; every other request `{}`.
    private func answerInit(_ reply: StubReply?) {
        StubURLProtocol.handler = { request in
            request.path == "/init" ? reply : StubReply()
        }
    }

    private func make(
        _ shop: String,
        identity: UserIdentityRepository = InMemoryUserIdentityRepository(),
        keychain: KeychainInitStore = InMemoryKeychainInitStore(),
        needReInitialization: Bool = false,
        deviceId: String? = nil,
        sendAdvertisingId: Bool = false,
        connectivity: ConnectivityMonitor? = nil,
        completion: ((SdkError?) -> Void)? = nil
    ) -> SimplePersonalizationSDK {
        StubSDK.make(
            shopId: shop,
            identity: identity,
            keychain: keychain,
            needReInitialization: needReInitialization,
            logLevel: .debug,
            connectivity: connectivity,
            coreV2: true,
            sendAdvertisingId: sendAdvertisingId,
            deviceId: deviceId,
            environment: environment,
            completion: completion
        )
    }

    private func inits(_ shop: String) -> [StubRequest] {
        StubURLProtocol.requests(to: "/init", shop: shop)
    }

    private func codes(_ shop: String) -> [String] {
        logLock.lock(); defer { logLock.unlock() }
        return logs.filter { $0.shopId == shop }.map(\.code)
    }

    private func messages(_ shop: String, _ code: String) -> [Rees46.SdkLogMessage] {
        logLock.lock(); defer { logLock.unlock() }
        return logs.filter { $0.shopId == shop && $0.code == code }
    }

    /// Runs a GET of the old methods and hands back what it got.
    private func getProduct(_ sdk: SimplePersonalizationSDK, timeout: TimeInterval = 5) -> Result<ProductInfo, SdkError>? {
        let done = expectation(description: "products/get")
        var outcome: Result<ProductInfo, SdkError>?
        sdk.getProductInfo(id: "item-1") { outcome = $0; done.fulfill() }
        wait(for: [done], timeout: timeout)
        return outcome
    }

    /// Waits until the instance left `initializing`.
    @discardableResult
    private func settled(_ sdk: SimplePersonalizationSDK) -> Rees46.SdkState {
        XCTAssertTrue(eventually { sdk.state != .initializing }, "the instance stayed initializing")
        return sdk.state
    }

    // MARK: - The answer table

    func test_a_2xx_with_a_did_is_ready_and_saves_the_did_and_the_whole_answer() throws {
        let shop = newShop()
        let body = #"{"did":"new-did","seance":"s-1","currency":"RUB"}"#
        answerInit(StubReply(json: body))
        storage(shop).refused = false
        let identity = InMemoryUserIdentityRepository()
        let keychain = InMemoryKeychainInitStore()
        let ready = expectation(description: "init")
        var initError: SdkError?
        let sdk = make(shop, identity: identity, keychain: keychain) { initError = $0; ready.fulfill() }
        wait(for: [ready], timeout: 5)

        XCTAssertNil(initError)
        XCTAssertEqual(sdk.state, .ready)
        XCTAssertEqual(sdk.deviceId, "new-did")
        XCTAssertEqual(identity.deviceId, "new-did")
        XCTAssertEqual(sdk.storage.readSavedInitAnswer(), Data(body.utf8), "the whole answer is saved")
        XCTAssertNil(keychain.data, "the keychain backup is written only by sendIDFARequest and the migrations")
        XCTAssertEqual(sdk.userInfo.currency, "RUB")
        XCTAssertEqual(scheduler.pending, 0, "nothing to repeat")
        XCTAssertTrue(eventually { self.codes(shop).contains("init_succeeded") })
        XCTAssertEqual(messages(shop, "init_succeeded").first?.level, .info)
    }

    func test_the_saved_answer_is_replaced_by_every_successful_init() {
        let shop = newShop()
        storage(shop).writeSavedInitAnswer(Data(#"{"did":"kept-did","currency":"OLD"}"#.utf8))
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept-did"
        answerInit(StubReply(json: #"{"did":"kept-did","currency":"NEW"}"#))

        let sdk = make(shop, identity: identity)

        XCTAssertEqual(sdk.state, .ready, "a stored did is ready at once, with a saved answer too")
        XCTAssertTrue(eventually { sdk.storage.readSavedInitAnswer() == Data(#"{"did":"kept-did","currency":"NEW"}"#.utf8) })
    }

    func test_a_2xx_without_a_did_or_not_json_is_retrying_and_logged_as_decoding() {
        for body in ["{}", #"{"seance":"s"}"#, "not json", ""] {
            let shop = newShop()
            answerInit(StubReply(json: body))
            let ready = expectation(description: "init")
            var initError: SdkError?
            let sdk = make(shop) { initError = $0; ready.fulfill() }
            wait(for: [ready], timeout: 5)

            XCTAssertEqual(sdk.state, .retrying, body)
            guard case .decodeError? = initError else { return XCTFail("\(body): expected decodeError, got \(String(describing: initError))") }
            XCTAssertEqual(sdk.deviceId, "")
            XCTAssertTrue(eventually { self.codes(shop).contains("decoding_failed") }, body)
            XCTAssertTrue(eventually { self.scheduler.pending == 1 }, "\(body): a retry is scheduled")
            sdk.release()
        }
    }

    func test_no_answer_and_the_passing_server_errors_are_retrying() {
        let replies: [(String, StubReply?)] = [("no answer", StubReply.noAnswer)]
            + [500, 502, 503, 408, 410, 417, 426, 429].map { ("\($0)", StubReply($0)) }
        for (name, reply) in replies {
            let shop = newShop()
            answerInit(reply)
            let sdk = make(shop)

            XCTAssertEqual(settled(sdk), .retrying, name)
            XCTAssertFalse(sdk.storage.refused, name)
            XCTAssertTrue(eventually { self.scheduler.pending == 1 }, "\(name): a retry is scheduled")
            XCTAssertTrue(eventually { self.codes(shop).contains("init_retry") }, name)
            let retry = messages(shop, "init_retry").first
            XCTAssertEqual(retry?.level, .warning, name)
            XCTAssertEqual(retry?.context["attempt"], "1", name)
            XCTAssertEqual(retry?.context["delay_ms"], "1000", name)
            XCTAssertEqual(retry?.context["error"], reply.map { "http \($0.status)" } ?? "network", name)
            XCTAssertFalse(codes(shop).contains("init_failed"), "\(name): a failure that is repeated is init_retry alone")
            sdk.release()
        }
    }

    func test_402_403_404_are_refused_and_kept_on_disk() {
        for status in [402, 403, 404] {
            let shop = newShop()
            answerInit(StubReply(status, json: #"{"status":"error","message":"Restricted Mode"}"#))
            let ready = expectation(description: "init")
            var initError: SdkError?
            let sdk = make(shop) { initError = $0; ready.fulfill() }
            wait(for: [ready], timeout: 5)

            XCTAssertEqual(sdk.state, .refused, "\(status)")
            XCTAssertTrue(storage(shop).refused, "\(status): kept on disk")
            guard case let .custom(message)? = initError else { return XCTFail("\(status): expected the shop-blocked error") }
            XCTAssertEqual(message, "shop blocked")
            XCTAssertEqual(scheduler.pending, 0, "\(status): a refusal is not repeated")
            XCTAssertTrue(eventually { self.codes(shop).contains("init_refused") })
            XCTAssertEqual(messages(shop, "init_refused").first?.level, .error)
            XCTAssertFalse(codes(shop).contains("init_failed"), "\(status) is the shop's refusal, not an error of the SDK")
        }
    }

    func test_any_other_4xx_is_refused_and_logged_as_an_error_of_the_sdk() {
        for status in [400, 401, 405, 422, 451] {
            let shop = newShop()
            answerInit(StubReply(status))
            let sdk = make(shop)

            XCTAssertEqual(settled(sdk), .refused, "\(status)")
            XCTAssertTrue(storage(shop).refused)
            XCTAssertTrue(eventually { self.codes(shop).contains("init_refused") })
            XCTAssertEqual(messages(shop, "init_failed").first?.level, .error, "\(status)")
            XCTAssertFalse(codes(shop).contains("init_retry"), "\(status): a refusal is not repeated")
        }
    }

    // MARK: - Pauses

    func test_the_pause_doubles_from_one_second_to_five_minutes() {
        let shop = newShop()
        answerInit(StubReply(503))
        let sdk = make(shop)
        var pauses: [TimeInterval] = []
        for attempt in 1...11 {
            XCTAssertTrue(eventually { self.scheduler.pending == 1 && self.inits(shop).count == attempt }, "attempt \(attempt)")
            let pause = scheduler.pendingDelays.first ?? -1
            pauses.append(pause)
            scheduler.advance(by: pause)
        }
        XCTAssertEqual(pauses, [1, 2, 4, 8, 16, 32, 64, 128, 256, 300, 300])
        XCTAssertEqual(sdk.state, .retrying)
        XCTAssertTrue(eventually { self.messages(shop, "init_retry").count == 11 })
        let retries = messages(shop, "init_retry")
        XCTAssertEqual(retries.map { $0.context["delay_ms"] }, pauses.map { String(Int($0) * 1000) }, "the pause in milliseconds")
        XCTAssertEqual(retries.map { $0.context["attempt"] }, (1...11).map { String($0) })
        XCTAssertFalse(codes(shop).contains("init_failed"))
        sdk.release()
    }

    func test_retry_after_counts_only_on_429_and_503_and_is_held_between_one_second_and_five_minutes() {
        let shop = newShop()
        let date = DateFormatter()
        date.locale = Locale(identifier: "en_US_POSIX")
        date.timeZone = TimeZone(identifier: "GMT")
        date.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let inTwoMinutes = date.string(from: Date().addingTimeInterval(120))
        let replies = Locked<[StubReply]>([
            StubReply(500, headers: ["Retry-After": "7"]),
            StubReply(503, headers: ["Retry-After": "600"]),
            StubReply(429, headers: ["Retry-After": "inf"]),
            StubReply(503, headers: ["Retry-After": "nan"]),
            StubReply(503, headers: ["Retry-After": "-5"]),
            StubReply(503, headers: ["Retry-After": "1e400"]),
            StubReply(429, headers: ["Retry-After": inTwoMinutes]),
            StubReply(408, headers: ["Retry-After": "7"]),
            StubReply(json: #"{"did":"d"}"#),
        ])
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            var reply = StubReply()
            replies.mutate { reply = $0.count > 1 ? $0.removeFirst() : $0[0] }
            return reply
        }
        let sdk = make(shop)
        var pauses: [TimeInterval] = []
        for attempt in 1...8 {
            XCTAssertTrue(eventually { self.scheduler.pending == 1 && self.inits(shop).count == attempt }, "attempt \(attempt)")
            let pause = scheduler.pendingDelays.first ?? -1
            pauses.append(pause)
            scheduler.advance(by: pause)
        }
        XCTAssertTrue(eventually { sdk.state == .ready })
        // 500 and 408 ignore it; 600 is held to five minutes; inf, nan, negative and overflowing values
        // are none; a date counts.
        XCTAssertEqual(Array(pauses.prefix(6)), [1, 300, 4, 8, 16, 32])
        XCTAssertEqual(pauses[6], 120, accuracy: 3)
        XCTAssertEqual(pauses[7], 128)
    }

    func test_retry_after_is_honoured_and_a_success_resets_the_pause() {
        let shop = newShop()
        let lock = NSLock()
        var replies: [StubReply] = [
            StubReply(503, headers: ["Retry-After": "7"]),
            StubReply(429, headers: ["Retry-After": "0"]),
            StubReply(json: #"{"did":"d"}"#),
        ]
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            lock.lock(); defer { lock.unlock() }
            return replies.count > 1 ? replies.removeFirst() : replies[0]
        }
        let sdk = make(shop)

        XCTAssertTrue(eventually { self.scheduler.pending == 1 })
        XCTAssertEqual(scheduler.pendingDelays, [7], "Retry-After of a 503")
        scheduler.advance(by: 7)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 && self.scheduler.pending == 1 })
        XCTAssertEqual(scheduler.pendingDelays, [1], "Retry-After: 0 still waits a second")
        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { sdk.state == .ready })
        XCTAssertEqual(scheduler.pending, 0)
        XCTAssertTrue(messages(shop, "init_retry").contains { $0.context["delay_ms"] == "7000" && $0.context["status"] == "503" })
    }

    // MARK: - refused

    func test_a_shop_refused_on_an_earlier_launch_stays_refused_until_init_passes() {
        let shop = newShop()
        storage(shop).refused = true
        answerInit(StubReply(json: #"{"did":"d-1"}"#, delay: 1))
        let ready = expectation(description: "init")
        var initError: SdkError?
        let sdk = make(shop) { initError = $0; ready.fulfill() }

        XCTAssertEqual(sdk.state, .refused)
        guard case let .failure(.custom(message))? = getProduct(sdk) else { return XCTFail("a call of a refused shop fails") }
        XCTAssertEqual(message, "shop blocked")
        XCTAssertTrue(StubURLProtocol.requests(to: "/products/get", shop: shop).isEmpty, "nothing goes out for a refused shop")
        XCTAssertTrue(eventually { self.inits(shop).count == 1 }, "/init goes on every launch")

        wait(for: [ready], timeout: 5)
        XCTAssertNil(initError)
        XCTAssertEqual(sdk.state, .ready)
        XCTAssertFalse(storage(shop).refused, "a successful /init clears it")
        guard case .success? = getProduct(sdk) else { return XCTFail("the shop serves again") }
    }

    func test_a_refusal_is_not_asked_again_while_the_app_runs() {
        let shop = newShop()
        answerInit(StubReply(403))
        let sdk = make(shop)
        XCTAssertEqual(settled(sdk), .refused)

        expectNoRequest(to: "/init", shop: shop) {
            lifecycle.send(.didEnterBackground)
            clock.advance(by: 3 * 60 * 60)
            lifecycle.send(.willEnterForeground)
            XCTAssertNotEqual(sdk.initMachine?.askShop(), .asked)
        }

        XCTAssertEqual(inits(shop).count, 1)
        XCTAssertEqual(sdk.state, .refused)
    }

    // MARK: - Decision 1 and the saved answer

    func test_a_stored_did_is_ready_at_once_with_a_saved_answer_or_without_and_init_still_goes() {
        for withSavedAnswer in [false, true] {
            let shop = newShop()
            if withSavedAnswer {
                storage(shop).writeSavedInitAnswer(Data(#"{"did":"old-did"}"#.utf8))
            }
            let identity = InMemoryUserIdentityRepository()
            identity.deviceId = "old-did"
            // A session inside its window: the call needs no new sid (`CoreSessionTests` has the other).
            identity.seance = "LiveSid001"
            identity.seanceLastActTime = clock.now()
            // /init is held until the call is over: the call cannot have waited for it.
            let answer = DispatchSemaphore(value: 0)
            StubURLProtocol.handler = { request in
                guard request.path == "/init" else { return StubReply() }
                _ = answer.wait(timeout: .now() + 10)
                return StubReply(json: #"{"did":"old-did"}"#)
            }
            let ready = expectation(description: "init")
            let sdk = make(shop, identity: identity) { error in
                XCTAssertNil(error)
                ready.fulfill()
            }

            XCTAssertEqual(sdk.state, .ready, "saved answer: \(withSavedAnswer)")
            wait(for: [ready], timeout: 1)
            guard case .success? = getProduct(sdk) else { return XCTFail("a call works while /init is held") }
            XCTAssertEqual(StubURLProtocol.requests(to: "/products/get", shop: shop).first?.query["did"], "old-did")
            XCTAssertEqual(inits(shop).count, 1, "/init is on its way")
            XCTAssertEqual(inits(shop).first?.query["did"], "old-did")
            answer.signal()
            sdk.release()
        }
    }

    func test_a_stored_did_without_a_saved_answer_keeps_working_while_init_is_repeated() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "old-did"
        answerInit(StubReply(503))
        let sdk = make(shop, identity: identity)

        XCTAssertTrue(eventually { sdk.state == .retrying })
        XCTAssertTrue(sdk.initMachine?.isUsable ?? false)
        guard case .success? = getProduct(sdk) else { return XCTFail("a stored did works as ready") }
    }

    func test_without_an_answer_the_saved_answer_stands_in_and_its_did_is_taken() {
        let shop = newShop()
        storage(shop).writeSavedInitAnswer(Data(#"{"did":"Saved00001","seance":"OldSeance1","popups_v3":true}"#.utf8))
        answerInit(StubReply.noAnswer)
        let identity = InMemoryUserIdentityRepository()
        let ready = expectation(description: "init")
        var initError: SdkError?
        let sdk = make(shop, identity: identity) { initError = $0; ready.fulfill() }
        wait(for: [ready], timeout: 5)

        XCTAssertNil(initError, "the saved answer lets the instance work")
        XCTAssertEqual(sdk.state, .retrying)
        XCTAssertEqual(sdk.deviceId, "Saved00001")
        XCTAssertEqual(identity.deviceId, "Saved00001")
        guard case .success? = getProduct(sdk) else { return XCTFail("calls work as in ready") }
        XCTAssertEqual(StubURLProtocol.requests(to: "/products/get", shop: shop).first?.query["did"], "Saved00001")
        XCTAssertTrue(eventually { self.codes(shop).contains("init_saved_answer") })
        XCTAssertEqual(messages(shop, "init_saved_answer").count, 1)
        XCTAssertTrue(eventually { self.scheduler.pending == 1 }, "/init is still repeated")
        sdk.release()
    }

    func test_with_a_saved_answer_init_does_not_wait_for_the_network_and_without_one_it_does() {
        let offline = FakeConnectivity(online: false)
        let saved = newShop()
        storage(saved).writeSavedInitAnswer(Data(#"{"did":"saved-did"}"#.utf8))
        answerInit(StubReply(json: #"{"did":"saved-did"}"#))
        let withSaved = make(saved, connectivity: offline)
        XCTAssertEqual(settled(withSaved), .retrying, "offline, /init fails at once and the saved answer stands in")
        XCTAssertTrue(inits(saved).isEmpty)
        XCTAssertTrue(withSaved.initMachine?.isUsable ?? false)
        withSaved.release()

        let fresh = newShop()
        var waiting: SimplePersonalizationSDK?
        expectNoRequest(to: "/init", shop: fresh) {
            waiting = make(fresh, connectivity: offline)
        }
        guard let waiting = waiting else { return XCTFail("no instance") }
        XCTAssertEqual(waiting.state, .initializing, "without a saved answer /init waits for the network")
        offline.isOnline = true
        XCTAssertTrue(eventually { waiting.state == .ready })
    }

    func test_a_refusal_wins_over_the_saved_answer() {
        let shop = newShop()
        storage(shop).writeSavedInitAnswer(Data(#"{"did":"Saved00001"}"#.utf8))
        answerInit(StubReply(402))
        let sdk = make(shop)

        XCTAssertEqual(settled(sdk), .refused)
        XCTAssertFalse(sdk.initMachine?.isUsable ?? true)
        guard case .failure(.custom("shop blocked"))? = getProduct(sdk) else { return XCTFail("the server's answer wins") }
    }

    // MARK: - Calls that wait

    func test_a_call_waits_for_ready_and_goes_out_with_the_did() {
        let shop = newShop()
        let answer = DispatchSemaphore(value: 0)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            _ = answer.wait(timeout: .now() + 10)
            return StubReply(json: #"{"did":"fresh-did"}"#)
        }
        let sdk = make(shop)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        let done = expectation(description: "call")
        expectNoRequest(to: "/products/get", shop: shop) {
            sdk.getProductInfo(id: "item-1") { _ in done.fulfill() }
        }

        answer.signal()
        wait(for: [done], timeout: 5)
        XCTAssertEqual(StubURLProtocol.requests(to: "/products/get", shop: shop).first?.query["did"], "fresh-did")
    }

    func test_a_call_that_is_not_let_through_within_its_timeout_is_a_timeout() {
        let shop = newShop()
        let answer = DispatchSemaphore(value: 0)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            _ = answer.wait(timeout: .now() + 10)
            return StubReply(json: #"{"did":"late-did"}"#)
        }
        defer { answer.signal() }
        let sdk = make(shop)
        let machine = try? XCTUnwrap(sdk.initMachine)

        let done = expectation(description: "wait")
        let outcome = Locked<Rees46.SdkError??>(nil)
        _Concurrency.Task {
            outcome.current = .some(await machine?.awaitUsable(timeout: 3))
            done.fulfill()
        }
        XCTAssertTrue(eventually { self.scheduler.pendingDelays == [3] })
        scheduler.advance(by: 2)
        XCTAssertNil(outcome.current)
        scheduler.advance(by: 1)
        wait(for: [done], timeout: 5)
        XCTAssertEqual(outcome.current, .some(.timeout))

        // The old methods: the request's own timeout, mapped to the old error.
        let call = expectation(description: "call")
        var legacy: Result<ProductInfo, SdkError>?
        sdk.getProductInfo(id: "item-1") { legacy = $0; call.fulfill() }
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(NetworkClient.defaultTimeout) })
        scheduler.advance(by: NetworkClient.defaultTimeout)
        wait(for: [call], timeout: 5)
        guard case .failure(.invalidResponse)? = legacy else { return XCTFail("a timeout is invalidResponse for the old methods") }
        XCTAssertTrue(StubURLProtocol.requests(to: "/products/get", shop: shop).isEmpty)
    }

    func test_one_shop_waiting_for_init_does_not_hold_another() {
        let held = newShop()
        let other = newShop()
        let answer = DispatchSemaphore(value: 0)
        defer { answer.signal() }
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            if request.query["shop_id"] == held { _ = answer.wait(timeout: .now() + 10) }
            return StubReply(json: #"{"did":"d"}"#)
        }
        let waiting = make(held)
        let ready = make(other)
        XCTAssertTrue(eventually { ready.state == .ready })

        // The held shop's /init is answered only after this: the call did not wait for it.
        guard case .success? = getProduct(ready) else { return XCTFail("the other shop's call went out") }
        XCTAssertEqual(waiting.state, .initializing)
    }

    func test_release_ends_the_calls_that_wait_and_later_ones_are_not_initialized() {
        let shop = newShop()
        let answer = DispatchSemaphore(value: 0)
        defer { answer.signal() }
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            _ = answer.wait(timeout: .now() + 10)
            return StubReply(json: #"{"did":"d"}"#)
        }
        let sdk = make(shop)
        let machine = sdk.initMachine
        let waiting = expectation(description: "waiting")
        let ended = Locked<Rees46.SdkError??>(nil)
        _Concurrency.Task {
            ended.current = .some(await machine?.awaitUsable(timeout: 30))
            waiting.fulfill()
        }
        XCTAssertTrue(eventually { self.scheduler.pending == 1 })

        sdk.release()
        wait(for: [waiting], timeout: 5)
        XCTAssertEqual(ended.current, .some(.cancelled))
        XCTAssertEqual(sdk.state, .notInitialized)
        guard case .failure(.initializationFailed)? = getProduct(sdk) else { return XCTFail("a call after release is notInitialized") }
    }

    // MARK: - Review of stage 3

    func test_an_init_cancelled_by_anything_but_release_or_reset_is_repeated() {
        let shop = newShop()
        let replies = Locked<[StubReply]>([
            // The app's URL protocol cancels it.
            StubReply(json: "{}", cutAfter: 0, cutWith: .cancelled),
            StubReply(json: #"{"did":"after-cancel"}"#),
        ])
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            var reply = StubReply()
            replies.mutate { reply = $0.count > 1 ? $0.removeFirst() : $0[0] }
            return reply
        }
        let sdk = make(shop)

        XCTAssertTrue(eventually { sdk.state == .retrying && self.scheduler.pending == 1 }, "\(sdk.state)")
        XCTAssertTrue(messages(shop, "init_retry").contains { $0.context["error"] == "cancelled" })
        XCTAssertFalse(codes(shop).contains("init_failed"))
        scheduler.advance(by: scheduler.pendingDelays.first ?? 1)
        XCTAssertTrue(eventually { sdk.state == .ready })
        XCTAssertEqual(sdk.deviceId, "after-cancel")
    }

    func test_delete_user_credentials_cancels_the_init_with_the_old_did_and_the_old_did_never_goes_out_again() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "old-did"
        let held = DispatchSemaphore(value: 0)
        defer { held.signal() }
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            guard request.query["did"] == nil else {
                _ = held.wait(timeout: .now() + 10)
                return StubReply(json: #"{"did":"old-did"}"#)
            }
            return StubReply(json: #"{"did":"new-did"}"#)
        }
        let sdk = make(shop, identity: identity)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })

        sdk.deleteUserCredentials()

        XCTAssertTrue(eventually { self.messages(shop, "request_cancelled").contains { $0.context["path"] == "init" } },
                      "the /init with the deleted did is cancelled")
        XCTAssertTrue(eventually { sdk.state == .ready && identity.deviceId == "new-did" })
        // A caller that still holds the deleted did does not send it: the stored one goes.
        let posted = expectation(description: "post")
        sdk.postRequest(path: "push", params: ["event": "view", "did": "old-did"]) { _ in posted.fulfill() }
        wait(for: [posted], timeout: 5)
        XCTAssertEqual(StubURLProtocol.requests(to: "/push", shop: shop).last?.body["did"] as? String, "new-did")
    }

    func test_a_refused_shop_sends_no_init_of_its_own_and_an_answer_saved_by_send_idfa_request_stands_in() {
        let refusedShop = newShop()
        answerInit(StubReply(403))
        let refused = make(refusedShop)
        XCTAssertEqual(settled(refused), .refused)
        let idfa = expectation(description: "idfa")
        var outcome: Result<InitResponse, SdkError>?
        expectNoRequest(to: "/init", shop: refusedShop) {
            refused.sendIDFARequest(idfa: UUID()) { outcome = $0; idfa.fulfill() }
        }
        wait(for: [idfa], timeout: 5)
        guard case .failure(.custom("shop blocked"))? = outcome else { return XCTFail("\(String(describing: outcome))") }

        // Without a did or a saved answer, retrying lets nothing through; an answer saved by
        // sendIDFARequest does.
        let shop = newShop()
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            return request.query["ios_advertising_id"] == nil ? StubReply(503) : StubReply(json: #"{"did":"idfa-did"}"#)
        }
        let sdk = make(shop)
        XCTAssertTrue(eventually { sdk.state == .retrying })
        XCTAssertEqual(sdk.initMachine?.isUsable, false)
        let saved = expectation(description: "saved")
        sdk.sendIDFARequest(idfa: UUID()) { _ in saved.fulfill() }
        wait(for: [saved], timeout: 5)
        XCTAssertEqual(sdk.initMachine?.isUsable, true, "the saved answer stands in")
        sdk.release()
    }

    func test_start_reads_the_saved_answer_and_the_keychain_off_the_callers_thread() {
        final class RecordingKeychain: KeychainInitStore {
            let threads = Locked<[Bool]>([])
            func readInitData() -> Data? {
                threads.mutate { $0.append(Thread.isMainThread) }
                return nil
            }
            func writeInitData(_ data: Data) {}
            func clear() {}
        }
        XCTAssertTrue(Thread.isMainThread)
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept-did"
        let keychain = RecordingKeychain()
        answerInit(StubReply(json: #"{"did":"kept-did"}"#))
        let sdk = make(shop, identity: identity, keychain: keychain)

        XCTAssertEqual(sdk.state, .ready)
        XCTAssertTrue(eventually { !keychain.threads.current.isEmpty }, "/init asked for the saved answer")
        XCTAssertFalse(keychain.threads.current.contains(true), "not on the main thread")
    }

    func test_two_shops_on_one_app_groups_key_keep_their_own_refusal() {
        let group = "group.test.\(UUID().uuidString.prefix(6))"
        defer { UserDefaults.standard.removePersistentDomain(forName: group) }
        let refusing = newShop()
        let serving = newShop()
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            return request.query["shop_id"] == refusing ? StubReply(403) : StubReply(json: #"{"did":"serving-did"}"#)
        }
        func launch(_ shop: String) -> SimplePersonalizationSDK {
            StubSDK.make(
                shopId: shop, logLevel: .debug, coreV2: true, environment: environment,
                shopStorage: ShopStorage(shopId: shop, storageKey: group, logger: SdkLogger(shopId: shop, level: .none))
            )
        }
        let first = launch(refusing)
        let second = launch(serving)
        XCTAssertEqual(settled(first), .refused)
        XCTAssertEqual(settled(second), .ready)
        first.release()
        second.release()

        // The next launch: the refusal is the refusing shop's only.
        StubURLProtocol.handler = { request in
            request.path == "/init" ? StubReply(json: #"{"did":"d"}"#, delay: 1) : StubReply()
        }
        XCTAssertEqual(launch(serving).state, .initializing)
        XCTAssertEqual(launch(refusing).state, .refused)
    }

    func test_a_stale_answer_does_not_take_the_first_answer_of_the_customer() {
        CoreFlag.reset(to: true)
        let shop = newShop()
        let answer = DispatchSemaphore(value: 0)
        defer { answer.signal() }
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply(json: #"{"status":"success"}"#) }
            _ = answer.wait(timeout: .now() + 10)
            return StubReply(json: #"{"did":"d"}"#)
        }
        let sdk = SimplePersonalizationSDK(
            shopId: shop, userEmail: "a@b.c", apiDomain: "stub.test", autoSendPushToken: false,
            enableAutoPopupPresentation: false, coreV2: true, environment: environment,
            userIdentity: InMemoryUserIdentityRepository(), keychainStore: InMemoryKeychainInitStore()
        )
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })

        // The answer of an /init that is no longer the machine's does nothing.
        expectNoRequest(to: "/profile/set", shop: shop) {
            sdk.initMachine(didFinish: InitResponse(json: ["did": "d"]), fromServer: true, generation: 999)
        }
        answer.signal()
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/profile/set", shop: shop).count == 1 },
                      "the first answer of the customer sends the contacts given at creation")
    }

    // MARK: - The request

    func test_init_sends_the_stream_of_the_config_and_the_advertising_id_only_when_asked() {
        CoreFlag.reset(to: true)
        let shop = newShop()
        answerInit(StubReply(json: #"{"did":"d"}"#))
        let identity = InMemoryUserIdentityRepository()
        identity.advertisingId = "AD-ID-1"
        let flutter = SimplePersonalizationSDK(
            shopId: shop, apiDomain: "stub.test", stream: "flutter", autoSendPushToken: false,
            enableAutoPopupPresentation: false, coreV2: true, environment: environment,
            userIdentity: identity, keychainStore: InMemoryKeychainInitStore()
        )
        XCTAssertEqual(settled(flutter), .ready)
        let query = inits(shop).first?.query ?? [:]
        XCTAssertEqual(query["stream"], "flutter")
        XCTAssertEqual(query["shop_id"], shop)
        XCTAssertNotNil(query["tz"])
        XCTAssertNil(query["ios_advertising_id"], "only with sendAdvertisingId")
        XCTAssertNil(query["segment"], "/init carries no segment")
        XCTAssertNil(query["sid"], "no session yet: the new core makes none")

        let asked = newShop()
        let askedIdentity = InMemoryUserIdentityRepository()
        askedIdentity.advertisingId = "AD-ID-2"
        let sdk = make(asked, identity: askedIdentity, sendAdvertisingId: true)
        XCTAssertEqual(settled(sdk), .ready)
        XCTAssertEqual(inits(asked).first?.query["ios_advertising_id"], "AD-ID-2")
        XCTAssertEqual(inits(asked).first?.timeout, NetworkClient.initTimeout)
    }

    func test_the_device_id_of_the_config_is_taken_only_by_a_shop_without_one() {
        let shop = newShop()
        answerInit(StubReply(json: #"{"did":"app-did"}"#))
        let identity = InMemoryUserIdentityRepository()
        let sdk = make(shop, identity: identity, deviceId: "app-did")
        XCTAssertEqual(sdk.state, .ready, "a device id without a saved answer is ready at once")
        XCTAssertEqual(identity.deviceId, "app-did")
        XCTAssertTrue(eventually { self.inits(shop).count == 1 })
        XCTAssertEqual(inits(shop).first?.query["did"], "app-did")

        let own = newShop()
        let ownIdentity = InMemoryUserIdentityRepository()
        ownIdentity.deviceId = "own-did"
        let kept = make(own, identity: ownIdentity, deviceId: "app-did")
        XCTAssertEqual(kept.deviceId, "own-did")
        XCTAssertEqual(ownIdentity.deviceId, "own-did")
        XCTAssertTrue(eventually { self.messages(own, "invalid_config").contains { $0.context["reason"] == "device_id_kept" } })
    }

    func test_need_re_initialization_gets_a_new_did_and_calls_wait_for_it() {
        let shop = newShop()
        storage(shop).writeSavedInitAnswer(Data(#"{"did":"old-did"}"#.utf8))
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "old-did"
        let keychain = InMemoryKeychainInitStore(Data(#"{"did":"old-did"}"#.utf8))
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            return StubReply(json: #"{"did":"\#(request.query["did"] ?? "new-did")"}"#, delay: 0.5)
        }
        let sdk = make(shop, identity: identity, keychain: keychain, needReInitialization: true)

        XCTAssertEqual(sdk.state, .initializing)
        XCTAssertEqual(sdk.deviceId, "")
        XCTAssertNil(keychain.data, "the keychain backup is forgotten too")
        guard case .success? = getProduct(sdk) else { return XCTFail("the call waited and went out") }
        XCTAssertEqual(StubURLProtocol.requests(to: "/products/get", shop: shop).first?.query["did"], "new-did")
        XCTAssertNil(inits(shop).first?.query["did"])
        XCTAssertEqual(identity.deviceId, "new-did")
        XCTAssertEqual(sdk.storage.readSavedInitAnswer(), Data(#"{"did":"new-did"}"#.utf8), "the new answer is kept")
    }

    // MARK: - Triggers

    func test_init_goes_again_back_in_the_foreground_two_hours_after_the_last_event() {
        let shop = newShop()
        answerInit(StubReply(json: #"{"did":"d"}"#))
        let sdk = make(shop)
        XCTAssertEqual(settled(sdk), .ready)

        expectNoRequest(to: "/init", shop: shop) {
            lifecycle.send(.didEnterBackground)
            clock.advance(by: 2 * 60 * 60 - 1)
            lifecycle.send(.willEnterForeground)
        }
        XCTAssertEqual(inits(shop).count, 1, "two hours have not passed")

        clock.advance(by: 2)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 })
        XCTAssertEqual(inits(shop).last?.query["did"], "d")
        XCTAssertTrue(eventually { sdk.state == .ready })

        sdk.release()
        XCTAssertEqual(lifecycle.observerCount, 0, "a released instance stops observing the app")
    }

    func test_check_shop_sends_init_at_most_once_in_ten_minutes() {
        let shop = newShop()
        answerInit(StubReply(json: #"{"did":"d"}"#))
        let sdk = make(shop)
        XCTAssertEqual(settled(sdk), .ready)
        let core = sdk.core as? CoreV2

        XCTAssertEqual(core?.machine.askShop(), .asked)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 })
        XCTAssertNotEqual(core?.machine.askShop(), .asked)
        clock.advance(by: 9 * 60)
        XCTAssertNotEqual(core?.machine.askShop(), .asked)
        clock.advance(by: 60)
        XCTAssertEqual(core?.machine.askShop(), .asked)
        XCTAssertTrue(eventually { self.inits(shop).count == 3 })

        // A shop that refused now: the check ends in refused.
        answerInit(StubReply(404))
        clock.advance(by: 10 * 60)
        XCTAssertEqual(core?.machine.askShop(), .asked)
        XCTAssertTrue(eventually { sdk.state == .refused })
    }

    // MARK: - Contract fixtures

    func test_the_shared_init_fixtures_pass_on_the_new_core() throws {
        for item in try ContractFixtures.cases("init") {
            let name = item["name"] as? String ?? "?"
            let shop = newShop()
            if let saved = item["saved"] as? [String: Any] {
                storage(shop).writeSavedInitAnswer(try JSONSerialization.data(withJSONObject: saved))
            }
            let response = item["response"] as? [String: Any] ?? [:]
            if let status = response["status"] as? Int {
                let body = response["body"].flatMap { $0 is NSNull ? nil : $0 }
                let json = try body.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) } ?? ""
                answerInit(StubReply(status, json: json))
            } else {
                answerInit(StubReply.noAnswer)
            }
            let sdk = make(shop)
            let expect = item["expect"] as? [String: Any] ?? [:]

            XCTAssertTrue(eventually { sdk.state.rawValue == expect["state"] as? String }, "\(name): \(sdk.state)")
            if let deviceId = expect["deviceId"] as? String {
                XCTAssertTrue(eventually { sdk.deviceId == deviceId }, "\(name): \(sdk.deviceId)")
            }
            if let works = expect["methodsWorkAsReady"] as? Bool {
                XCTAssertEqual(sdk.initMachine?.isUsable, works, name)
            }
            if let sessionId = expect["sessionId"] as? String {
                XCTAssertTrue(eventually { sdk.sessionId == sessionId }, "\(name): \(String(describing: sdk.sessionId))")
            }
            sdk.release()
        }
    }
}
