//
//  NotificationsNamespaceTests.swift
//  REES46Tests
//
//  `sdk.notifications` over the stub server: the requests of the proposed fixture with what the core
//  adds, its refusals and answers, one event per message whoever sends it, the source of a click, no
//  callback for an event the app sends, the device's token, the shop's callbacks, the old core's
//  refusal, `release()`, a refused shop, `completion` once on the main thread, the `async` forms.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class NotificationsNamespaceTests: CoreScenarioTestCase {

    // MARK: - The fixture's cases

    /// The cases of the proposed `notifications` fixture for iOS: those of no platform and of iOS. Not
    /// those of `getHistory`, a server method the package tests hold to the fixture
    /// (`NotificationsPackageTests`).
    private static func iosCases() throws -> [ContractCase] {
        try ContractFixtures.cases("notifications", from: .proposed)
            .filter { ($0["platform"] as? String ?? "ios") == "ios" }
            .map(ContractCase.init)
            .filter { $0.call?.method != "getHistory" }
    }

    /// The event of a `track…` method of the fixture.
    private static func event(of method: String) -> Rees46.PushEvent? {
        guard method.hasPrefix("track") else { return nil }
        return Rees46.PushEvent(rawValue: method.dropFirst("track".count).lowercased())
    }

    // MARK: - Calls

    /// A call with `completion` and what it got, called on the main thread.
    private func outcome(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ start: (@escaping (Result<Void, Rees46.SdkError>) -> Void) -> Void
    ) -> Result<Void, Rees46.SdkError>? {
        let done = expectation(description: "completion")
        let result = Locked<Result<Void, Rees46.SdkError>?>(nil)
        start { value in
            XCTAssertTrue(Thread.isMainThread, "completion on the main thread", file: file, line: line)
            result.current = value
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return result.current
    }

    /// The fixture's `call` on `sdk`.
    private func run(_ call: ContractCase.Call, on sdk: PersonalizationSDK, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        let code = call.args["code"] as? String ?? ""
        let type = call.args["type"] as? String ?? ""
        switch call.method {
        case "trackDelivered":
            sdk.notifications.trackDelivered(code: code, type: type, completion: completion)
        case "trackOpened":
            sdk.notifications.trackOpened(code: code, type: type, completion: completion)
        case "trackClicked":
            sdk.notifications.trackClicked(code: code, type: type, completion: completion)
        case "trackClosed":
            sdk.notifications.trackClosed(code: code, type: type, completion: completion)
        case "setPushToken":
            guard let provider = Rees46.PushProvider(rawValue: call.args["provider"] as? String ?? "") else {
                return XCTFail("\(call.name): no provider")
            }
            sdk.notifications.setPushToken(call.args["token"] as? String ?? "", provider: provider, completion: completion)
        default:
            XCTFail("\(call.name) is not a method of notifications")
        }
    }

    private func error(of result: Result<Void, Rees46.SdkError>?) -> Rees46.SdkError? {
        if case .failure(let error)? = result { return error }
        return nil
    }

    private func succeeded(_ result: Result<Void, Rees46.SdkError>?) -> Bool {
        if case .success? = result { return true }
        return false
    }

    /// An `async` call and what it threw, `nil` for none.
    private func thrown(cancel: ((_Concurrency.Task<Void, Error>) -> Void)? = nil, _ body: @escaping () async throws -> Void) -> Rees46.SdkError?? {
        let done = expectation(description: "async")
        let result = Locked<Rees46.SdkError??>(nil)
        let task = _Concurrency.Task { try await body() }
        _Concurrency.Task {
            do {
                try await task.value
                result.current = .some(nil)
            } catch let error as Rees46.SdkError {
                result.current = .some(error)
            } catch {
                XCTFail("not an SdkError: \(error)")
            }
            done.fulfill()
        }
        cancel?(task)
        wait(for: [done], timeout: 5)
        return result.current
    }

    /// The paths of the events of pushes and the token's.
    private static let paths = ["/track/delivered", "/track/opened", "/track/clicked", "/track/closed", "/track/received", "/mobile_push_tokens"]

    private func sentNothing(_ shop: String) -> Bool {
        Self.paths.allSatisfy { requests($0, shop).isEmpty }
    }

    // MARK: - The fixture

    func test_each_call_of_the_fixture_sends_its_request_with_the_shop_and_the_device() throws {
        let cases = try Self.iosCases().filter { $0.request != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let expected = try XCTUnwrap(item.request, item.name)
            // A shop each: an event goes once per message, a token once a week.
            let shop = newShop()
            let sdk = makeV2(shop)
            XCTAssertTrue(succeeded(outcome { run(call, on: sdk, completion: $0) }), item.name)
            XCTAssertTrue(eventually { self.requests("/" + expected.path, shop).count == 1 }, item.name)
            let sent = try XCTUnwrap(requests("/" + expected.path, shop).first, item.name)
            XCTAssertEqual(sent.method, expected.method, item.name)
            for (key, value) in expected.body {
                XCTAssertEqual(sent.body[key] as? String, value as? String, "\(item.name): \(key)")
            }
            XCTAssertEqual(sent.body["shop_id"] as? String, shop, item.name)
            XCTAssertEqual(sent.body["did"] as? String, "d", item.name)
            XCTAssertNil(sent.body["push_provider"], "\(item.name): iOS sends none")
            if call.method.hasPrefix("track") {
                XCTAssertEqual(sent.body["stream"] as? String, "ios", item.name)
                XCTAssertNil(sent.body["sid"], "\(item.name): the server does not read it")
                XCTAssertNil(sent.body["seance"], item.name)
                XCTAssertNil(sent.body["source"], item.name)
            }
            XCTAssertTrue(queueIdle(sdk))
            XCTAssertEqual(Self.paths.map { requests($0, shop).count }.reduce(0, +), 1, "\(item.name): that request alone")
            sdk.release()
        }
    }

    func test_each_refusal_of_the_fixture_sends_nothing_and_says_which_call() throws {
        let cases = try Self.iosCases().filter { $0.call != nil && $0.request == nil && $0.response == nil }
        XCTAssertFalse(cases.isEmpty)
        let shop = newShop()
        let sdk = makeV2(shop)
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let expected = try XCTUnwrap(item.expectedError, item.name)
            let result = outcome { run(call, on: sdk, completion: $0) }
            XCTAssertTrue(error(of: result).map(expected.matches) == true, "\(item.name): \(String(describing: result))")
            XCTAssertTrue(logged(shop, "invalid_argument").contains { $0.context["call"] == call.name }, item.name)
        }
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(sentNothing(shop))
        XCTAssertTrue(files(sdk.storage).isEmpty)
        XCTAssertTrue(heard.filter { $0.shopId == shop }.allSatisfy(LogContract.allows))
        sdk.release()
    }

    func test_each_answer_of_the_fixture_ends_the_call_as_the_fixture_says() throws {
        let cases = try Self.iosCases().filter { $0.response != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let response = try XCTUnwrap(item.response, item.name)
            let path = call.method == "setPushToken" ? "/mobile_push_tokens" : "/track/\(Self.event(of: call.method)?.rawValue ?? "")"
            let shop = newShop()
            answer(path, response.status.map { StubReply($0, json: String(decoding: response.body, as: UTF8.self)) } ?? StubReply.noAnswer)
            let sdk = makeV2(shop)
            let result = outcome { run(call, on: sdk, completion: $0) }
            if let expected = item.expectedError {
                XCTAssertTrue(error(of: result).map(expected.matches) == true, "\(item.name): \(String(describing: result))")
            } else {
                XCTAssertTrue(succeeded(result), "\(item.name): \(String(describing: result))")
            }
            XCTAssertTrue(eventually { !self.requests(path, shop).isEmpty }, "\(item.name): it went")
            if call.method.hasPrefix("track") {
                // Not taken by the server: the event waits in the queue for the next try.
                sdk.eventQueue?.settle()
                XCTAssertEqual(files(sdk.storage).count, 1, "\(item.name): on disk")
            } else {
                XCTAssertEqual(requests(path, shop).count, 1, "\(item.name): not repeated")
            }
            // The state of the instance does not move on an answer of one request.
            XCTAssertEqual(sdk.state, .ready, item.name)
            sdk.release()
        }
    }

    // MARK: - Events

    func test_an_event_of_a_message_goes_once_whoever_sends_it() {
        let shop = newShop()
        let sdk = makeV2(shop)
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop, code: "m-1"), event: .clicked), shop)
        XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == 1 })
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackClicked(code: "m-1", type: "bulk", completion: $0) }), "a repeat succeeds")

        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackDelivered(code: "m-2", type: "bulk", completion: $0) }))
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackDelivered(code: "m-2", type: "bulk", completion: $0) }))
        Rees46.handlePush(pushPayload(shop, code: "m-2"), event: .delivered)
        // Another event of the same message is its own.
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackClosed(code: "m-2", type: "bulk", completion: $0) }))

        XCTAssertTrue(queueIdle(sdk))
        XCTAssertEqual(requests("/track/clicked", shop).count, 1)
        XCTAssertEqual(requests("/track/delivered", shop).map { $0.body["code"] as? String }, ["m-2"])
        XCTAssertEqual(requests("/track/closed", shop).count, 1)
        XCTAssertTrue(requests("/track/received", shop).isEmpty)
        sdk.release()
    }

    func test_a_code_or_type_of_blanks_is_refused_too() {
        let shop = newShop()
        let sdk = makeV2(shop)
        guard case .invalidArgument? = error(of: outcome({ sdk.notifications.trackOpened(code: "  ", type: "bulk", completion: $0) })) else {
            return XCTFail("a code of blanks")
        }
        guard case .invalidArgument? = error(of: outcome({ sdk.notifications.trackClosed(code: "m-1", type: "\n", completion: $0) })) else {
            return XCTFail("a type of blanks")
        }
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(sentNothing(shop))
        sdk.release()
    }

    func test_an_event_the_server_does_not_take_is_still_accepted_and_waits_for_the_next_try() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/track/closed", StubReply(500, json: ""))
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackClosed(code: "m-1", type: "bulk", completion: $0) }), "no network error")
        XCTAssertTrue(eventually { self.requests("/track/closed", shop).count == 1 })
        sdk.eventQueue?.settle()
        XCTAssertEqual(files(sdk.storage).count, 1, "on disk for the next try")
        XCTAssertEqual(sdk.state, .ready)
        sdk.release()
    }

    func test_an_event_waits_in_the_queue_offline_and_its_call_succeeds_at_once() {
        let shop = newShop()
        let sdk = makeV2(shop)
        network.isOnline = false
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackOpened(code: "m-1", type: "bulk", completion: $0) }))
        sdk.eventQueue?.settle()
        XCTAssertEqual(files(sdk.storage).count, 1, "on disk")
        XCTAssertTrue(requests("/track/opened", shop).isEmpty)
        network.isOnline = true
        XCTAssertTrue(eventually { self.requests("/track/opened", shop).count == 1 })
        XCTAssertTrue(eventually { self.files(sdk.storage).isEmpty })
        sdk.release()
    }

    func test_a_click_stores_the_source_and_no_event_the_app_sends_calls_a_callback() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let heardEvents = Locked<[String]>([])
        let record: (String) -> (Rees46.PushPayload) -> Void = { who in { _ in heardEvents.mutate { $0.append(who) } } }
        Rees46.setPushCallbacks(Rees46.PushCallbacks(
            onDelivered: record("facade"), onOpened: record("facade"), onClicked: record("facade"), onClosed: record("facade")
        ))
        sdk.notifications.setCallbacks(Rees46.PushCallbacks(
            onDelivered: record("own"), onOpened: record("own"), onClicked: record("own"), onClosed: record("own")
        ))
        let listener = Rees46.onPushEvent { event, _ in heardEvents.mutate { $0.append("bridge \(event.rawValue)") } }

        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackDelivered(code: "c-7", type: "chain", completion: $0) }))
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackOpened(code: "c-7", type: "chain", completion: $0) }))
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackClicked(code: "c-7", type: "chain", completion: $0) }))
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackClosed(code: "c-7", type: "chain", completion: $0) }))
        XCTAssertEqual(sdk.sourceStore.currentSource()?.type, "chain")
        XCTAssertEqual(sdk.sourceStore.currentSource()?.code, "c-7")

        sdk.tracking.productView(itemId: "37")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertEqual(requests("/push", shop).first?.body["source"] as? [String: String], ["from": "chain", "code": "c-7"])
        XCTAssertNil(requests("/track/clicked", shop).first?.body["source"])

        // A type that is not a source changes nothing.
        XCTAssertTrue(succeeded(outcome { sdk.notifications.trackClicked(code: "dg-1", type: "digest", completion: $0) }))
        XCTAssertEqual(sdk.sourceStore.currentSource()?.code, "c-7")

        XCTAssertTrue(queueIdle(sdk))
        drainMainQueue()
        XCTAssertEqual(heardEvents.current, [], "the app knows of the events it sends")
        listener.cancel()
        sdk.release()
    }

    func test_the_events_without_a_completion_go_too() {
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.notifications.trackDelivered(code: "m-1", type: "bulk")
        sdk.notifications.trackOpened(code: "m-1", type: "bulk")
        sdk.notifications.trackClicked(code: "m-1", type: "bulk")
        sdk.notifications.trackClosed(code: "m-1", type: "bulk")
        for event in Rees46.PushEvent.allCases {
            XCTAssertTrue(eventually { self.requests("/" + event.path, shop).count == 1 }, event.rawValue)
        }
        sdk.release()
    }

    // MARK: - The token

    func test_get_push_token_reads_the_tokens_without_the_network() {
        let shop = newShop()
        let sdk = makeV2(shop)
        XCTAssertNil(sdk.notifications.getPushToken())
        Rees46.PushProvider.allCases.forEach { XCTAssertNil(sdk.notifications.getPushToken(provider: $0), $0.rawValue) }

        XCTAssertTrue(succeeded(outcome { sdk.notifications.setPushToken("a-1", provider: .apns, completion: $0) }))
        XCTAssertEqual(sdk.notifications.getPushToken(), Rees46.PushToken(token: "a-1", provider: .apns))
        clock.advance(by: 60)
        XCTAssertTrue(succeeded(outcome { sdk.notifications.setPushToken("f-1", provider: .fcm, completion: $0) }))
        XCTAssertEqual(sdk.notifications.getPushToken(), Rees46.PushToken(token: "f-1", provider: .fcm), "the one the shop sent last")
        XCTAssertEqual(sdk.notifications.getPushToken(provider: .apns), Rees46.PushToken(token: "a-1", provider: .apns))
        XCTAssertEqual(sdk.notifications.getPushToken(provider: .fcm), Rees46.PushToken(token: "f-1", provider: .fcm))
        XCTAssertNil(sdk.notifications.getPushToken(provider: .hms), "iOS has none")

        // The token the SDK got from APNs itself.
        clock.advance(by: 60)
        NotificationService(sdk: sdk, notificationLogger: NotificationLogger()).didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data([0xAB, 0x01]))
        XCTAssertEqual(sdk.notifications.getPushToken(provider: .apns), Rees46.PushToken(token: "ab01", provider: .apns))
        XCTAssertTrue(eventually { self.requests("/mobile_push_tokens", shop).count == 3 })
        XCTAssertTrue(eventually { sdk.notifications.getPushToken() == Rees46.PushToken(token: "ab01", provider: .apns) })
        sdk.release()

        // A shop that sent none: the device's last token.
        let other = newShop()
        let fresh = makeV2(other)
        fresh.deviceStore.deviceToken = Rees46.PushToken(token: "f-2", provider: .fcm)
        XCTAssertEqual(fresh.notifications.getPushToken(), Rees46.PushToken(token: "f-2", provider: .fcm))
        XCTAssertEqual(fresh.notifications.getPushToken(provider: .fcm), Rees46.PushToken(token: "f-2", provider: .fcm))
        XCTAssertTrue(requests("/mobile_push_tokens", other).isEmpty)
        fresh.release()
    }

    func test_set_push_token_waits_for_the_device_id_and_goes_once_a_week() {
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let done = expectation(description: "setPushToken")
        let result = Locked<Result<Void, Rees46.SdkError>?>(nil)
        sdk.notifications.setPushToken("t-1", provider: .apns) { result.current = $0; done.fulfill() }
        XCTAssertTrue(waitForLog(shop, "push_token_skipped", reason: "no_device_id"))
        XCTAssertNil(result.current, "waiting is no failure")
        release("/init")
        wait(for: [done], timeout: 5)
        XCTAssertTrue(succeeded(result.current))
        XCTAssertEqual(requests("/mobile_push_tokens", shop).count, 1)
        XCTAssertEqual(requests("/mobile_push_tokens", shop).first?.body["did"] as? String, sdk.deviceId)

        // The same token within its week: nothing goes, and it is a success.
        XCTAssertTrue(succeeded(outcome { sdk.notifications.setPushToken("t-1", provider: .apns, completion: $0) }))
        XCTAssertEqual(requests("/mobile_push_tokens", shop).count, 1)
        // A new one goes at once.
        XCTAssertTrue(succeeded(outcome { sdk.notifications.setPushToken("t-2", provider: .apns, completion: $0) }))
        XCTAssertEqual(requests("/mobile_push_tokens", shop).count, 2)
        sdk.release()
    }

    // MARK: - Callbacks

    func test_the_shops_own_callbacks_win_over_the_facades_and_empty_ones_remove_them() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let heardClicks = Locked<[String]>([])
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onClicked: { push in heardClicks.mutate { $0.append("facade \(push.code)") } }))
        sdk.notifications.setCallbacks(Rees46.PushCallbacks(onClicked: { push in heardClicks.mutate { $0.append("own \(push.code)") } }))
        Rees46.handlePush(pushPayload(shop, code: "m-1"), event: .clicked)
        XCTAssertTrue(eventually { heardClicks.current == ["own m-1"] }, "\(heardClicks.current)")

        sdk.notifications.setCallbacks(Rees46.PushCallbacks())
        Rees46.handlePush(pushPayload(shop, code: "m-2"), event: .clicked)
        XCTAssertTrue(eventually { heardClicks.current == ["own m-1", "facade m-2"] }, "\(heardClicks.current)")
        sdk.release()
    }

    // MARK: - The new core only

    func test_on_the_old_core_every_method_is_not_initialized_sends_and_sets_nothing() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let before = Self.paths.map { requests($0, shop).count }
        let source = sdk.sourceStore.currentSource().map { "\($0.type) \($0.code)" }
        XCTAssertEqual(error(of: outcome { sdk.notifications.trackDelivered(code: "m-1", type: "bulk", completion: $0) }), .notInitialized)
        XCTAssertEqual(error(of: outcome { sdk.notifications.trackOpened(code: "m-1", type: "bulk", completion: $0) }), .notInitialized)
        XCTAssertEqual(error(of: outcome { sdk.notifications.trackClicked(code: "m-1", type: "bulk", completion: $0) }), .notInitialized)
        XCTAssertEqual(error(of: outcome { sdk.notifications.trackClosed(code: "m-1", type: "bulk", completion: $0) }), .notInitialized)
        XCTAssertEqual(error(of: outcome { sdk.notifications.setPushToken("t-1", provider: .apns, completion: $0) }), .notInitialized)
        XCTAssertEqual(thrown { try await sdk.notifications.trackClicked(code: "m-1", type: "bulk") }, .some(.notInitialized))
        XCTAssertEqual(thrown { try await sdk.notifications.setPushToken("t-1", provider: .apns) }, .some(.notInitialized))
        XCTAssertNil(sdk.notifications.getPushToken())
        sdk.notifications.setCallbacks(Rees46.PushCallbacks(onClicked: { _ in }))
        XCTAssertNil(sdk.pushCallbackBox.callbacks)

        XCTAssertEqual(Self.paths.map { requests($0, shop).count }, before, "nothing went")
        XCTAssertEqual(sdk.sourceStore.currentSource().map { "\($0.type) \($0.code)" }, source, "a click stored no source")
        XCTAssertNil(sdk.deviceStore.deviceToken(.apns))
        XCTAssertTrue(waitForLog(shop, "core_flag_mismatch"))
        let calls = Set(logged(shop, "core_flag_mismatch").compactMap { $0.context["call"] })
        XCTAssertEqual(calls, [
            "notifications.trackDelivered", "notifications.trackOpened", "notifications.trackClicked",
            "notifications.trackClosed", "notifications.setPushToken", "notifications.getPushToken",
            "notifications.setCallbacks",
        ])
        XCTAssertTrue(logged(shop, "core_flag_mismatch").allSatisfy { $0.level == .warning })
        XCTAssertTrue(heard.filter { $0.shopId == shop }.allSatisfy(LogContract.allows))
        sdk.release()
    }

    func test_another_conformer_of_the_protocol_is_not_initialized() {
        let fake = FakeSDK(shopId: "fake-\(UUID().uuidString)")
        XCTAssertEqual(error(of: outcome { fake.notifications.trackDelivered(code: "m-1", type: "bulk", completion: $0) }), .notInitialized)
        XCTAssertEqual(error(of: outcome { fake.notifications.setPushToken("t-1", provider: .apns, completion: $0) }), .notInitialized)
        XCTAssertNil(fake.notifications.getPushToken())
        fake.notifications.setCallbacks(Rees46.PushCallbacks())
        XCTAssertTrue(waitForLog(nil, "not_implemented"))
        XCTAssertTrue(logged(nil, "not_implemented").contains { $0.context["call"] == "notifications.setCallbacks" })
    }

    func test_after_release_every_method_is_not_initialized_and_sends_nothing() {
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.release()
        XCTAssertEqual(error(of: outcome { sdk.notifications.trackDelivered(code: "m-1", type: "bulk", completion: $0) }), .notInitialized)
        XCTAssertEqual(error(of: outcome { sdk.notifications.trackClicked(code: "m-1", type: "bulk", completion: $0) }), .notInitialized)
        XCTAssertEqual(error(of: outcome { sdk.notifications.setPushToken("t-1", provider: .apns, completion: $0) }), .notInitialized)
        XCTAssertNil(sdk.notifications.getPushToken())
        XCTAssertTrue(sentNothing(shop))
        XCTAssertFalse(PushCenter.isTaken(.clicked, code: "m-1", shopId: shop), "nothing counted as sent")

        // The shop's next instance sends the event.
        let next = makeV2(shop)
        XCTAssertTrue(succeeded(outcome { next.notifications.trackClicked(code: "m-1", type: "bulk", completion: $0) }))
        XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == 1 })
        next.release()
    }

    func test_a_refused_shop_is_shop_blocked_and_sends_nothing() {
        let shop = newShop()
        answer("/init", StubReply(402, json: #"{"status":"error","message":"Restricted Mode"}"#))
        let sdk = makeV2(shop, settled: false)
        XCTAssertTrue(eventually { sdk.state == .refused })
        XCTAssertEqual(error(of: outcome { sdk.notifications.trackDelivered(code: "m-1", type: "bulk", completion: $0) }), .shopBlocked)
        XCTAssertEqual(error(of: outcome { sdk.notifications.setPushToken("t-1", provider: .apns, completion: $0) }), .shopBlocked)
        XCTAssertEqual(thrown { try await sdk.notifications.trackClosed(code: "m-1", type: "bulk") }, .some(.shopBlocked))
        XCTAssertTrue(sentNothing(shop))
        sdk.release()
    }

    // MARK: - completion and async

    func test_completion_comes_once_on_the_main_thread_whatever_thread_calls() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let calls = Locked(0)
        let all = expectation(description: "completions")
        all.expectedFulfillmentCount = 3
        DispatchQueue.global().async {
            let completion: (Result<Void, Rees46.SdkError>) -> Void = { _ in
                XCTAssertTrue(Thread.isMainThread)
                calls.mutate { $0 += 1 }
                all.fulfill()
            }
            sdk.notifications.trackDelivered(code: "m-1", type: "bulk", completion: completion)
            sdk.notifications.trackDelivered(code: "", type: "bulk", completion: completion)
            sdk.notifications.setPushToken("t-1", provider: .fcm, completion: completion)
        }
        wait(for: [all], timeout: 5)
        drainMainQueue()
        XCTAssertEqual(calls.current, 3)
        sdk.release()
    }

    func test_the_async_forms_return_and_throw_the_result() {
        let shop = newShop()
        let sdk = makeV2(shop)
        XCTAssertEqual(thrown { try await sdk.notifications.trackDelivered(code: "m-1", type: "bulk") }, .some(nil))
        XCTAssertEqual(thrown { try await sdk.notifications.trackOpened(code: "m-1", type: "bulk") }, .some(nil))
        XCTAssertEqual(thrown { try await sdk.notifications.trackClicked(code: "m-1", type: "bulk") }, .some(nil))
        XCTAssertEqual(thrown { try await sdk.notifications.trackClosed(code: "m-1", type: "bulk") }, .some(nil))
        guard case .invalidArgument?? = thrown(cancel: nil, { try await sdk.notifications.trackClicked(code: "", type: "bulk") }) else {
            return XCTFail("a blank code")
        }
        XCTAssertEqual(thrown { try await sdk.notifications.setPushToken("t-1", provider: .fcm) }, .some(nil))
        answer("/mobile_push_tokens", StubReply(400, json: #"{"error":"Token is missing"}"#))
        XCTAssertEqual(thrown { try await sdk.notifications.setPushToken("t-2", provider: .fcm) }, .some(.http(code: 400, serverCode: nil)))
        for event in Rees46.PushEvent.allCases {
            XCTAssertTrue(eventually { self.requests("/" + event.path, shop).count == 1 }, event.rawValue)
        }
        sdk.release()
    }

    func test_a_cancelled_task_sends_no_event_and_a_cancelled_wait_for_the_token_keeps_it() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let event: Rees46.SdkError?? = thrown(cancel: { $0.cancel() }) {
            withUnsafeCurrentTask { $0?.cancel() }
            try await sdk.notifications.trackDelivered(code: "m-1", type: "bulk")
        }
        XCTAssertEqual(event, .some(.cancelled))
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(requests("/track/delivered", shop).isEmpty)
        XCTAssertFalse(PushCenter.isTaken(.delivered, code: "m-1", shopId: shop))

        // The token waits for a device id; the task stops waiting, the SDK sends it once it has one.
        let pending = newShop()
        hold("/init")
        let waiting = makeV2(pending, identity: InMemoryUserIdentityRepository(), settled: false)
        let token: Rees46.SdkError?? = thrown(cancel: { task in
            XCTAssertTrue(self.waitForLog(pending, "push_token_skipped", reason: "no_device_id"))
            task.cancel()
        }) {
            try await waiting.notifications.setPushToken("t-1", provider: .apns)
        }
        XCTAssertEqual(token, .some(.cancelled))
        XCTAssertTrue(requests("/mobile_push_tokens", pending).isEmpty)
        release("/init")
        XCTAssertTrue(eventually { self.requests("/mobile_push_tokens", pending).count == 1 })
        XCTAssertEqual(waiting.notifications.getPushToken(provider: .apns)?.token, "t-1")
        waiting.release()
        sdk.release()
    }
}
